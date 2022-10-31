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

function _get_simulation_portions(
    binding::T, horizon::T, times::Vector{DateTime}, τ::Float64
) where {T<:Period}
    (binding_min, horizon_min) = Minute.((binding, horizon))
    (binding_n, horizon_n) = @. value((binding_min, horizon_min) / (τ * 60.0))
    @assert(0 < binding_n ≤ horizon_n, "0 < binding ≤ $horizon (horizon)")
    @assert(
        horizon_n ≤ length(times),
        "Horizon is longer than data (max of ($(data.times[end] - data.times[1]))"
    )
    binding_intervals = Tuple[]
    horizon_ends = Int64[]
    (binding_start, horizon_end) = (1, horizon_n)
    while horizon_end ≤ length(times)
        binding_end = binding_start + binding_n - 1
        push!(binding_intervals, (binding_start, binding_end))
        push!(horizon_ends, horizon_end)
        binding_start = binding_end + 1
        horizon_end = binding_start + horizon_n - 1
    end
    binding_intervals = binding_intervals[horizon_ends .≤ length(times)]
    filter!(x -> x ≤ length(times), horizon_ends)
    @assert(
        length(binding_intervals) == length(horizon_ends),
        "Binding periods and horizon end vectors length mismatch"
    )
    return binding_intervals, horizon_ends
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
