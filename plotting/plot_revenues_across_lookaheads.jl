using Dates, DataFrames
using NEMStorageUnderUncertainty
using Plots, StatsPlots, Plots.PlotMeasures
using JLD2

function _sort_bess_capacities(data::DataFrame)
    for cap in ("12.5MW", "25.0MW", "50.0MW")
        data[:, :sim] = replace.(data[:, :sim], cap => lpad(cap, 7, "0"))
    end
    sort!(data, :sim)
    for cap in ("012.5MW", "025.0MW", "050.0MW")
        data[:, :sim] = replace.(data[:, :sim], cap => cap[2:end])
    end
    return data
end

function plot_revenues_across_simulations(
    jld2_path::String, title::String; percentage_of_perfect_foresight=false
)
    data = load(jld2_path)
    revenues = []
    bess_type = []
    lookaheads = []
    for key in keys(data)
        df = data[key]
        for lookahead in unique(df.lookahead_minutes)
            lookahead_df = df[df.lookahead_minutes .== lookahead, :]
            lookahead_df = lookahead_df[lookahead_df.status .== "binding", :]
            revenue = sum(lookahead_df.revenue)
            push!(revenues, revenue)
            push!(bess_type, key)
            push!(lookaheads, lookahead)
        end
    end
    summary_data = DataFrame(
        :revenue => revenues,
        :sim => bess_type,
        :lookahead => lookaheads,
        :rel_gap => fill(0.01, length(lookaheads)),
    )
    summary_data = _sort_bess_capacities(summary_data)
    summary_data = unstack(summary_data, :sim, :lookahead, :revenue)
    plot_data = rename(summary_data, Symbol("526500") => Symbol("Perfect Foresight"))
    if percentage_of_perfect_foresight
        for col in propertynames(plot_data[:, 2:end])
            plot_data[:, col] = @. plot_data[:, col] /
                                   plot_data[:, Symbol("Perfect Foresight")] * 100
        end
        scale = :none
        ylabel = "% of perfect foresight revenue"
        plot_data = plot_data[:, Not(Symbol("Perfect Foresight"))]
    else
        scale = :log10
        ylabel = "Revenue (AUD)"
    end
    plot_matrix = Float64.(Array(plot_data[:, 2:end]))
    groupby_labels = permutedims(names(plot_data)[2:end])
    colors = [[color] for color in palette(:roma, 8)]'
    return groupedbar(
        plot_data[:, :sim],
        plot_matrix;
        rot=45,
        ylabel=ylabel,
        size=(800, 650),
        fontfamily="serif",
        legend=Symbol(:outer, :right),
        framestyle=:box,
        title=title,
        label=groupby_labels,
        color=colors,
        bg="#f0f0f0",
        legend_title="Lookahead\n(minutes)",
        bottom_margin=50px,
        yscale=scale,
    )
end

function plot_standardarb_nodeg()
    results_path = "simulations/arbitrage_no_degradation/results"
    jld2_file = joinpath(
        results_path, "NSW_100.0MWh_StandardArb_NoDeg_2021_lookaheads.jld2"
    )
    abs_revenues = plot_revenues_across_simulations(
        jld2_file, "100MWh BESS, Standard Arbitrage\nNSW Prices 2021"
    )
    savefig(
        abs_revenues,
        joinpath(
            results_path, "NSW_100.0MWh_StandardArb_NoDeg_2021_revenues_lookaheads.pdf"
        ),
    )
    percentage_revenues = plot_revenues_across_simulations(
        jld2_file,
        "100MWh BESS, Standard Arbitrage\nNSW Prices 2021",
        ;
        percentage_of_perfect_foresight=true,
    )
    return savefig(
        percentage_revenues,
        joinpath(
            results_path,
            "NSW_100.0MWh_StandardArb_NoDeg_2021_percentage_revenues_lookaheads.pdf",
        ),
    )
end

function plot_standardarb_throughput_limits()
    results_path = "simulations/arbitrage_throughputlimited_no_degradation/results"
    jld2_file = joinpath(
        results_path, "NSW_100.0MWh_ArbThroughputLimits_NoDeg_2021_lookaheads.jld2"
    )
    abs_revenues = plot_revenues_across_simulations(
        jld2_file, "100MWh BESS, Arbitrage with 100MWh throughput per day\nNSW Prices 2021"
    )
    savefig(
        abs_revenues,
        joinpath(
            results_path,
            "NSW_100.0MWh_ArbThroughputLimits_NoDeg_2021_revenues_lookaheads.pdf",
        ),
    )
    percentage_revenues = plot_revenues_across_simulations(
        jld2_file,
        "100MWh BESS, Arbitrage with 100MWh throughput per day\nNSW Prices 2021";
        percentage_of_perfect_foresight=true,
    )
    return savefig(
        percentage_revenues,
        joinpath(
            results_path,
            "NSW_100.0MWh_ArbThroughputLimits_NoDeg_2021_percentage_revenues_lookaheads.pdf",
        ),
    )
end

plot_standardarb_nodeg()
plot_standardarb_throughput_limits()
