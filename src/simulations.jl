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
    if JuMP.termination_status(model) == MOI.OPTIMAL
        return model
    elseif JuMP.termination_status(model) == MOI.TIME_LIMIT ||
        JuMP.termination_status(model) == MOI.ITERATION_LIMIT
        @warn "Model run between $(times[1]) and $(times[end]) hit iteration/time limit"
        return model
    else
        @error "Error in model run between $(times[1]) and $(times[end])" model
        error("Model error")
    end
end

function _update_storage_state(storage::StorageDevice, model::JuMP.Model, τ::Float64) end
