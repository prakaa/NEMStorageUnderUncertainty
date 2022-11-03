"""
Gets decision points, binding intervals and horizon ends given [`ActualData`](@ref) and
simulation parameters.

# Arguments

  - `decision_start_time`: Decision start time.
  - `decision_end_time`: Decision end time.
  - `binding`: `decision_time` + `binding` gives the last binding period
  - `horizon`: `decision_time` + `horizon` gives the end of the simulation horizon
  - `data`: [`ActualData`](@ref)

# Returns

`DataFrame` with the following columns:

1. `decision_interval`: `data.times` indices that correspond to decision points
2. `binding_start`: `data.times` indices that correspond to the first
   binding period for each simulation.
3. `binding_end`: `data.times` indices that correspond to the last
   binding period for each simulation.
4. `horizon_end`: `data.times` indices that correspond to the horizon end for
   each simulation

"""
function _get_periods_for_simulation(
    decision_start_time::DateTime,
    decision_end_time::DateTime,
    binding::T,
    horizon::T,
    data::ActualData,
) where {T<:Period}
    interval_length = Minute(Int64(data.τ * 60.0))
    times = data.times
    (decision_start, decision_end) = (
        findfirst(t -> t == decision_start_time, times),
        findfirst(t -> t == decision_end_time, times),
    )
    @assert(
        !isnothing(decision_start),
        "First decision time $(decision_start_time) not in data.times"
    )
    @assert(
        !isnothing(decision_end),
        "Last decision time $(decision_end_time) not in data.times"
    )
    binding_start = decision_start + 1
    (binding_n, horizon_n) = @. Int64(Minute.((binding, horizon)) / interval_length)
    horizon_end = decision_start + horizon_n
    @assert(0 < binding_n ≤ horizon_n, "0 < binding ≤ $horizon (horizon)")
    @assert(
        horizon_n ≤ length(times),
        "Horizon is longer than data (max of ($(data.times[end] - data.times[1]))"
    )
    @assert(
        decision_end + horizon_n ≤ length(times),
        (
            "Data insufficient to run final decision point at $(decision_end_time)" *
            " (need data to $(decision_end_time + horizon))"
        )
    )
    @assert(
        (decision_end - decision_start) % binding_n == 0,
        (
            "An integer number of decision times cannot be run between decision start " *
            "and end times. Change these, or change the binding time" *
            "(($decision_end - $decision_start) % $binding_n != 0)"
        )
    )
    decision_n = decision_start
    n_iterations = length(decision_start_time:binding:decision_end_time)
    period_data = Array{Int64,2}(undef, n_iterations, 4)
    n = 1
    while decision_n ≤ decision_end
        binding_end = decision_n + binding_n
        period_data[n, 1] = decision_n
        period_data[n, 2] = binding_start
        period_data[n, 3] = binding_end
        period_data[n, 4] = horizon_end
        decision_n = binding_end
        (binding_start, horizon_end) = (decision_n + 1, decision_n + horizon_n)
        n += 1
    end
    period_data = DataFrame(period_data, :auto)
    rename!(period_data, [:decision_interval, :binding_start, :binding_end, :horizon_end])
    return period_data
end

"""
Gets decision points, binding intervals and horizon ends given [`ForecastData`](@ref) and
simulation parameters.

# Arguments

  - `decision_start_time`: Decision start time. Applies to `run_time`
  - `decision_end_time`: Decision end time. Applies to `run_time`
  - `binding`: `decision_time` + `binding` gives the last binding period.
    Applies to `forecasted_time`
  - `horizon`: `decision_time` + `horizon` gives the end of the simulation horizon.
    Applies to `forecasted_time`
  - `data`: [`ForecastData`](@ref)

# Returns

`DataFrame` with the following columns:

1. `decision_interval`: `data.times` indices that correspond to `run_time` decision points
2. `binding_start`: `data.times` indices that correspond to the first
   binding period for each simulation. Applies to `forecasted_time`.
3. `binding_end`: `data.times` indices that correspond to the last
   binding period for each simulation. Applies to `forecasted_time`
4. `horizon_end`: `data.times` indices that correspond to the horizon end for
   each simulation. Applies to `forecasted_time`

"""
function _get_periods_for_simulation(
    decision_start_time::DateTime,
    decision_end_time::DateTime,
    binding::T,
    horizon::T,
    data::ForecastData,
) where {T<:Period}
    function _validate_time_inputs(
        data::ForecastData, decision_start_time::DateTime, decision_end_time::DateTime
    )
        (run_times, forecasted_times) = (data.run_times, data.forecasted_times)
        @assert(
            !isnothing(_get_first_index_for_time(run_times, decision_start_time)),
            "First decision time $(decision_start_time) not in data.run_times"
        )
        @assert(
            !isnothing(_get_first_index_for_time(run_times, decision_end_time)),
            "Last decision time $(decision_end_time) not in data.run_times"
        )
        @assert(
            !isnothing(
                _get_first_index_for_time(forecasted_times, decision_end_time + horizon)
            ),
            (
                "Data insufficient to run final decision point at $(decision_end_time)" *
                " (forecasted data should go up to $(decision_end_time + horizon))"
            )
        )
        return run_times, forecasted_times
    end

    function _get_first_index_for_time(vec::Vector{DateTime}, dt::DateTime)
        return findfirst(t -> t == dt, vec)
    end

    function _create_run_time_index_ref(data::ForecastData, decision_end_time::DateTime)
        df = convert(DataFrame, data)
        df[!, :index] = 1:size(df)[1]
        first_idx = combine(groupby(df, :actual_run_times), :index => first)
        filter!(:actual_run_times => dt -> dt ≤ decision_end_time, first_idx)
        return first_idx[!, :index_first]
    end

    @assert(data.run_time_aligned, "ForecastData should be aligned by run times")
    interval_length = Minute(Int64(data.τ * 60.0))
    (run_times, forecasted_times) = _validate_time_inputs(
        data, decision_start_time, decision_end_time
    )
    (decision_start, decision_end) = (
        _get_first_index_for_time(run_times, decision_start_time),
        _get_first_index_for_time(run_times, decision_end_time),
    )
    (binding_n, horizon_n) = @. Int64(Minute.((binding, horizon)) / interval_length)
    @assert(0 < binding_n ≤ horizon_n, "0 < binding ≤ $horizon (horizon)")
    decision_n = decision_start
    rt_index_ref = _create_run_time_index_ref(data, decision_end_time)
    index_ref = findfirst(i -> i == decision_start, rt_index_ref)
    @assert(
        (length(rt_index_ref) - index_ref) % binding_n == 0,
        (
            "An integer number of decision times cannot be run between decision start " *
            "and end times. Change these, or change the binding time" *
            "(($(length(rt_index_ref)) - $index_ref) % $binding_n != 0)"
        )
    )
    n_iterations = length(decision_start_time:binding:decision_end_time)
    period_data = Array{Int64,2}(undef, n_iterations, 4)
    n = 1
    while decision_n ≤ decision_end
        period_data[n, 1] = decision_n
        decision_time = run_times[decision_n]
        # binding applies to forecasted_time
        binding_start = decision_n
        binding_end = decision_n + binding_n - 1
        @assert(
            forecasted_times[binding_end] == decision_time + binding,
            (
                "Forecasted times do not extend to `decision_time + binding`" *
                "($(decision_time + binding)) for run time $decision_time"
            )
        )
        period_data[n, 2] = binding_start
        period_data[n, 3] = binding_end
        # horizon applies to forecasted_time
        horizon_end = decision_n + horizon_n - 1
        @assert(
            forecasted_times[horizon_end] == decision_time + horizon,
            (
                "Forecasted times do not extend to `decision_time + horizon`" *
                "($(decision_time + horizon)) for run time $decision_time"
            )
        )
        period_data[n, 4] = horizon_end
        index_ref += binding_n
        if index_ref > length(rt_index_ref)
            decision_n += 1
        else
            decision_n = rt_index_ref[index_ref]
        end
        n += 1
    end
    period_data = DataFrame(period_data, :auto)
    rename!(period_data, [:decision_interval, :binding_start, :binding_end, :horizon_end])
    return period_data
end

function _retrieve_results(
    m::JuMP.Model, decision_time::DateTime, binding_start::DateTime, binding_end::DateTime
)
    vars = (:charge_mw, :discharge_mw, :soc_mwh, :charge_state)
    var_solns = Vector{DataFrame}(undef, length(vars))
    for (i, var) in enumerate(vars)
        table = JuMP.Containers.rowtable(JuMP.value.(m[var]); header=[:simulated_time, var])
        var_solns[i] = DataFrame(table)
    end
    results = innerjoin(var_solns...; on=:simulated_time)
    results[:, :decision_time] .= decision_time
    binding = results[binding_start .≤ results.simulated_time .≤ binding_end, :]
    binding[:, :status] .= "binding"
    non_binding = results[binding_end .< results.simulated_time, :]
    non_binding[:, :status] .= "non binding"
    return non_binding, binding
end

"""
"Updates" (via new `StorageDevice`) storage state between model runs. Specifically:

  * Updates `soc₀` to reflect `soc` at end of binding decisions from last model run
  * Updates storage `throughput` based on model run
    * `throughput` is defined as discharged energy, and hence does not consider η_discharge

# Arguments

  * `storage`: [`StorageDevice`](@ref)
  * `binding_results`: Binding results from last model run
  * `τ`: Interval duration in hours
  * `degradation`: No degradation model [`NoDegradation`](@ref)

# Returns

New [`StorageDevice`](@ref) with updated `soc₀` and `throughput`
"""
function _update_storage_state(
    storage::StorageDevice, binding_results::DataFrame, τ::Float64, ::NoDegradation
)
    new_soc₀ = binding_results[end, :soc_mwh]
    new_throughput = storage.throughput + sum(binding_results[:, :discharge_mw] * τ)
    return copy(storage, new_soc₀, new_throughput)
end

function simulate_storage_operation(
    optimizer::OptimizerWithAttributes,
    storage::StorageDevice,
    data::ActualData,
    model_formulation::StorageModelFormulation,
    degradation::DegradationModel;
    decision_start_time::DateTime,
    decision_end_time::DateTime,
    binding::T,
    horizon::T,
    capture_all_decisions::Bool=false,
    silent::Bool=true,
    show_progress::Bool=true,
    time_limit_sec::Union{Float64,Nothing}=nothing,
    string_names::Bool=true,
) where {T<:Period}
    @assert(
        decision_start_time ≤ decision_end_time, "Decision start time ≤ decision end time"
    )
    if silent
        disable_logging(Logging.Info)
    end
    (times, prices) = (data.times, data.prices)
    sim_periods = _get_periods_for_simulation(
        decision_start_time, decision_end_time, binding, horizon, data
    )
    @info("""
        Running actual data simulation with $model_formulation and $degradation:
            decision_start_time: $decision_start_time
            decision_end_time: $decision_end_time
            binding: $binding
            horizon: $horizon
            """)
    binding_results = Vector{DataFrame}(undef, size(sim_periods)[1])
    if capture_all_decisions
        non_binding_results = Vector{DataFrame}(undef, size(sim_periods)[1])
    end
    p = Progress(size(sim_periods)[1]; enabled=show_progress)
    for (i, sim_period) in enumerate(eachrow(sim_periods))
        sim_indices = sim_period[:binding_start]:1:sim_period[:horizon_end]
        decision_time = times[sim_period[:decision_interval]]
        binding_start_time = times[sim_indices[1]]
        binding_end_time = times[sim_period[:binding_end]]
        simulate_times = times[sim_indices]
        simulate_prices = prices[sim_indices]
        m = run_model(
            optimizer,
            storage,
            simulate_prices,
            simulate_times,
            data.τ,
            model_formulation;
            silent=silent,
            time_limit_sec=time_limit_sec,
            string_names=string_names,
        )
        non_binding_result, binding_result = _retrieve_results(
            m, decision_time, binding_start_time, binding_end_time
        )
        binding_results[i] = binding_result
        if capture_all_decisions
            non_binding_results[i] = non_binding_result
        end
        storage = _update_storage_state(storage, binding_result, data.τ, degradation)
        next!(p)
    end
    if capture_all_decisions
        non_binding_df = vcat(non_binding_results...)
        binding_df = vcat(binding_results...)
        results_df = sort!(vcat(binding_df, non_binding_df), :decision_time)
    else
        results_df = vcat(binding_results...)
    end
    results_df[:, :lookahead_minutes] .= Dates.value(Minute(horizon))
    results_df[:, :REGIONID] .= data.region
    return results_df
end

function simulate_storage_operation(
    optimizer::OptimizerWithAttributes,
    storage::StorageDevice,
    data::ForecastData,
    model_formulation::StorageModelFormulation,
    degradation::DegradationModel;
    decision_start_time::DateTime,
    decision_end_time::DateTime,
    binding::T,
    horizon::T,
    capture_all_decisions::Bool=false,
    silent::Bool=true,
    show_progress::Bool=true,
    time_limit_sec::Union{Float64,Nothing}=nothing,
    string_names::Bool=true,
) where {T<:Period}
    @assert(
        decision_start_time ≤ decision_end_time, "Decision start time ≤ decision end time"
    )
    if silent
        disable_logging(Logging.Info)
    end
    (run_times, forecasted_times, prices) = (
        data.run_times, data.forecasted_times, data.prices
    )
    sim_periods = _get_periods_for_simulation(
        decision_start_time, decision_end_time, binding, horizon, data
    )
    @info("""
        Running forecast data simulation with $model_formulation and $degradation:
            decision_start_time: $decision_start_time
            decision_end_time: $decision_end_time
            binding: $binding
            horizon: $horizon
            """)
    binding_results = Vector{DataFrame}(undef, size(sim_periods)[1])
    if capture_all_decisions
        non_binding_results = Vector{DataFrame}(undef, size(sim_periods)[1])
    end
    p = Progress(size(sim_periods)[1]; enabled=show_progress)
    for (i, sim_period) in enumerate(eachrow(sim_periods))
        sim_indices = sim_period[:binding_start]:1:sim_period[:horizon_end]
        decision_time = run_times[sim_period[:decision_interval]]
        binding_start_time = forecasted_times[sim_indices[1]]
        binding_end_time = forecasted_times[sim_period[:binding_end]]
        simulate_times = forecasted_times[sim_indices]
        simulate_prices = prices[sim_indices]
        m = run_model(
            optimizer,
            storage,
            simulate_prices,
            simulate_times,
            data.τ,
            model_formulation;
            silent=silent,
            time_limit_sec=time_limit_sec,
            string_names=string_names,
        )
        non_binding_result, binding_result = _retrieve_results(
            m, decision_time, binding_start_time, binding_end_time
        )
        binding_results[i] = binding_result
        if capture_all_decisions
            non_binding_results[i] = non_binding_result
        end
        storage = _update_storage_state(storage, binding_result, data.τ, degradation)
        next!(p)
    end
    if capture_all_decisions
        non_binding_df = vcat(non_binding_results...)
        binding_df = vcat(binding_results...)
        results_df = sort!(vcat(binding_df, non_binding_df), :decision_time)
    else
        results_df = vcat(binding_results...)
    end
    results_df[:, :lookahead_minutes] .= Dates.value(Minute(horizon))
    results_df[:, :REGIONID] .= data.region
    return results_df
end
