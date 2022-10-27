@doc raw"""
Adds variables for charging in MW (``q_t``) and discharging in MW (``p_t``).

The following variable bounds are applied:
  * ``0 \leq p_t \leq \bar{p}``
  * ``0 \leq q_t \leq \bar{p}``

# Arguments

  * `model`: JuMP model
  * `storage`: A [`StorageDevice`](@ref)
  * `times`: A `Vector` of `DateTime`s
"""
function _add_variables_power!(
    model::JuMP.Model, storage::StorageDevice, times::Vector{DateTime}
)
    power_capacity = storage.power_capacity
    JuMP.@variables(
        model,
        begin
            0.0 ≤ discharge_mw[times] ≤ power_capacity
            0.0 ≤ charge_mw[times] ≤ power_capacity
        end
    )
end

@doc raw"""
Adds variable that tracks state-of-charge (SoC, ``e_t``).

The following variable bound is applied: ``\underline{e} \leq e_t \leq \bar{e}``, where
the limits represent the lower and upper SoC limits obtained from `storage`.

# Arguments

  * `model`: JuMP model
  * `storage`: A [`StorageDevice`](@ref)
  * `times`: A `Vector` of `DateTime`s
"""
function _add_variable_soc!(
    model::JuMP.Model, storage::StorageDevice, times::Vector{DateTime}
)
    min_soc = storage.soc_min
    max_soc = storage.soc_max
    JuMP.@variable(model, min_soc ≤ soc_mwh[times] ≤ max_soc)
end

@doc raw"""
Adds binary variable that indicates charging (i.e. ``u_t=1``) when charging.

# Arguments

  * `model`: JuMP model
  * `times`: A `Vector` of `DateTime`s
"""
function _add_variable_charge_state!(model::JuMP.Model, times::Vector{DateTime})
    JuMP.@variable(model, charge_state[times], binary = true)
end
