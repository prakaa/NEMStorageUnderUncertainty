abstract type StorageModelFormulation end

@doc raw"""
# Summary
Maximises storage revenue:

  * All periods are treated (weighted) equally
  * No cycling/throughput limits are modelled
  * Revenue is purely defined by the spot price for energy
  * Intertemporal SoC constraints are applied

```math
\begin{aligned}
  \max_{t} \quad & \sum_{t=1}^T{\tau\lambda_t(p_t-q_t)}\\
  \textrm{s.t.} \quad & u_t \in \{0,1\}    \\
  & p_t \geq 0 \\
  & q_t \geq 0 \\
  & p_t - \bar{p}\left(1-u_t\right) \leq 0\\
  & q_t - \bar{p}u_t \leq 0\\
  & \underline{e} \leq e_t \leq \bar{e}    \\
  & e_t-e_{t-1}- \left( q_t\eta_{charge}\tau\right)+\frac{p_t\tau}{\eta_{discharge}} = 0\\
  & e_1 = e_0 \\
\end{aligned}
```
"""
struct StandardFormulation <: StorageModelFormulation end

"""
# Arguments

  * `silent`: Default `false`. If `true`, turn off JuMP/solver output
  * `time_limit_sec`: Default `nothing`. Number of seconds before solver times out.
  * `string_names`: Default `true`. If `false`, disables JuMP string names, which can
    improve speed/performance.

# Returns

A `JuMP` model
"""
function _initialise_model(;
    silent::Bool=false,
    time_limit_sec::Union{Float64,Nothing}=nothing,
    string_names::Bool=true,
)
    model = JuMP.Model()
    if silent
        JuMP.set_silent(model)
    end
    if !isnothing(time_limit_sec)
        JuMP.set_time_limit_sec(model, time_limit_sec)
    end
    if !string_names
        JuMP.set_string_names_on_creation(model, false)
    end
    return model
end

function build_storage_model(
    storage::StorageDevice,
    prices::Vector{<:Union{Missing,AbstractFloat}},
    times::Vector{DateTime},
    τ::Float64,
    ::StandardFormulation;
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
