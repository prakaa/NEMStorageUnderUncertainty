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
function build_storage_model(
    storage::StorageDevice,
    prices::Vector{<:Union{Missing,AbstractFloat}},
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
    _add_constraint_intertemporal_soc!(model, storage, times, τ)
    _add_constraint_initial_soc!(model, storage, times)
    @debug "Adding objective"
    _add_objective_standard!(model, prices, times, τ)
    return model
end
