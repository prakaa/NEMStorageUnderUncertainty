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

1. `decision_intervals`: `data.times` indices that correspond to decision points
2. `binding_intervals`: Tuple of `data.times` indices that correspond to the first and last
   binding period for each simulation.
3. `horizon_ends`: `data.times` indices that correspond to the horizon end for
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
    decision_intervals = Int64[]
    binding_intervals = Tuple{Int64,Int64}[]
    horizon_ends = Int64[]
    while decision_start ≤ decision_end
        binding_end = decision_start + binding_n
        push!(decision_intervals, decision_start)
        push!(binding_intervals, (binding_start, binding_end))
        push!(horizon_ends, horizon_end)
        decision_start = binding_end
        (binding_start, horizon_end) = (decision_start + 1, decision_start + horizon_n)
    end
    @assert(
        length(binding_intervals) == length(horizon_ends) == length(binding_intervals),
        "Length mismatch between returned vectors"
    )
    return decision_intervals, binding_intervals, horizon_ends
end

function _get_periods_for_simulation(
    decision_start_time::DateTime,
    decision_end_time::DateTime,
    binding::T,
    horizon::T,
    data::ForecastData,
) where {T<:Period}
    function _get_indices_for_time(vec::Vector{DateTime}, dt::DateTime)
        return findall(t -> t == dt, vec)
    end

    function _get_first_index_for_time(vec::Vector{DateTime}, dt::DateTime)
        return findfirst(t -> t == dt, vec)
    end

    @assert(data.run_time_aligned, "ForecastData should be aligned by run times")
    interval_length = Minute(Int64(data.τ * 60.0))
    (run_times, forecasted_times) = (data.run_times, data.forecasted_times)
    @assert(
        !isempty(_get_indices_for_time(run_times, decision_start_time)),
        "First decision time $(decision_start_time) not in data.run_times"
    )
    @assert(
        !isempty(_get_indices_for_time(run_times, decision_end_time)),
        "Last decision time $(decision_end_time) not in data.run_times"
    )
    (decision_start, decision_end) = (
        _get_first_index_for_time(run_times, decision_start_time),
        _get_first_index_for_time(run_times, decision_end_time),
    )
    @assert(
        !isempty(_get_indices_for_time(forecasted_times, decision_end_time + horizon)),
        (
            "Data insufficient to run final decision point at $(decision_end_time)" *
            " (forecasted data should go up to $(decision_end_time + horizon))"
        )
    )
    (binding_n, horizon_n) = @. Int64(Minute.((binding, horizon)) / interval_length)
    @assert(0 < binding_n ≤ horizon_n, "0 < binding ≤ $horizon (horizon)")
    decision_n = decision_start
    decision_intervals = Int64[]
    binding_intervals = Tuple{Int64,Int64}[]
    horizon_ends = Int64[]
    while decision_n ≤ decision_end
        push!(decision_intervals, decision_n)
        decision_time = run_times[decision_n]
        decision_time_indices = _get_indices_for_time(run_times, decision_time)
        binding_start = intersect(
            decision_time_indices,
            findall(t -> t == decision_time + interval_length, forecasted_times),
        )[]
        binding_end = decision_n + binding_n - 1
        @assert(
            forecasted_times[binding_end] == decision_time + binding,
            (
                "Forecasted times do not extend to `decision_time + binding`" *
                "($(decision_time + binding)) for run time $decision_time"
            )
        )
        push!(binding_intervals, (binding_start, binding_end))
        horizon_end = decision_n + horizon_n - 1
        @assert(
            forecasted_times[horizon_end] == decision_time + horizon,
            (
                "Forecasted times do not extend to `decision_time + horizon`" *
                "($(decision_time + horizon)) for run time $decision_time"
            )
        )
        push!(horizon_ends, horizon_end)
        decision_n = _get_first_index_for_time(run_times, forecasted_times[binding_end])
    end
    @assert(
        length(binding_intervals) == length(horizon_ends) == length(binding_intervals),
        "Length mismatch between returned vectors"
    )
    return decision_intervals, binding_intervals, horizon_ends
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
