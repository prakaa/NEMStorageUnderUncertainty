"""
Calculates actual revenue and adds it as a column to `sim_results`.
  * Revenue is calculated for `binding` decisions
  * `non binding` decisions have `missing` revenue

# Arguments:

  * `sim_results`: DataFrame of simulation results
  * `actual_price_data`: DataFrame with actual price data
  (with `SETTLEMENTDATE` column and prices covering simulation period)
  * `tau`: Interval length in hours

# Returns

`sim_results` with `revenue` column.

"""
function calculate_actual_revenue(
    sim_results::DataFrame, actual_price_data::DataFrame, τ::Float64
)
    sort!(sim_results, :simulated_time)
    sort!(actual_price_data, :SETTLEMENTDATE)
    @assert(
        actual_price_data.SETTLEMENTDATE[1] ≤ sim_results.simulated_time[1],
        "Actual price data starts after the first simulated datetime"
    )
    @assert(
        actual_price_data.SETTLEMENTDATE[end] ≥ sim_results.simulated_time[end],
        "Actual price data ends before the last simulated datetime"
    )
    actual_price_data = rename(
        actual_price_data, :SETTLEMENTDATE => :simulated_time, :RRP => :actual_price
    )
    merged = leftjoin(sim_results, actual_price_data; on=[:simulated_time, :REGIONID])
    merged[!, :revenue] =
        merged[!, :actual_price] .* (merged[!, :discharge_mw] .- merged[!, :charge_mw]) * τ
    nonbinding_mask = sim_results.status .== "non binding"
    if !isempty(nonbinding_mask)
        allowmissing!(merged)
        merged[nonbinding_mask, :revenue] .= missing
    end
    return merged
end

"""
Runs a perfect foresight model across the period of an [`ActualData`](@ref) instance.

Perfect foresight entails:

  * Perfect knowledge of future price (hence use of actual price data)
  * Complete horizon lookahead

# Arguments

  * `optimizer`: A solver optimizer
  * `storage`: [`StorageDevice`](@ref)
  * `actual_data`: [`ActualData`](@ref)
  * `formulation`: A model formulation ([`StorageModelFormulation`](@ref))
  * `degradation`: A degradation model ([`DegradationModel`](@ref))
  * `silent`: default `false`. `true` to suppress solver output
  * `time_limit_sec`: default `nothing`. `Float64` to impose solver time limit in seconds
  * `string_names`: default `true`. `false` to disable JuMP string names

# Returns

Simulation results for the one binding decision point (i.e. at start of simulation period)
"""
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
        actual_data.times[end],
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

"""
Saves simulation results to a JLD2 (HDF5) data file

Simulation results (`data`) are saved in `results_file/group/key`

# Arguments

  * `results_file`: Path to file, including `.jld2` extension
  * `group`: Data group - `actual` or `forecast`
  * `key`: Dataset key - storage power capacity
  * `data`: Simulation results DataFrame
"""
function results_to_jld2(results_file::String, group::String, key::String, data::DataFrame)
    @assert results_file[(end - 4):end] == ".jld2" "File extension must be '.jld2'"
    jldopen(results_file, "a+"; compress=true) do f
        f["$(group)/$(key)"] = data
    end
    return nothing
end
