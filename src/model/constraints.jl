@doc raw"""
    _add_constraints_charge_state!(
        model::JuMP.Model, storage::StorageDevice, times::Vector{DateTime}
    )

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
    power_cap = storage.power_cap
    JuMP.@constraints(
        model,
        begin
            discharge_operation[t=times],
            discharge_mw[t] - power_cap * (1 - charge_state[t]) ≤ 0
            charge_operation[t=times], charge_mw[t] - power_cap * charge_state[t] ≤ 0
        end
    )
end

@doc raw"""
    _add_constraint_initial_soc!(
        model::JuMP.Model, storage::StorageDevice, times::Vector{DateTime}
    )

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
    soc₀ = storage.soc₀
    JuMP.@constraint(model, initial_soc, soc_mwh[times[1]] == soc₀)
end

@doc raw"""
   _add_constraint_intertemporal_soc!(
    model::JuMP.Model, storage::StorageDevice, times::Vector{DateTime}
    )

Adds the following constraint to `model`:
``e_t-e_{t-1}- \left( q_t\eta_{charge}\tau\right)+\frac{p_t\tau}{\eta_{discharge}} = 0``

``\tau`` is calculated dynamically (i.e. using `times`) and has units hours.

``\eta`` are obtained from `storage`.

# Arguments

  * `model`: JuMP model
  * `storage`: A [`StorageDevice`](@ref)
  * `times`: A `Vector` of `DateTime`s
"""
function _add_constraint_intertemporal_soc!(
    model::JuMP.Model, storage::StorageDevice, times::Vector{DateTime}
)
    η_charge = storage.η_charge
    η_discharge = storage.η_discharge
    if length(times) < 2
        return nothing
    else
        get_times_index(t, times) = findall(time -> time == t, times)[]
        JuMP.@constraint(
            model,
            intertemporal_soc[t=times[2:end]],
            (
                soc_mwh[times[get_times_index(t, times)]] # soc at time t
                -
                soc_mwh[times[get_times_index(t, times) - 1]] # soc at time t-1
                -
                charge_mw[times[get_times_index(t, times)]] * # calculate charge
                η_charge *
                Minute(
                    times[get_times_index(t, times)] - times[get_times_index(t, times) - 1]
                ).value / 60.0  # dynamically calculate τ as hours
                +
                discharge_mw[times[get_times_index(t, times)]] / # calculate discharge
                η_discharge *
                Minute(
                    times[get_times_index(t, times)] - times[get_times_index(t, times) - 1]
                ).value / 60.0 # dynamically calculate τ as hours
                == 0
            )
        )
    end
end
