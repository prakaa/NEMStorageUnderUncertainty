using DataFrames
using JLD2
using NEMStorageUnderUncertainty
using Statistics

const SCENARIO_COLS = [
    :formulation, :energy_capacity, :power_capacity, :data_type, :lookahead
]

function merge_summary_data(standard_data_path::String, apb_data_path::String)
    for path in (standard_data_path, apb_data_path)
        @assert isfile(path)
    end
    standard_data = load(standard_data_path)
    apb_data = load(apb_data_path)
    all_merged = DataFrame[]
    for key in keys(standard_data)
        (df_standard, df_apb) = (standard_data[key], apb_data[key])
        df_standard_forecast = df_standard[df_standard.data_type.=="forecast", :]
        df_apb_forecast = df_apb[df_apb.data_type.=="forecast", :]
        merged = innerjoin(
            df_standard_forecast,
            df_apb_forecast,
            on=SCENARIO_COLS,
            renamecols="_standard" => "_apb"
        )
        push!(all_merged, merged)
    end
    return all_merged
end

"""
Calculates three metrics

- `rev_improvement`: Improvement in actual-prices-binding scenario
    from standard scenario as % of standard revenue
- `neg_rev_discharge_percent`: Negative revenue from discharge in standard scenario
    as % of standard revenue
- `neg_rev_charge_500_percent`: Negative revenue from charging in standard scenario
    when price ≥ 500 as % of standard revenue
"""
function calculate_metrics(all_merged_data::Array{DataFrame})
    all_metrics = DataFrame[]
    metric_cols = [
        :rev_improvement_percent, :neg_rev_discharge_percent, :neg_rev_charge_500_percent
    ]
    for df in all_merged_data
        df[:, metric_cols[1]] = @. (df[:, :revenue_apb] - df[:, :revenue_standard]) / (df[:, :revenue_standard]) * 100
        df[:, metric_cols[2]] = @. -1 * df[:, :neg_rev_discharge_standard] / (df[:, :revenue_standard]) * 100
        df[:, metric_cols[3]] = @. -1 * df[:, :neg_rev_discharge_standard] / (df[:, :revenue_standard]) * 100
        push!(all_metrics, df[:, cat(SCENARIO_COLS, metric_cols, dims=1)])
    end
    return all_metrics
end

function summarise_metrics(all_metrics::Array{DataFrame})
    function _filter_results!(df::DataFrame)
        filtered = df[df.lookahead.!=="Perfect Foresight".&&df.power_capacity.>12.5.&&df.power_capacity.<800, :]
        return filtered
    end
    formulations = String[]
    min_rev_improvements = Float64[]
    med_rev_improvements = Float64[]
    max_rev_improvements = Float64[]
    max_neg_rev_discharge_percents = Float64[]
    max_neg_rev_charge_500_percents = Float64[]
    for df in all_metrics
        filtered_df = _filter_results!(df)
        push!(formulations, only(unique(filtered_df.formulation)))
        push!(min_rev_improvements, minimum(filtered_df[filtered_df.lookahead.!="5", :rev_improvement_percent]))
        push!(med_rev_improvements, median(filtered_df.rev_improvement_percent))
        push!(max_rev_improvements, maximum(filtered_df.rev_improvement_percent))
        push!(max_neg_rev_discharge_percents, maximum(filtered_df.neg_rev_discharge_percent))
        push!(max_neg_rev_charge_500_percents, maximum(filtered_df.neg_rev_charge_500_percent))
    end
    return DataFrame(
        :formulation => formulations,
        :min_rev_improvements_lkgt5 => min_rev_improvements,
        :med_rev_improvements => med_rev_improvements,
        :max_rev_improvement => max_rev_improvements,
        :max_neg_rev_discharge_percent => max_neg_rev_discharge_percents,
        :max_neg_rev_charge_500_percent => max_neg_rev_charge_500_percents
    )
end

merged = merge_summary_data("results/data/NSW_summary_results.jld2", "results/data/actual-prices-binding/NSW_summary_results_apb.jld2")
metrics = calculate_metrics(merged)
summary = summarise_metrics(metrics)
