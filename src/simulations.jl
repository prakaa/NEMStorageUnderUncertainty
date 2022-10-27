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
    return model
end
