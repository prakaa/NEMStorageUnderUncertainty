"""
Runs a model using data in `prices`, `times` and τ (interval duration in hours).
The type of model constructed and run is dependent on the `formulation`

# Arguments
  * `optimizer`: A solver optimizer
  * `storage`: [`StorageDevice`](@ref)
  * `prices`: Energy prices in \$/MW/hr that corresponds to prices at `times`
  * `times`: Times to run model for
  * `τ`: Interval duration in hours
  * `formulation`: A model formulation ([`StorageModelFormulation`](@ref))

# Returns

  * A JuMP model if the solution is optimal (within solver tolerances)
  * A JuMP model with warning if a time/iteration limit is hit
  * Throws and error if infeasible/unbounded/etc.
"""
function _run_model(
    optimizer::DataType,
    storage::StorageDevice,
    prices::Vector{<:AbstractFloat},
    times::Vector{DateTime},
    τ::Float64,
    formulation::StorageModelFormulation;
)
    @debug "Filtering by region, then obtaining times and prices"
    @debug "Building model"
    model = build_storage_model(storage, prices, times, τ, formulation)
    JuMP.set_optimizer(model, optimizer)
    @debug "Begin model solving"
    JuMP.optimize!(model)
    if JuMP.termination_status(model) == JuMP.OPTIMAL
        return model
    elseif JuMP.termination_status(model) == JuMP.TIME_LIMIT ||
        JuMP.termination_status(model) == JuMP.ITERATION_LIMIT
        @warn "Model run between $(times[1]) and $(times[end]) hit iteration/time limit"
        return model
    else
        @error "Error in model run between $(times[1]) and $(times[end])" model
        error("Model error")
    end
end

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

  - `decision_start_time`: Decision start time. `decision_start_time` need not be in
    `data.times`, so long as the first binding time (`decision_start_time + τ`)
    is contained in `data.times`.
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
    binding_start = findfirst(t -> t == decision_start_time + interval_length, times)
    (decision_start, decision_end) = (
        binding_start - 1, findfirst(t -> t == decision_end_time, times)
    )
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
            "(need data to $(decision_end_time + horizon)"
        )
    )
    decision_intervals = Int64[]
    binding_intervals = Tuple[]
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
