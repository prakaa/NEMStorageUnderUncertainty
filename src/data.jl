####### TYPES #######
abstract type NEMData end

"""
"""
struct ActualData{T<:AbstractFloat} <: NEMData
    region::String
    times::Vector{DateTime}
    prices::Vector{T}
    τ::T
end

"""
"""
struct ForecastData{T<:AbstractFloat} <: NEMData
    region::String
    run_times::Vector{DateTime}
    forecasted_times::Vector{DateTime}
    prices::Vector{T}
    τ::T
end

####### ACTUAL PRICES #######
"""
Obtains actual data from `parquet` files located at `path`

# Arguments

  * `path`: Path to parquet partitions

# Returns

DataFrame with settlement date, region and corresponding energy prices
"""
function get_all_actual_data(path::String)
    if !any([occursin(".parquet", file) for file in readdir(path)])
        thow(ArgumentError("$path does not contain *.parquet"))
    end
    actual_data = DataFrame(read_parquet(path))
    filter!(:INTERVENTION => x -> x == 0, actual_data)
    actual_data = actual_data[:, [:SETTLEMENTDATE, :REGIONID, :RRP]]
    actual_data[!, :SETTLEMENTDATE] =
        DateTime.(actual_data[!, :SETTLEMENTDATE], "yyyy/mm/dd HH:MM:SS")
    return actual_data
end

function _get_data_by_times(actual_data::DataFrame, times::Tuple{DateTime,DateTime})
    @assert times[1] ≤ times[2] "Start time should be ≤ end time"
    @assert actual_data.SETTLEMENTDATE[1] ≤ times[1] "Start time before data start"
    @assert actual_data.SETTLEMENTDATE[end] ≥ times[end] "End time after data end"
    filter!(:SETTLEMENTDATE => dt -> times[1] ≤ dt ≤ times[2], actual_data)
    return actual_data
end

function get_ActualData(
    actual_data::DataFrame,
    region::String,
    actual_time_window::Union{Nothing,Tuple{DateTime,DateTime}}=nothing,
)
    actual_df = copy(actual_data)
    if region ∉ ("QLD1", "NSW1", "VIC1", "SA1", "TAS1")
        throw(ArgumentError("Invalid region"))
    end
    @debug "Filtering actual prices by region"
    filter!(:REGIONID => x -> x == region, actual_df)
    disallowmissing!(actual_df)
    τ = _get_times_frequency_in_hours(actual_df.SETTLEMENTDATE)
    if !isnothing(actual_time_window)
        @debug "Filtering actual prices by time"
        actual_df = _get_data_by_times(actual_data, actual_time_window)
    end
    actual = ActualData(region, actual_df.SETTLEMENTDATE, actual_data.RRP, τ)
    return actual
end

####### FORECAST PRICES #######
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
function get_all_pd_and_p5_data(pd_path::String, p5_path::String)
    for path in (p5_path, pd_path)
        if !any([occursin(".parquet", file) for file in readdir(path)])
            thow(ArgumentError("$path does not contain *.parquet"))
        end
    end
    pd_data = DataFrame(read_parquet(pd_path))
    rename!(pd_data, :PREDISPATCH_RUN_DATETIME => :run_time, :DATETIME => :forecasted_time)
    p5_data = DataFrame(read_parquet(p5_path))
    rename!(p5_data, :RUN_DATETIME => :run_time, :INTERVAL_DATETIME => :forecasted_time)
    # unix2datetime converts unix epoch to DateTime
    for data in (p5_data, pd_data)
        filter!(:INTERVENTION => x -> x == 0, data)
        data[!, [:run_time, :forecasted_time]] = # convert microseconds to seconds
            unix2datetime.(data[!, [:run_time, :forecasted_time]] ./ 10^6)
        select!(data, :run_time, :forecasted_time, :REGIONID, :RRP)
    end
    return (pd_data, p5_data)
end

function _impute_predispatch_data(regional_pd_data::DataFrame)
    run_times = unique(regional_pd_data.actual_run_time)
    all_runtime_data = DataFrame[]
    p = Progress(length(run_times), "Imputing predispatch data")
    for run_time in run_times
        # isolate data for one run time
        run_time_data = filter(:actual_run_time => x -> x == run_time, regional_pd_data)
        # generate forecasted time at 5 minute frequency
        fill_forecasted_times = Vector(
            range(
                run_time_data.forecasted_time[1],
                run_time_data.forecasted_time[end];
                step=Minute(5),
            ),
        )
        # merge 5-minute frequency forecasted times into original data for one run time
        expanded_run_time_data = leftjoin(
            DataFrame(:forecasted_time => fill_forecasted_times),
            run_time_data;
            on=:forecasted_time,
        )
        sort!(expanded_run_time_data, :forecasted_time)
        # impute data via Next Observation Carried Backwards (NOCB)
        imputed_run_time_data = Impute.nocb(expanded_run_time_data)
        push!(all_runtime_data, imputed_run_time_data)
        # filling forecasts for the next 25 minutes with the same imputed data
        ffill_run_times = Vector(
            range(run_time + Minute(5), run_time + Minute(25); step=Minute(5))
        )
        for fill_run_time in ffill_run_times
            fill_data = copy(imputed_run_time_data)
            fill_data[:, :actual_run_time] .= fill_run_time
            # remove periods when run time > forecasted time
            filter!([:actual_run_time, :forecasted_time] => (rt, ft) -> rt <= ft, fill_data)
            push!(all_runtime_data, fill_data)
        end
        next!(p)
    end
    return vcat(all_runtime_data...)
end

function _drop_overlapping_PD_forecasts(pd_data::DataFrame)
    pd_data[!, :ahead_time] = pd_data.forecasted_time .- pd_data.actual_run_time
    filtered_pd_data = filter(:ahead_time => dt -> dt > Hour(1), pd_data)
    return filtered_pd_data
end

function _concatenate_forecast_data(pd_data::DataFrame, p5_data::DataFrame)
    pd_data = _drop_overlapping_PD_forecasts(pd_data)
    pd_data = pd_data[:, [:actual_run_time, :forecasted_time, :REGIONID, :RRP]]
    p5_data = p5_data[:, [:actual_run_time, :forecasted_time, :REGIONID, :RRP]]
    (pd_rtimes, pd_ftimes) = (
        unique(pd_data.actual_run_time), unique(pd_data.forecasted_time)
    )
    (p5_rtimes, p5_ftimes) = (
        unique(p5_data.actual_run_time), unique(p5_data.forecasted_time)
    )
    if (
        (pd_rtimes[1] != p5_rtimes[1]) ||
        (pd_rtimes[end] != p5_rtimes[end]) ||
        (pd_ftimes[1] != p5_ftimes[1]) ||
        (pd_ftimes[end] != p5_ftimes[end])
    )
        warning = (
            "PD and P5 datasets not aligned by run times or by forecasted times." *
            " The number of forecast entries across run/forecasted time may not be consistent"
        )
        @warn warning
    end
    # concatenate Data
    forecast_data = vcat(pd_data, p5_data)
    sort!(forecast_data, [:forecasted_time, :actual_run_time, :REGIONID])
    return forecast_data
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
function _get_data_by_times!(
    forecast_data::DataFrame;
    run_times::Union{Tuple{DateTime,DateTime},Nothing}=nothing,
    forecasted_times::Union{Tuple{DateTime,DateTime},Nothing}=nothing,
)
    if !isnothing(run_times)
        @assert(run_times[1] ≤ run_times[2], "Start time should be ≤ end time")
        @assert(
            forecast_data.actual_run_time[1] ≤ run_times[1], "Start time before data start"
        )
        @assert(
            forecast_data.actual_run_time[end] ≥ run_times[end], "End time after data end"
        )
        filter!(:actual_run_time => dt -> run_times[1] ≤ dt ≤ run_times[2], forecast_data)
    end
    if !isnothing(forecasted_times)
        @assert(
            forecasted_times[1] ≤ forecasted_times[2], "Start time should be ≤ end time"
        )
        @assert(
            forecast_data.forecated_time[1] ≤ forecasted_times[1],
            "Start time before data start"
        )
        @assert(
            forecast_data.forecasted_time[2] ≥ forecasted_times[end],
            "End time after data end"
        )
        filter!(
            forecasted_time => dt -> forecasted_times[1] ≤ dt ≤ forecasted_times[2],
            forecast_data,
        )
    end
end

function get_ForecastData(
    pd_data::DataFrame,
    p5_data::DataFrame,
    region::String,
    run_time_window::Union{Nothing,Tuple{DateTime,DateTime}}=nothing,
    forecasted_time_window::Union{Nothing,Tuple{DateTime,DateTime}}=nothing,
)
    (pd_df, p5_df) = (copy(pd_data), copy(p5_data))
    if region ∉ ("QLD1", "NSW1", "VIC1", "SA1", "TAS1")
        throw(ArgumentError("Invalid region"))
    end
    @debug "Filtering PD and P5 DataFrames by region"
    for df in (pd_df, p5_df)
        filter!(:REGIONID => x -> x == region, df)
    end
    @debug "Calculating actual run times and dropping original run time col"
    for (df, minutes) in zip((pd_df, p5_df), (5, 30))
        df[!, :actual_run_time] = df[!, :run_time] .- Minute(minutes)
        select!(df, Not(:run_time))
    end
    @debug "Filtering PD and P5 DataFrames by times and dropping nominal run time col"
    for df in (pd_df, p5_df)
        if !isnothing(run_time_window) || !isnothing(forecasted_time_window)
            _get_data_by_times!(
                df; run_times=run_time_window, forecasted_times=forecasted_time_window
            )
        end
    end
    @debug "Imputing predispatch data"
    imputed_pd_df = _impute_predispatch_data(pd_df)
    @debug "Concatenating PD and P5 datasets to make a forecast dataset"
    forecast_data = _concatenate_forecast_data(imputed_pd_df, p5_df)
    sort!(forecast_data, [:actual_run_time, :forecasted_time])
    τ = _get_times_frequency_in_hours(
        forecast_data[
            forecast_data.actual_run_time .== forecast_data.actual_run_time[1],
            :forecasted_time,
        ],
    )
    disallowmissing!(forecast_data)
    forecast = ForecastData(
        region,
        forecast_data.actual_run_time,
        forecast_data.forecasted_time,
        Float64.(forecast_data.RRP),
        τ,
    )
    return forecast
end
