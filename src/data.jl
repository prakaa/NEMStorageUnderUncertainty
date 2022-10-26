const DTFMT::String = "yyyy/mm/dd HH:MM:SS"

"""
    get_all_actual_prices(path::String)

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
    price_df[!, :SETTLEMENTDATE] = DateTime.(price_df[!, :SETTLEMENTDATE], DTFMT)
    return price_df
end

"""
    get_all_forecast_prices(pd_path::String, p5_path::String)

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
    return forecast_prices
end

"""
    get_forecast_prices_by_times(
    forecast_prices::DataFrame,
    forecasted_times::Tuple{DateTime, DateTime}=nothing,
    run_times::Tuple{DateTime, DateTime}=nothing
    )

Filters forecast prices based on supplied `run_times` (start, end) and `forecasted_times`
(start, end)

# Arguments

  * `forecast_prices`: DataFrame produced by [`get_all_forecast_prices`](@ref)
  * `forecasted_times`: (start_time, end_time), inclusive
  * `run_times`: (start_time, end_time), inclusive

# Returns

Filtered forecast prices
"""
function get_forecast_prices_by_times(
    forecast_prices::DataFrame;
    forecasted_times::Union{Tuple{DateTime,DateTime},Nothing}=nothing,
    run_times::Union{Tuple{DateTime,DateTime},Nothing}=nothing,
)
    if isnothing(run_times) && isnothing(forecasted_times)
        ArgumentError("Supply either run or forecasted times")
    end
    if !isnothing(run_times)
        @assert run_times[1] ≤ run_times[2] "Start time should be ≤ end time"
        forecast_prices = filter(
            :actual_run_time => dt -> run_times[1] ≤ dt ≤ run_times[2], forecast_prices
        )
    end
    if !isnothing(forecasted_times)
        @assert forecasted_times[1] ≤ forecasted_times[2] "Start time should be ≤ end time"
        forecast_prices = filter(
            :forecasted_time => dt -> forecasted_times[1] ≤ dt ≤ forecasted_times[2],
            forecast_prices,
        )
    end
    return forecast_prices
end
