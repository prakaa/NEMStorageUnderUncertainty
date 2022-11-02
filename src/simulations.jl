"""
"Updates" (via new `StorageDevice`) storage state between model runs. Specifically:

  * Updates `soc₀` to reflect `soc` at end of last model run
    * Considers `η_discharge` and `η_charge` (explicitly/via intertemporal SoC constraints)
  * Updates storage `throughput` based on model run
    * Based on *discharged (delivered) energy* and thus does not consider any η

# Arguments

  * `storage`: [`StorageDevice`](@ref)
  * `model`: Model from [`_run_model`](@ref) with solution values
  * `τ`: Interval duration in hours
  * `degradation`: No degradation model [`NoDegradation`](@ref)

# Returns

New [`StorageDevice`](@ref) with updated `soc₀` and `throughput`
"""
function _update_storage_state(
    storage::StorageDevice, model::JuMP.Model, τ::Float64, ::NoDegradation
)
    if length(model[:soc_mwh]) == 1
        soc_start = model[:soc_mwh][1]
        charge_mw = model[:charge_mw][1]
        discharge_mw = model[:discharge_mw][1]
        new_soc₀ =
            soc_start +
            charge_mw * storage.η_charge * τ +
            discharge_mw / storage.η_discharge * τ
        period_throughput_mwh = discharge_mw * τ
    else
        new_soc₀ = JuMP.value(model[:soc_mwh][end])
        period_throughput_mwh = sum(@. JuMP.value(model[:discharge_mw] * τ))
    end
    return copy(storage, new_soc₀, period_throughput_mwh)
end

"""
Gets decision points, binding intervals and horizon ends given [`ActualData`](@ref) and
simulation parameters.

# Arguments

  - `decision_start_time`: Decision start time.
  - `decision_end_time`: Decision end time.
  - `binding`: `decision_time` + `binding` gives the last binding period
  - `horizon`: `decision_time` + `horizon` gives the end of the simulation horizon
  - `data`: [`ActualData`](@ref)

# Returns

`DataFrame` with the following columns:

1. `decision_interval`: `data.times` indices that correspond to decision points
2. `binding_start`: `data.times` indices that correspond to the first
   binding period for each simulation.
3. `binding_end`: `data.times` indices that correspond to the last
   binding period for each simulation.
4. `horizon_end`: `data.times` indices that correspond to the horizon end for
   each simulation

"""
function _get_periods_for_simulation(
    decision_start_time::DateTime,
    decision_end_time::DateTime,
    binding::T,
    horizon::T,
    data::ActualData,
) where {T<:Period}
    interval_length = Minute(Int64(data.τ * 60.0))
    times = data.times
    (decision_start, decision_end) = (
        findfirst(t -> t == decision_start_time, times),
        findfirst(t -> t == decision_end_time, times),
    )
    @assert(
        !isnothing(decision_start),
        "First decision time $(decision_start_time) not in data.times"
    )
    @assert(
        !isnothing(decision_end),
        "Last decision time $(decision_end_time) not in data.times"
    )
    binding_start = decision_start + 1
    (binding_n, horizon_n) = @. Int64(Minute.((binding, horizon)) / interval_length)
    horizon_end = decision_start + horizon_n
    @assert(0 < binding_n ≤ horizon_n, "0 < binding ≤ $horizon (horizon)")
    @assert(
        horizon_n ≤ length(times),
        "Horizon is longer than data (max of ($(data.times[end] - data.times[1]))"
    )
    @assert(
        decision_end + horizon_n ≤ length(times),
        (
            "Data insufficient to run final decision point at $(decision_end_time)" *
            " (need data to $(decision_end_time + horizon))"
        )
    )
    @assert(
        (decision_end - decision_start) % binding_n == 0,
        (
            "An integer number of decision times cannot be run between decision start " *
            "and end times. Change these, or change the binding time" *
            "(($decision_end - $decision_start) % $binding_n != 0)"
        )
    )
    decision_n = decision_start
    n_iterations = length(decision_start_time:binding:decision_end_time)
    period_data = Array{Int64,2}(undef, n_iterations, 4)
    n = 1
    while decision_n ≤ decision_end
        binding_end = decision_n + binding_n
        period_data[n, 1] = decision_n
        period_data[n, 2] = binding_start
        period_data[n, 3] = binding_end
        period_data[n, 4] = horizon_end
        decision_n = binding_end
        (binding_start, horizon_end) = (decision_n + 1, decision_n + horizon_n)
        n += 1
    end
    period_data = DataFrame(period_data, :auto)
    rename!(period_data, [:decision_interval, :binding_start, :binding_end, :horizon_end])
    return period_data
end

"""
Gets decision points, binding intervals and horizon ends given [`ForecastData`](@ref) and
simulation parameters.

# Arguments

  - `decision_start_time`: Decision start time. Applies to `run_time`
  - `decision_end_time`: Decision end time. Applies to `run_time`
  - `binding`: `decision_time` + `binding` gives the last binding period.
    Applies to `forecasted_time`
  - `horizon`: `decision_time` + `horizon` gives the end of the simulation horizon.
    Applies to `forecasted_time`
  - `data`: [`ForecastData`](@ref)

# Returns

`DataFrame` with the following columns:

1. `decision_interval`: `data.times` indices that correspond to `run_time` decision points
2. `binding_start`: `data.times` indices that correspond to the first
   binding period for each simulation. Applies to `forecasted_time`.
3. `binding_end`: `data.times` indices that correspond to the last
   binding period for each simulation. Applies to `forecasted_time`
4. `horizon_end`: `data.times` indices that correspond to the horizon end for
   each simulation. Applies to `forecasted_time`

"""
function _get_periods_for_simulation(
    decision_start_time::DateTime,
    decision_end_time::DateTime,
    binding::T,
    horizon::T,
    data::ForecastData,
) where {T<:Period}
    function _validate_time_inputs(
        data::ForecastData, decision_start_time::DateTime, decision_end_time::DateTime
    )
        (run_times, forecasted_times) = (data.run_times, data.forecasted_times)
        @assert(
            !isnothing(_get_first_index_for_time(run_times, decision_start_time)),
            "First decision time $(decision_start_time) not in data.run_times"
        )
        @assert(
            !isnothing(_get_first_index_for_time(run_times, decision_end_time)),
            "Last decision time $(decision_end_time) not in data.run_times"
        )
        @assert(
            !isnothing(
                _get_first_index_for_time(forecasted_times, decision_end_time + horizon)
            ),
            (
                "Data insufficient to run final decision point at $(decision_end_time)" *
                " (forecasted data should go up to $(decision_end_time + horizon))"
            )
        )
        return run_times, forecasted_times
    end

    function _get_first_index_for_time(vec::Vector{DateTime}, dt::DateTime)
        return findfirst(t -> t == dt, vec)
    end

    function _create_run_time_index_ref(data::ForecastData, decision_end_time::DateTime)
        df = convert(DataFrame, data)
        df[!, :index] = 1:size(df)[1]
        first_idx = combine(groupby(df, :actual_run_times), :index => first)
        filter!(:actual_run_times => dt -> dt ≤ decision_end_time, first_idx)
        return first_idx[!, :index_first]
    end

    @assert(data.run_time_aligned, "ForecastData should be aligned by run times")
    interval_length = Minute(Int64(data.τ * 60.0))
    (run_times, forecasted_times) = _validate_time_inputs(
        data, decision_start_time, decision_end_time
    )
    (decision_start, decision_end) = (
        _get_first_index_for_time(run_times, decision_start_time),
        _get_first_index_for_time(run_times, decision_end_time),
    )
    (binding_n, horizon_n) = @. Int64(Minute.((binding, horizon)) / interval_length)
    @assert(0 < binding_n ≤ horizon_n, "0 < binding ≤ $horizon (horizon)")
    decision_n = decision_start
    rt_index_ref = _create_run_time_index_ref(data, decision_end_time)
    index_ref = findfirst(i -> i == decision_start, rt_index_ref)
    @assert(
        (length(rt_index_ref) - index_ref) % binding_n == 0,
        (
            "An integer number of decision times cannot be run between decision start " *
            "and end times. Change these, or change the binding time" *
            "(($(length(rt_index_ref)) - $index_ref) % $binding_n != 0)"
        )
    )
    n_iterations = length(decision_start_time:binding:decision_end_time)
    period_data = Array{Int64,2}(undef, n_iterations, 4)
    n = 1
    while decision_n ≤ decision_end
        period_data[n, 1] = decision_n
        decision_time = run_times[decision_n]
        # binding applies to forecasted_time
        binding_start = decision_n
        binding_end = decision_n + binding_n - 1
        @assert(
            forecasted_times[binding_end] == decision_time + binding,
            (
                "Forecasted times do not extend to `decision_time + binding`" *
                "($(decision_time + binding)) for run time $decision_time"
            )
        )
        period_data[n, 2] = binding_start
        period_data[n, 3] = binding_end
        # horizon applies to forecasted_time
        horizon_end = decision_n + horizon_n - 1
        @assert(
            forecasted_times[horizon_end] == decision_time + horizon,
            (
                "Forecasted times do not extend to `decision_time + horizon`" *
                "($(decision_time + horizon)) for run time $decision_time"
            )
        )
        period_data[n, 4] = horizon_end
        index_ref += binding_n
        if index_ref > length(rt_index_ref)
            decision_n += 1
        else
            decision_n = rt_index_ref[index_ref]
        end
        n += 1
    end
    period_data = DataFrame(period_data, :auto)
    rename!(period_data, [:decision_interval, :binding_start, :binding_end, :horizon_end])
    return period_data
end

function simulate_storage_operation(
    optimizer::DataType,
    storage::StorageDevice,
    data::ActualData,
    region::String,
    model_formulation::StorageModelFormulation,
    degradation::DegradationModel;
    binding::T,
    horizon::T,
) where {T<:Period} end
