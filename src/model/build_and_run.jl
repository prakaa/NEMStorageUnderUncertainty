"""
Build a [`StandardArbitrage`](@ref) model

# Arguments

  * `storage`: [`StorageDevice`](@ref)
  * `prices`: Energy prices in \$/MW/hr that corresponds to prices at `times`
  * `times`: Times to run model for
  * `τ`: Interval duration in hours
  * `StandardArbitrage`
  * `silent`: default `false`. `true` to suppress solver output
  * `time_limit_sec`: default `nothing`. `Float64` to impose solver time limit in seconds
  * `string_names`: default `true`. `false` to disable JuMP string names

# Returns

Built JuMP model
"""
function _build_storage_model(
    storage::StorageDevice,
    prices::Vector{<:AbstractFloat},
    times::Vector{DateTime},
    τ::Float64,
    ::StandardArbitrage;
    silent::Bool=false,
    time_limit_sec::Union{Float64,Nothing}=nothing,
    string_names::Bool=true,
)
    if length(times) != length(prices)
        throw(ArgumentError("Prices and times vectors must be the same length"))
    end
    model = _initialise_model(;
        silent=silent, time_limit_sec=time_limit_sec, string_names=string_names
    )
    @debug "Adding vars"
    _add_variables_power!(model, storage, times)
    _add_variable_soc!(model, storage, times)
    _add_variable_charge_state!(model, times)
    @debug "Adding constraints"
    _add_constraints_charge_state!(model, storage, times)
    _add_constraint_initial_soc!(model, storage, times)
    if length(times) == 1
        _add_constraint_single_period_soc!(model, storage, times, τ)
    else
        _add_constraint_intertemporal_soc!(model, storage, times, τ)
    end
    @debug "Adding objective"
    _add_objective_standard!(model, prices, times, τ)
    return model
end

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
function run_model(
    optimizer::OptimizerWithAttributes,
    storage::StorageDevice,
    prices::Vector{<:AbstractFloat},
    times::Vector{DateTime},
    τ::Float64,
    formulation::StorageModelFormulation;
    silent::Bool=false,
    time_limit_sec::Union{Float64,Nothing}=nothing,
    string_names::Bool=true,
)
    @debug "Filtering by region, then obtaining times and prices"
    @debug "Building model"
    model = _build_storage_model(
        storage,
        prices,
        times,
        τ,
        formulation;
        silent=silent,
        time_limit_sec=time_limit_sec,
        string_names=string_names,
    )
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
