@doc raw"""
Adds a standard revenue-maximising objective function:

```math
\begin{aligned}
\max_{t} \quad & \sum_{t}{\tau\lambda_t(p_t - q_t)}
\end{aligned}
```
# Arguments

  * `model`: JuMP model
  * `prices`: A `Vector` of prices in $/MWh
  * `times`: A `Vector` of `DateTime`s
  * `τ`: Frequency of `prices` in hours

"""
function _add_objective_standard!(
    model::JuMP.Model, prices::Vector{<:AbstractFloat}, times::Vector{DateTime}, τ::Float64
)
    discharge_mw = model[:discharge_mw]
    charge_mw = model[:charge_mw]
    JuMP.@objective(
        model,
        Max,
        sum(
            prices[_get_times_index(t, times)] * τ * (discharge_mw[t] - charge_mw[t]) for
            t in times
        )
    )
end
