@doc raw"""
Adds a standard revenue-maximising objective function:

```math
\begin{aligned}
\max \quad & \sum_{t \in T}{\tau\lambda_t(p_t - q_t)}
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

@doc raw"""
Adds a revenue-maximising objective function that penalises storage throughput/cycling.

The penalty is the proportion of the warrantied throughput lifetime of the storage device
expended during the modelled period, multiplied by the cost of a new storage device. In
other words, the storage device replacement cost is amortised across throughput.

This bears similarities to the energy throughput model in
[this paper](https://link.springer.com/article/10.1557/s43581-022-00047-7).

```math
\begin{aligned}
\max \quad & \sum_{t \in T}{\tau\lambda_t(p_t - q_t)} - \frac{d_T - d_{0}}{d_{\textrm{lifetime}}}e_{\textrm{rated}}c_{\textrm{capital}}
\end{aligned}
```
# Arguments

  * `model`: JuMP model
  * `prices`: A `Vector` of prices in $/MWh
  * `times`: A `Vector` of `DateTime`s
  * `τ`: Frequency of `prices` in hours
  * `d_0`: Initial throughput of storage device in MWh
  * `d_lifetime`: Warrantied throughput lifetime of the storage device in MWh
  * `e_rated`: Storage energy capacity in MWh
  * `c_capital`: Capital cost of storage device in AUD/MWh

"""
function _add_objective_throughput_penalty!(
    model::JuMP.Model,
    prices::Vector{<:AbstractFloat},
    times::Vector{DateTime},
    τ::Float64,
    d_0::Float64,
    d_lifetime::Float64,
    e_rated::Float64,
    c_capital::Float64,
)
    discharge_mw = model[:discharge_mw]
    charge_mw = model[:charge_mw]
    throughput_mwh = model[:throughput_mwh]
    JuMP.@objective(
        model,
        Max,
        sum(
            prices[_get_times_index(t, times)] * τ * (discharge_mw[t] - charge_mw[t]) for
            t in times
        ) - (throughput_mwh[end] - d_0) / d_lifetime * e_rated * c_capital
    )
end

@doc raw"""
Adds a revenue-maximising objective function that penalises storage throughput/cycling.

The penalty is the proportion of the warrantied throughput lifetime of the storage device
expended during the modelled period, multiplied by the cost of a new storage device. In
other words, the storage device replacement cost is amortised across throughput.

This bears similarities to the energy throughput model in
[this paper](https://link.springer.com/article/10.1557/s43581-022-00047-7).

```math
\begin{aligned}
\max \quad & \sum_{t \in T}{\tau\lambda_t(p_t - q_t)} - \frac{d_T - d_{0}}{d_{\textrm{lifetime}}}e_{\textrm{rated}}c_{\textrm{capital}}
\end{aligned}
```
# Arguments

  * `model`: JuMP model
  * `prices`: A `Vector` of prices in $/MWh
  * `times`: A `Vector` of `DateTime`s
  * `τ`: Frequency of `prices` in hours
  * `d_0`: Initial throughput of storage device in MWh
  * `d_lifetime`: Warrantied throughput lifetime of the storage device in MWh
  * `e_rated`: Storage energy capacity in MWh
  * `c_capital`: Capital cost of storage device in AUD/MWh

"""
function _add_objective_throughput_penalty!(
    model::JuMP.Model,
    prices::Vector{<:AbstractFloat},
    times::Vector{DateTime},
    τ::Float64,
    d_0::Float64,
    d_lifetime::Float64,
    e_rated::Float64,
    c_capital::Float64,
)
    discharge_mw = model[:discharge_mw]
    charge_mw = model[:charge_mw]
    throughput_mwh = model[:throughput_mwh]
    JuMP.@objective(
        model,
        Max,
        sum(
            prices[_get_times_index(t, times)] * τ * (discharge_mw[t] - charge_mw[t]) for
            t in times
        ) - (throughput_mwh[end] - d_0) / d_lifetime * e_rated * c_capital
    )
end
