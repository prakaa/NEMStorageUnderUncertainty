using DataFrames
using JLD2
using NEMStorageUnderUncertainty
using Statistics
using CSV

const SCENARIO_COLS = [
    :formulation, :energy_capacity, :power_capacity, :data_type, :lookahead
]

"""
Merge APB variant summary data into standard forecast simulation summary data

Drop 1:8 and 8:1 power ratios

"""
function merge_summary_data(standard_data_path::String, apb_data_path::String)
    for path in (standard_data_path, apb_data_path)
        @assert isfile(path)
    end
    standard_data = load(standard_data_path)
    apb_data = load(apb_data_path)
    all_merged = DataFrame[]
    for key in keys(standard_data)
        (df_standard, df_apb) = (standard_data[key], apb_data[key])
        df_standard.formulation = fill(key, size(df_standard, 1))
        df_apb.formulation = fill(key, size(df_apb, 1))
        df_standard_forecast = df_standard[df_standard.data_type.=="forecast", :]
        df_standard_forecast = df_standard_forecast[(df_standard_forecast.power_capacity.>=25.0).&(df_standard_forecast.power_capacity.<=400.0), :]
        df_apb_forecast = df_apb[df_apb.data_type.=="forecast", :]
        df_apb_forecast = df_apb_forecast[(df_apb_forecast.power_capacity.>=25.0).&(df_apb_forecast.power_capacity.<=400.0), :]
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

- `neg_rev_discharge_percent_standard`: Negative revenue from discharge in standard scenario
    as % of standard revenue
- `neg_rev_charge_500_percent_standard`: Negative revenue from charging in standard scenario
    when price ≥ 500 as % of standard revenue
- `neg_rev_discharge_percent_apb`: Negative revenue from discharge in APB scenario
    as % of APB revenue
- `neg_rev_charge_500_percent_apb`: Negative revenue from charging in APB scenario
    when price ≥ 500 as % of APB revenue
- `rev_improvement`: Improvement in actual-prices-binding scenario
    from standard scenario as % of standard revenue
"""
function calculate_metrics(all_merged_data::Array{DataFrame})
    all_metrics = DataFrame[]
    metric_cols = [
        :rev_improvement,
        :neg_rev_discharge_standard,
        :neg_rev_charge_500_standard,
        :neg_rev_discharge_apb,
        :neg_rev_charge_500_apb,
    ]
    for df in all_merged_data
        df[:, metric_cols[1]] = @. (df[:, :revenue_apb] - df[:, :revenue_standard]) / (df[:, :revenue_standard])
        df[:, metric_cols[2]] = @. -1 * df[:, :neg_rev_discharge_standard] / (df[:, :revenue_standard])
        df[:, metric_cols[3]] = @. -1 * df[:, :neg_rev_charge_500_standard] / (df[:, :revenue_standard])
        df[:, metric_cols[4]] = @. -1 * df[:, :neg_rev_discharge_apb] / (df[:, :revenue_apb])
        df[:, metric_cols[5]] = @. -1 * df[:, :neg_rev_charge_500_apb] / (df[:, :revenue_apb])
        push!(all_metrics, df[:, cat(SCENARIO_COLS, metric_cols, dims=1)])
    end
    return all_metrics
end

"""
Produce revenue improvement and negative revenue metrics by formulation
"""
function summarise_formulation_metrics(all_metrics::Array{DataFrame})
    function _filter_results!(df::DataFrame)
        filtered = df[df.lookahead.!=="Perfect Foresight", :]
        return filtered
    end
    formulations = String[]
    min_rev_improvements = Float64[]
    med_rev_improvements = Float64[]
    max_rev_improvements = Float64[]
    max_neg_rev_discharge_standard = Float64[]
    max_neg_rev_charge_500_standard = Float64[]
    max_neg_rev_discharge_apb = Float64[]
    max_neg_rev_charge_500_apb = Float64[]
    for df in all_metrics
        filtered_df = _filter_results!(df)
        push!(formulations, only(unique(filtered_df.formulation)))
        push!(min_rev_improvements, minimum(filtered_df[filtered_df.lookahead.!="5", :rev_improvement]))
        push!(med_rev_improvements, median(filtered_df.rev_improvement))
        push!(max_rev_improvements, maximum(filtered_df.rev_improvement))
        push!(max_neg_rev_discharge_standard, maximum(filtered_df.neg_rev_discharge_standard))
        push!(max_neg_rev_charge_500_standard, maximum(filtered_df.neg_rev_charge_500_standard))
        push!(max_neg_rev_discharge_apb, maximum(filtered_df.neg_rev_discharge_apb))
        push!(max_neg_rev_charge_500_apb, maximum(filtered_df.neg_rev_charge_500_apb))
    end
    return DataFrame(
        :formulation => formulations,
        :min_rev_improvements_lkgt5 => min_rev_improvements,
        :med_rev_improvements => med_rev_improvements,
        :max_rev_improvement => max_rev_improvements,
        :max_neg_rev_discharge_standard => max_neg_rev_discharge_standard,
        :max_neg_rev_charge_500_standard => max_neg_rev_charge_500_standard,
        :max_neg_rev_discharge_apb => max_neg_rev_discharge_apb,
        :max_neg_rev_charge_500_apb => max_neg_rev_charge_500_apb,
    )
end

"""
Produce negative revenue from charging metrics by storage duration
"""
function summarise_duration_metrics(all_metrics::Array{DataFrame})
    function _filter_results!(df::DataFrame)
        filtered = df[df.lookahead.!=="Perfect Foresight", :]
        return filtered
    end
    duration_datalists = (DataFrame[], DataFrame[], DataFrame[], DataFrame[], DataFrame[])
    durations_hours = Float64[]
    mean_charge_500_improvement = Float64[]
    median_charge_500_improvement = Float64[]
    for (power_cap, duration_data) in zip((25.0 * 2^x for x in 0:1:4), duration_datalists)
        for df in all_metrics
            filtered_df = _filter_results!(df)
            push!(duration_data, filtered_df[filtered_df.power_capacity.==power_cap, :])
        end
        duration_df = vcat(duration_data...)
        duration_df.duration = @. duration_df.energy_capacity / duration_df.power_capacity
        push!(durations_hours, only(unique(duration_df.duration)))
        push!(mean_charge_500_improvement, mean(
            duration_df.neg_rev_charge_500_standard .- duration_df.neg_rev_charge_500_apb
        )
        )
        push!(median_charge_500_improvement, median(
            duration_df.neg_rev_charge_500_standard .- duration_df.neg_rev_charge_500_apb
        )
        )
    end
    return DataFrame(
        :duration => durations_hours,
        :mean_neg_rev_charge_500_improvement => mean_charge_500_improvement,
        :median_neg_rev_charge_500_improvement => median_charge_500_improvement,
    )
end
merged = merge_summary_data("results/data/NSW_summary_results.jld2", "results/data/actual-prices-binding/NSW_summary_results_apb.jld2")
metrics = calculate_metrics(merged)
formulation_summary = summarise_formulation_metrics(metrics)
duration_charge_improvement_summary = summarise_duration_metrics(metrics)
CSV.write(
    "results/data/actual-prices-binding/rev_and_negrev_standard_vs_apb.csv",
    formulation_summary
)
CSV.write(
    "results/data/actual-prices-binding/negrev_charge_improvement_by_duration.csv",
    duration_charge_improvement_summary
)
