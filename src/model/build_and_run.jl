function _get_times_index(t::DateTime, times::Vector{DateTime})
    return findall(time -> time == t, times)[]
end

"""
Build a [`StandardArbitrage`](@ref) model

# Arguments

  * `storage`: [`StorageDevice`](@ref)
  * `prices`: Energy prices in \$/MW/hr that corresponds to prices at `times`
  * `times`: Times to run model for
  * `binding_end_time`: Binding period end time
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
    binding_end_time::DateTime,
    τ::Float64,
    ::StandardArbitrage,
    ::NoDegradation;
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
    _add_variable_throughput!(model, storage, times)
    @debug "Adding constraints"
    _add_constraints_charge_state!(model, storage, times)
    _add_constraint_initial_soc!(model, storage, times, τ)
    _add_constraint_initial_throughput!(model, storage, times, τ)
    if length(times) > 1
        _add_constraint_intertemporal_soc!(model, storage, times, τ)
        _add_constraint_intertemporal_throughput!(model, times, τ)
    end
    @debug "Adding objective"
    _add_objective_standard!(model, prices, times, τ)
    return model
end

"""
Build a [`StandardArbitrageThroughputLimit`](@ref) model

# Arguments

  * `storage`: [`StorageDevice`](@ref)
  * `prices`: Energy prices in \$/MW/hr that corresponds to prices at `times`
  * `times`: Times to run model for
  * `binding_end_time`: Binding period end time
  * `τ`: Interval duration in hours
  * `StandardArbitrageThroughputLimit`: [`StandardArbitrageThroughputLimit`](@ref)
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
    binding_end_time::DateTime,
    τ::Float64,
    throughput_limit::StandardArbitrageThroughputLimit,
    ::NoDegradation;
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
    time_diff = Minute(times[end] - times[1]) + Minute(5)
    min_in_year = Minute(60 * 24 * 365)
    proportion_of_year = time_diff / min_in_year
    binding_proportion_of_year =
        (Minute(binding_end_time - times[1]) + Minute(5)) / min_in_year
    d_binding_max =
        storage.throughput +
        throughput_limit.throughput_mwh_per_year * binding_proportion_of_year
    d_max =
        storage.throughput + throughput_limit.throughput_mwh_per_year * proportion_of_year
    @debug "Adding vars"
    _add_variables_power!(model, storage, times)
    _add_variable_soc!(model, storage, times)
    _add_variable_charge_state!(model, times)
    _add_variable_throughput!(model, storage, times)
    @debug "Adding constraints"
    _add_constraints_charge_state!(model, storage, times)
    _add_constraint_initial_soc!(model, storage, times, τ)
    _add_constraint_initial_throughput!(model, storage, times, τ)
    _add_constraint_throughput_limit!(model, times, d_max)
    if length(times) > 1
        _add_constraint_binding_throughput_limit!(model, binding_end_time, d_binding_max)
        _add_constraint_intertemporal_soc!(model, storage, times, τ)
        _add_constraint_intertemporal_throughput!(model, times, τ)
    end
    @debug "Adding objective"
    _add_objective_standard!(model, prices, times, τ)
    return model
end

"""
Build a [`ArbitrageThroughputPenalty`](@ref) model

# Arguments

  * `storage`: [`StorageDevice`](@ref)
  * `prices`: Energy prices in \$/MW/hr that corresponds to prices at `times`
  * `times`: Times to run model for
  * `binding_end_time`: Binding period end time
  * `τ`: Interval duration in hours
  * `throughput_penalty`: [`ArbitrageThroughputPenalty`](@ref)
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
    binding_end_time::DateTime,
    τ::Float64,
    throughput_penalty::ArbitrageThroughputPenalty,
    ::NoDegradation;
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
    _add_variables_power!(model, storage, times)
    _add_variable_soc!(model, storage, times)
    _add_variable_charge_state!(model, times)
    _add_variable_throughput!(model, storage, times)
    @debug "Adding constraints"
    _add_constraints_charge_state!(model, storage, times)
    _add_constraint_initial_soc!(model, storage, times, τ)
    _add_constraint_initial_throughput!(model, storage, times, τ)
    if length(times) > 1
        _add_constraint_intertemporal_soc!(model, storage, times, τ)
        _add_constraint_intertemporal_throughput!(model, times, τ)
    end
    @debug "Adding objective"
    _add_objective_throughput_penalty!(
        model,
        prices,
        times,
        τ,
        storage.throughput,
        throughput_penalty.d_lifetime,
        storage.energy_capacity,
        throughput_penalty.c_capital,
    )
    return model
end

"""
Build a [`ArbitrageCapContracted`](@ref) model

# Arguments

  * `storage`: [`StorageDevice`](@ref)
  * `prices`: Energy prices in \$/MW/hr that corresponds to prices at `times`
  * `times`: Times to run model for
  * `binding_end_time`: Binding period end time
  * `τ`: Interval duration in hours
  * `cap_contracted`: [`ArbitrageCapContracted`](@ref)
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
    binding_end_time::DateTime,
    τ::Float64,
    cap_contracted::ArbitrageCapContracted,
    ::NoDegradation;
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
    _add_variables_power!(model, storage, times)
    _add_variable_soc!(model, storage, times)
    _add_variable_charge_state!(model, times)
    _add_variable_throughput!(model, storage, times)
    @debug "Adding constraints"
    _add_constraints_charge_state!(model, storage, times)
    _add_constraint_initial_soc!(model, storage, times, τ)
    _add_constraint_initial_throughput!(model, storage, times, τ)
    if length(times) > 1
        _add_constraint_intertemporal_soc!(model, storage, times, τ)
        _add_constraint_intertemporal_throughput!(model, times, τ)
    end
    @debug "Adding objective"
    _add_objective_cap_contracted!(
        model,
        prices,
        times,
        τ,
        storage.throughput,
        cap_contracted.d_lifetime,
        storage.energy_capacity,
        cap_contracted.c_capital,
        cap_contracted.C,
    )
    return model
end

"""
Build a [`ArbitrageDiscounted`](@ref) model

# Arguments

  * `storage`: [`StorageDevice`](@ref)
  * `prices`: Energy prices in \$/MW/hr that corresponds to prices at `times`
  * `times`: Times to run model for
  * `binding_end_time`: Binding period end time
  * `τ`: Interval duration in hours
  * `discounted`: [`ArbitrageDiscounted`](@ref)
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
    binding_end_time::DateTime,
    τ::Float64,
    discounted::ArbitrageDiscounted,
    ::NoDegradation;
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
    _add_variables_power!(model, storage, times)
    _add_variable_soc!(model, storage, times)
    _add_variable_charge_state!(model, times)
    _add_variable_throughput!(model, storage, times)
    @debug "Adding constraints"
    _add_constraints_charge_state!(model, storage, times)
    _add_constraint_initial_soc!(model, storage, times, τ)
    _add_constraint_initial_throughput!(model, storage, times, τ)
    if length(times) > 1
        _add_constraint_intertemporal_soc!(model, storage, times, τ)
        _add_constraint_intertemporal_throughput!(model, times, τ)
    end
    @debug "Adding objective"
    _add_objective_discounted!(
        model,
        prices,
        times,
        τ,
        storage.throughput,
        discounted.d_lifetime,
        storage.energy_capacity,
        discounted.c_capital,
        discounted.discount_function,
        discounted.r,
    )
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
  * `binding_end_time`: Binding period end time
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
    binding_end_time::DateTime,
    τ::Float64,
    formulation::StorageModelFormulation,
    degradation::DegradationModel;
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
        binding_end_time,
        τ,
        formulation,
        degradation;
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
