abstract type Formulation end
"""
"""
abstract type StorageModelFormulation <: Formulation end
"""
"""
abstract type DegradationModel <: Formulation end

@doc raw"""
# Summary
Maximises storage revenue:

  * All periods are treated (weighted) equally
  * No cycling/throughput limits are modelled
  * Revenue is purely defined by the spot price for energy
  * Intertemporal SoC constraints are applied, including from `e₀` (initial SoC of storage
    device) to `e₁` (first modelled SoC)

```math
\begin{aligned}
  \max \quad & \sum_{t \in T}{\tau\lambda_t(p_t-q_t)}\\
  \textrm{s.t.} \quad & u_t \in \{0,1\}    \\
  & p_t \geq 0 \\
  & q_t \geq 0 \\
  & p_t - \bar{p}\left(1-u_t\right) \leq 0\\
  & q_t - \bar{p}u_t \leq 0\\
  & \underline{e} \leq e_t \leq \bar{e}    \\
  & e_t-e_{t-1}- \left( q_t\eta_{charge}\tau\right)+\frac{p_t\tau}{\eta_{discharge}} = 0\\
  & e_1 - e_0 - \left( q_1\eta_{charge}\tau\right)+\frac{p_1\tau}{\eta_{discharge}} = 0\\
\end{aligned}
```
"""
struct StandardArbitrage <: StorageModelFormulation end

@doc raw"""
# Summary
Maximises storage revenue subject to pro-rata application of throughput limits:

  * All periods are treated (weighted) equally
  * A throughput limit is modelled, with an annual throughput limit (`d_max`) specified
    * Each simulation includes this limit applied on a *pro rata* basis (i.e. proportion of
      year in each model horizon)
      * `d_max` for a model period is given by (where `d₀` is the initial
        storage device throughput):
        ``d_{max} = d_0 + \frac{t_T - t_1 + 5}{60 \times 24 \times 365} \times d_{limit}``
      * `d_binding_max` applies a similar limit to the binding period
      * `d_limit` is the throughput limit in MWh/year
  * Revenue is purely defined by the spot price for energy
  * Intertemporal SoC constraints are applied, including from `e₀` (initial SoC of storage
    device) to `e₁` (first modelled SoC)

```math
\begin{aligned}
  \max \quad & \sum_{t \in T}{\tau\lambda_t(p_t-q_t)}\\
  \textrm{s.t.} \quad & u_t \in \{0,1\}    \\
  & p_t \geq 0 \\
  & q_t \geq 0 \\
  & p_t - \bar{p}\left(1-u_t\right) \leq 0\\
  & q_t - \bar{p}u_t \leq 0\\
  & \underline{e} \leq e_t \leq \bar{e}    \\
  & e_t-e_{t-1}- \left( q_t\eta_{charge}\tau\right)+\frac{p_t\tau}{\eta_{discharge}} = 0\\
  & e_1 - e_0 - \left( q_1\eta_{charge}\tau\right)+\frac{p_1\tau}{\eta_{discharge}} = 0\\
  & d_t-d_{t-1} - p_t\tau = 0\\
  & d_1 - d_0 - p_1\tau = 0\\
  & d_{t_{binding, end}} ≤ d_{binding_{max}} \\
  & d_T ≤ d_{max}\\
\end{aligned}
```
"""
struct StandardArbitrageThroughputLimit <: StorageModelFormulation
    throughput_mwh_per_year::Float64
end

@doc raw"""
# Summary
Maximises storage revenue subject to pro-rata penalisation of throughput/cycling:

  * All periods are treated (weighted) equally
  * No cycling/throughput limits are imposed on the storage device
  * Revenue is defined by the spot price for energy and is penalised based on throughput
    * The penalty is the proportion of the warrantied throughput lifetime of the storage
      device expended during the modelled period,
      multiplied by the cost of a new storage device
  * Intertemporal SoC constraints are applied, including from `e₀` (initial SoC of storage
    device) to `e₁` (first modelled SoC)

```math
\begin{aligned}
  \max \quad & \sum_{t \in T}{\tau\lambda_t(p_t - q_t)} - \frac{d_T - d_0}{d_{lifetime}} e_{rated} c_{capital} \\
  \textrm{s.t.} \quad & u_t \in \{0,1\}    \\
  & p_t \geq 0 \\
  & q_t \geq 0 \\
  & p_t - \bar{p}\left(1-u_t\right) \leq 0\\
  & q_t - \bar{p}u_t \leq 0\\
  & \underline{e} \leq e_t \leq \bar{e}    \\
  & e_t-e_{t-1}- \left( q_t\eta_{charge}\tau\right)+\frac{p_t\tau}{\eta_{discharge}} = 0\\
  & e_1 - e_0 - \left( q_1\eta_{charge}\tau\right)+\frac{p_1\tau}{\eta_{discharge}} = 0\\
  & d_t-d_{t-1} - p_t\tau = 0\\
  & d_1 - d_0 - p_1\tau = 0\\
\end{aligned}
```

# Attributes

  * `d_lifetime`: Warrantied throughput lifetime of the storage device in MWh
  * `c_capital`: Capital cost of storage device in AUD/MWh
```
"""
struct ArbitrageThroughputPenalty <: StorageModelFormulation
    d_lifetime::Float64
    c_capital::Float64
end

@doc raw"""
# Summary
Maximises storage revenue subject to:
  1. Pro-rata penalisation of throughput/cycling
  2. Device defending cap contract

  * All periods are treated (weighted) equally
  * No cycling/throughput limits are imposed on the storage device
  * Revenue is defined by the spot price for energy and is penalised based on throughput
    and cap contract defence
    * The penalty is the proportion of the warrantied throughput lifetime of the storage
      device expended during the modelled period,
      multiplied by the cost of a new storage device
     * Cap contracts that are sold by a generating participant can be defended across the
       entire *portfolio* of their generating assets (as opposed to any individual asset).
       As such, this representation only approximates how a storage device might be used
       to defend a cap contract.
  * Intertemporal SoC constraints are applied, including from `e₀` (initial SoC of storage
    device) to `e₁` (first modelled SoC)

```math
\begin{aligned}
  \max \quad & \sum_{t \in T}\left(\tau\lambda_t(p_t - q_t) - \tau\beta_tC(\lambda_t - 300)\right) - \frac{d_T - d_0}{d_{lifetime}} e_{rated} c_{capital} \\
  \textrm{s.t.} \quad & u_t \in \{0,1\}    \\
  & p_t \geq 0 \\
  & q_t \geq 0 \\
  & p_t - \bar{p}\left(1-u_t\right) \leq 0\\
  & q_t - \bar{p}u_t \leq 0\\
  & \underline{e} \leq e_t \leq \bar{e}    \\
  & e_t-e_{t-1}- \left( q_t\eta_{charge}\tau\right)+\frac{p_t\tau}{\eta_{discharge}} = 0\\
  & e_1 - e_0 - \left( q_1\eta_{charge}\tau\right)+\frac{p_1\tau}{\eta_{discharge}} = 0\\
  & d_t-d_{t-1} - p_t\tau = 0\\
  & d_1 - d_0 - p_1\tau = 0\\
\end{aligned}
```

# Attributes

  * `d_lifetime`: Warrantied throughput lifetime of the storage device in MWh
  * `c_capital`: Capital cost of storage device in AUD/MWh
  * `C`: Quantity of capacity "contracted" under cap contract (MW)
```
"""
struct ArbitrageCapContracted <: StorageModelFormulation
    d_lifetime::Float64
    c_capital::Float64
    C::Float64
end

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

"""
No storage degradation modelled in simulations.
"""
struct NoDegradation <: DegradationModel end
