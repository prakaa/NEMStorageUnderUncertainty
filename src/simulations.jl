"""
Runs a model using data in `prices`, `times` and τ (interval duration in hours).
The type of model constructed and run is dependent on the `formulation`

# Arguments
  * `optimizer`: A solver optimizer
  * `storage`: [`StorageDevice`](@ref)
  * `times`: Times to run model for
  * `prices`: Energy prices in \$/MW/hr that corresponds to prices at `times`
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
    times::Vector{DateTime},
    prices::Vector{<:Float64},
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
    storage::T where {T<:StorageDevice},
    model::JuMP.Model,
    τ::Float64,
    degradation::NoDegradation,
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
