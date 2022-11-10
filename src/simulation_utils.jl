function calculate_actual_revenue!(
    sim_results::DataFrame, actual_price_data::DataFrame, τ::Float64
)
    binding_sim_results = filter(:status => status -> status == "binding", sim_results)
    sort!(binding_sim_results, :simulated_time)
    sort!(actual_price_data, :SETTLEMENTDATE)
    @assert(
        actual_price_data.SETTLEMENTDATE[1] ≤ binding_sim_results.simulated_time[1],
        "Actual price data starts after the first simulated datetime"
    )
    @assert(
        actual_price_data.SETTLEMENTDATE[end] ≥ binding_sim_results.simulated_time[end],
        "Actual price data ends before the last simulated datetime"
    )
    actual_price_data = rename(
        actual_price_data, :SETTLEMENTDATE => :simulated_time, :RRP => :actual_price
    )
    merged = leftjoin(
        binding_sim_results, actual_price_data; on=[:simulated_time, :REGIONID]
    )
    merged[!, :revenue] =
        merged[!, :actual_price] .* (merged[!, :discharge_mw] .- merged[!, :charge_mw]) * τ
    return merged
end

function run_perfect_foresight(
    optimizer::OptimizerWithAttributes,
    storage::StorageDevice,
    actual_data::ActualData,
    formulation::StorageModelFormulation,
    degradation::DegradationModel;
    silent::Bool=false,
    time_limit_sec::Union{Float64,Nothing}=nothing,
    string_names::Bool=true,
)
    model = run_model(
        optimizer,
        storage,
        actual_data.prices,
        actual_data.times,
        actual_data.τ,
        formulation,
        degradation;
        silent=silent,
        time_limit_sec=time_limit_sec,
        string_names=string_names,
    )
    (_, binding_results) = _retrieve_results(
        model, actual_data.times[1], actual_data.times[2], actual_data.times[end]
    )
    binding_results[:, :REGIONID] .= actual_data.region
    binding_results[:, :lookahead_minutes] .= Dates.value(
        Minute(actual_data.times[end] - actual_data.times[1])
    )
    binding_results[:, :relative_gap] .= get(model, RelativeGap())
    return binding_results
end

function results_to_jld2(results_file::String, group::String, key::String, data::DataFrame)
    @assert results_file[(end - 4):end] == ".jld2" "File extension must be '.jld2'"
    jldopen(results_file, "a+"; compress=true) do f
        f["$(group)/$(key)"] = data
    end
    return nothing
end
