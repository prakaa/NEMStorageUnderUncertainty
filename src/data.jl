abstract type PriceData end

"""
"""
struct ForecastPrice <: PriceData
    run_start::DateTime
    run_end::DateTime
    forecasted_start::DateTime
    forecasted_end::DateTime
    data::DataFrame
end

"""
"""
struct ActualPrice <: PriceData
    start_time::DateTime
    end_time::DateTime
    data::DataFrame
end

"""
Obtains actual price data from `parquet` files located at `path`

# Arguments

  * `path`: Path to parquet partitions

# Returns

DataFrame with settlement date, region and corresponding energy prices
"""
function get_all_actual_prices(path::String)
    if !any([occursin(".parquet", file) for file in readdir(path)])
        thow(ArgumentError("$path does not contain *.parquet"))
    end
    df = DataFrame(read_parquet(path))
    filter!(:INTERVENTION => x -> x == 0, df)
    price_df = df[:, [:SETTLEMENTDATE, :REGIONID, :RRP]]
    price_df[!, :SETTLEMENTDATE] =
        DateTime.(price_df[!, :SETTLEMENTDATE], "yyyy/mm/dd HH:MM:SS")
    start_time = sort(price_df[!, :SETTLEMENTDATE])[1]
    end_time = sort(price_df[!, :SETTLEMENTDATE])[end]
    return ActualPrice(start_time, end_time, price_df)
end

"""
Obtains and compiles all forecasted price data from `parquet` files located at the
`P5MIN` path (`p5_path`) and the `PREDISPATCH path` (`pd_path`)

Note that `Parquet.jl` cannot parse Timestamps from `.parquet`, so we use
[`unix2datetime`](https://docs.julialang.org/en/v1/stdlib/Dates/#Dates.unix2datetime).

# Arguments

  * `pd_path`: Path to `PREDISPATCH` parquet partitions
  * `p5_path`: Path to `P5MIN` parquet partitions

# Returns

Compiled forecast data, with `PREDISPATCH` forecasts that overlap with `P5MIN` removed.
Compiled forecast data has actual run times, forecasted times, regions and their
corresponding energy prices.
"""
function get_all_forecast_prices(pd_path::String, p5_path::String)
    function _drop_overlapping_PD_forecasts(pd_df::DataFrame)
        pd_df[!, :ahead_time] = pd_df[:, :forecasted_time] .- pd_df[:, :actual_run_time]
        filtered_pd_df = filter(:ahead_time => dt -> dt > Hour(1), pd_df)
        return filtered_pd_df
    end

    function _concatenate_forecast_prices(pd_df::DataFrame, p5_df::DataFrame)
        pd_df = _drop_overlapping_PD_forecasts(pd_df)
        pd_prices = pd_df[:, [:actual_run_time, :forecasted_time, :REGIONID, :RRP]]
        p5_prices = p5_df[:, [:actual_run_time, :forecasted_time, :REGIONID, :RRP]]
        # concatenate Data
        forecast_prices = vcat(pd_prices, p5_prices)
        sort!(forecast_prices, [:forecasted_time, :actual_run_time, :REGIONID])
        return forecast_prices
    end

    for path in (p5_path, pd_path)
        if !any([occursin(".parquet", file) for file in readdir(path)])
            thow(ArgumentError("$path does not contain *.parquet"))
        end
    end
    pd_df = DataFrame(read_parquet(pd_path))
    rename!(pd_df, :PREDISPATCH_RUN_DATETIME => :run_time, :DATETIME => :forecasted_time)
    p5_df = DataFrame(read_parquet(p5_path))
    rename!(p5_df, :RUN_DATETIME => :run_time, :INTERVAL_DATETIME => :forecasted_time)
    # unix2datetime converts unix epoch to DateTime
    for df in (p5_df, pd_df)
        filter!(:INTERVENTION => x -> x == 0, df)
        df[!, [:run_time, :forecasted_time]] = # convert microseconds to seconds
            unix2datetime.(df[!, [:run_time, :forecasted_time]] ./ 10^6)
    end
    # PD actual run time is 30 minutes before nominal run time
    pd_df[!, :actual_run_time] = pd_df[!, :run_time] .- Minute(30)
    # P5MIN actual run time is 5 minutes before nominal run time
    p5_df[!, :actual_run_time] = p5_df[!, :run_time] .- Minute(5)
    forecast_prices = _concatenate_forecast_prices(pd_df, p5_df)
    (run_start, run_end) = (
        forecast_prices.actual_run_time[0], forecast_prices.actual_run_time[1]
    )
    (forecasted_start, forecasted_end) = (
        forecast_prices.forecasted_time[0], forecast_prices.forecasted_time[1]
    )
    return ForecastPrice(
        run_start, run_end, forecasted_start, forecasted_end, forecast_prices
    )
end

"""
Filters forecast prices based on supplied `run_times` (start, end) and `forecasted_times`
(start, end)

# Arguments

  * `prices`: `ForecastPrice` produced by [`get_all_forecast_prices`](@ref)
  * `forecasted_times`: (`start_time`, `end_time`), inclusive
  * `run_times`: (`start_time`, `end_time`), inclusive

# Returns

Filtered [`ForecastPrice`](@ref)
"""
function get_prices_by_times(
    prices::ForecastPrice;
    forecasted_times::Union{Tuple{DateTime,DateTime},Nothing}=nothing,
    run_times::Union{Tuple{DateTime,DateTime},Nothing}=nothing,
)
    if isnothing(run_times) && isnothing(forecasted_times)
        ArgumentError("Supply either run or forecasted times")
    end
    forecast_prices = prices.data
    if !isnothing(run_times)
        @assert run_times[1] ≤ run_times[2] "Start time should be ≤ end time"
        @assert prices.run_start ≤ run_times[1] "Start time before data start"
        @assert prices.run_end ≥ run_times[end] "End time after data end"
        forecast_prices = filter(
            :actual_run_time => dt -> run_times[1] ≤ dt ≤ run_times[2], forecast_prices
        )
    end
    if !isnothing(forecasted_times)
        @assert forecasted_times[1] ≤ forecasted_times[2] "Start time should be ≤ end time"
        @assert prices.forecasted_start ≤ forecasted_times[1] "Start time before data start"
        @assert prices.forecasted_end ≥ forecasted_times[end] "End time after data end"
        forecast_prices = filter(
            :forecasted_time => dt -> forecasted_times[1] ≤ dt ≤ forecasted_times[2],
            forecast_prices,
        )
    end
    (run_start, run_end) = (
        forecast_prices.actual_run_time[1], forecast_prices.actual_run_time[end]
    )
    (forecasted_start, forecasted_end) = (
        forecast_prices.forecasted_time[1], forecast_prices.forecasted_time[end]
    )
    return ForecastPrice(
        run_start, run_end, forecasted_start, forecasted_end, forecast_prices
    )
end

"""
Filters actual prices based on supplied `times` (start, end)

# Arguments

  * `prices`: `ActualPrice` produced by [`get_all_actual_prices`](@ref)
  * `times`: (`start_time`, `end_time`), inclusive

# Returns

Filtered [`ActualPrice`](@ref)
"""
function get_prices_by_times(
    prices::ActualPrice, times::Union{Tuple{DateTime,DateTime},Nothing}
)
    @assert times[1] ≤ times[2] "Start time should be ≤ end time"
    @assert prices.start_time ≤ times[1] "Start time before data start"
    @assert prices.end_time ≥ times[end] "End time after data end"
    actual_prices = prices.data
    actual_prices = filter(:SETTLEMENTDATE => dt -> times[1] ≤ dt ≤ times[2], actual_prices)
    (start_time, end_time) = (
        actual_prices.SETTLEMENTDATE[1], actual_prices.SETTLEMENTDATE[end]
    )
    return ActualPrice(start_time, end_time, actual_prices)
end
