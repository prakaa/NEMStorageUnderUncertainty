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

Adds a revenue-maximising objective function that:

1. Models the storage device defending a [cap contract](https://www.aemc.gov.au/energy-system/electricity/electricity-market/spot-and-contract-markets).
   Cap contracts are sold at a price in $/MWh, and typically apply over a quarter or year.
   Futhermore, cap contracts that are sold by a generating participant can be defended
   across the entire *portfolio* of their generating assets (as opposed to any individual
   asset). As such, this representation only approximates how a storage device might be used
   to defend a cap contract.
2. Penalises storage throughput/cycling. The penalty is the proportion of the warrantied
   throughput lifetime of the storage device expended during the modelled period,
   multiplied by the cost of a new storage device. In other words, the storage device
   replacement cost is amortised across throughput. This bears similarities to the
   energy throughput model in [this paper](https://link.springer.com/article/10.1557/s43581-022-00047-7).

```math
\begin{aligned}
\max \quad & \sum_{t \in T}\left(\tau\lambda_t(p_t - q_t) - \tau\beta_tC(\lambda_t - 300)\right) - \frac{d_T - d_0}{d_{lifetime}} e_{rated} c_{capital}
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
  * `C`: Quantity of capacity "contracted" under cap contract (MW)

"""
function _add_objective_cap_contracted!(
    model::JuMP.Model,
    prices::Vector{<:AbstractFloat},
    times::Vector{DateTime},
    τ::Float64,
    d_0::Float64,
    d_lifetime::Float64,
    e_rated::Float64,
    c_capital::Float64,
    C::Float64,
)
    discharge_mw = model[:discharge_mw]
    charge_mw = model[:charge_mw]
    throughput_mwh = model[:throughput_mwh]
    beta_t = (prices .> 300.0)
    JuMP.@objective(
        model,
        Max,
        sum(
            prices[_get_times_index(t, times)] * τ * (discharge_mw[t] - charge_mw[t]) -
            τ *
            beta_t[_get_times_index(t, times)] *
            C *
            (prices[_get_times_index(t, times)] - 300.0) for t in times
        ) - (throughput_mwh[end] - d_0) / d_lifetime * e_rated * c_capital,
    )
end

@doc raw"""

Adds a revenue-maximising objective function that:

1. Models the storage device discounting decisions in the future based on a discount
   function $DF(r,t)$, where $r$ is the discount rate.
2. Penalises storage throughput/cycling. The penalty is the proportion of the warrantied
   throughput lifetime of the storage device expended during the modelled period,
   multiplied by the cost of a new storage device. In other words, the storage device
   replacement cost is amortised across throughput. This bears similarities to the
   energy throughput model in [this paper](https://link.springer.com/article/10.1557/s43581-022-00047-7).

```math
\begin{aligned}
\max \quad & \sum_{t \in T}\left(\tau(p_t - q_t) \times \lambda_t DF(r, t)\right) - \frac{d_T - d_0}{d_{lifetime}} e_{rated} c_{capital}
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
  * `discount_function`: Function that calculates discount factor $DF$. Should take a
                        `Vector` of discount times (hours ahead) and the discount rate
                         $r$ (per hour) as arguments.
  * `r`: Discount rate. Should have units $hr^{-1}$.

"""
function _add_objective_discounted!(
    model::JuMP.Model,
    prices::Vector{<:AbstractFloat},
    times::Vector{DateTime},
    τ::Float64,
    d_0::Float64,
    d_lifetime::Float64,
    e_rated::Float64,
    c_capital::Float64,
    discount_function::Function,
    r::Float64,
)
    discharge_mw = model[:discharge_mw]
    charge_mw = model[:charge_mw]
    throughput_mwh = model[:throughput_mwh]
    time_indices = range(1, length(times); step=1)
    if length(time_indices) == 1
        discount_factors = [1.0]
    else
        discount_times = time_indices .* τ
        discount_factors = discount_function(discount_times, r)
    end
    JuMP.@objective(
        model,
        Max,
        sum(
            τ *
            (discharge_mw[t] - charge_mw[t]) *
            prices[_get_times_index(t, times)] *
            discount_factors[_get_times_index(t, times)] for t in times
        ) - (throughput_mwh[end] - d_0) / d_lifetime * e_rated * c_capital,
    )
end
