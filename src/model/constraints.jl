@doc raw"""
Adds two constraints to `model`:
  * ``p_t - \bar{p}\left(1-u_t\right) \leq 0``
  * ``q_t - \bar{p}u_t \leq 0``

# Arguments

  * `model`: JuMP model
  * `storage`: A [`StorageDevice`](@ref)
  * `times`: A `Vector` of `DateTime`s
"""
function _add_constraints_charge_state!(
    model::JuMP.Model, storage::StorageDevice, times::Vector{DateTime}
)
    discharge_mw = model[:discharge_mw]
    charge_mw = model[:charge_mw]
    charge_state = model[:charge_state]
    power_capacity = storage.power_capacity
    JuMP.@constraints(
        model,
        begin
            discharge_operation[t=times],
            discharge_mw[t] - power_capacity * (1 - charge_state[t]) ≤ 0
            charge_operation[t=times], charge_mw[t] - power_capacity * charge_state[t] ≤ 0
        end
    )
end

@doc raw"""
Adds the following constraint to `model`: ``e_1 = e_0``, where ``e_0`` is obtained from
`storage`.

# Arguments

  * `model`: JuMP model
  * `storage`: A [`StorageDevice`](@ref)
  * `times`: A `Vector` of `DateTime`s
"""
function _add_constraint_initial_soc!(
    model::JuMP.Model, storage::StorageDevice, times::Vector{DateTime}
)
    soc_mwh = model[:soc_mwh]
    soc₀ = storage.soc₀
    JuMP.@constraint(model, initial_soc, soc_mwh[times[1]] == soc₀)
end

@doc raw"""
Adds the following constraint to `model` if `times` has length ≥ 2:
``e_t-e_{t-1}- \left( q_t\eta_{charge}\tau\right)+\frac{p_t\tau}{\eta_{discharge}} = 0``

``\eta`` are obtained from `storage`.


# Arguments

  * `model`: JuMP model
  * `storage`: A [`StorageDevice`](@ref)
  * `times`: A `Vector` of `DateTime`s
"""
function _add_constraint_intertemporal_soc!(
    model::JuMP.Model, storage::StorageDevice, times::Vector{DateTime}, τ::Float64
)
    η_charge = storage.η_charge
    η_discharge = storage.η_discharge
    soc_mwh = model[:soc_mwh]
    charge_mw = model[:charge_mw]
    discharge_mw = model[:discharge_mw]
    if length(times) < 2
        @debug "Intertemporal SoC constraint not added"
        return nothing
    else
        JuMP.@constraint(
            model,
            intertemporal_soc[t=times[2:end]],
            (
                soc_mwh[times[_get_times_index(t, times)]] # soc at time t
                -
                soc_mwh[times[_get_times_index(t, times) - 1]] # soc at time t-1
                -
                charge_mw[times[_get_times_index(t, times)]] * # calculate charge
                η_charge *
                τ + discharge_mw[times[_get_times_index(t, times)]] / # calculate discharge
                η_discharge * τ == 0
            )
        )
    end
end
