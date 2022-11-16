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

function _get_revenue_summary_data(data::Dict{String,Any})
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
    summary_data = rename(summary_data, Symbol("526500") => Symbol("Perfect Foresight"))
    return summary_data
end

function plot_revenues_across_simulations(
    jld2_path::String, title::String; percentage_of_perfect_foresight=false
)
    data = load(jld2_path)
    plot_data = _get_revenue_summary_data(data)
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
    colors = [[color] for color in palette(:roma, length(groupby_labels))]'
    fnt = "Source Sans Pro"
    return groupedbar(
        plot_data[:, :sim],
        plot_matrix;
        xrot=45,
        ylabel=ylabel,
        size=(800, 600),
        lw=0,
        title=title,
        label=groupby_labels,
        color=colors,
        bg="#f0f0f0",
        legend_title="Lookahead\n(minutes)",
        margin=5px,
        yscale=scale,
        guidefont=font(fnt, 12),
        titlefont=font(fnt, 16),
        tickfont=font(fnt, 10),
        legendtitlefont=font(fnt, 8),
        legendfont=font(fnt, 8),
        extra_kwargs=KW(
            :plot => KW(
                :legend =>
                    KW(:x => 0.5, :y => -0.01, :orientation => "h", :borderwidth => 0),
            ),
        ),
    )
end

function plot_value_of_information_and_foresight(jld2_path::String, title::String)
    data = load(jld2_path)
    plot_data = _get_revenue_summary_data(data)
    actual_caps = [
        cap[2] for cap in split.(unique(plot_data.sim), "/") if cap[1] == "actual"
    ]
    forecast_caps = [
        cap[2] for cap in split.(unique(plot_data.sim), "/") if cap[1] == "forecast"
    ]
    caps = intersect(actual_caps, forecast_caps)
    v_pi = DataFrame[]
    v_pf = DataFrame[]
    for cap in caps
        value_of_pi =
            plot_data[plot_data.sim .== "actual/$cap", 2:(end - 1)] .-
            plot_data[plot_data.sim .== "forecast/$cap", 2:(end - 1)]
        push!(v_pi, hcat(DataFrame(:bess_mw => cap), value_of_pi))
        value_of_pf =
            plot_data[plot_data.sim .== "forecast/$cap", end] .-
            plot_data[plot_data.sim .== "forecast/$cap", 2:(end - 1)]
        push!(v_pf, hcat(DataFrame(:bess_mw => cap), value_of_pf))
    end
    v_pi = vcat(v_pi...)
    v_pf = vcat(v_pf...)

    scale = :log10
    ylabel = "Revenue (AUD)"
    return plot_data
    #plot_matrix = Float64.(Array(plot_data[:, 2:end]))
    #groupby_labels = permutedims(names(plot_data)[2:end])
    #colors = [[color] for color in palette(:roma, 8)]'
    #return groupedbar(
    #    plot_data[:, :sim],
    #    plot_matrix;
    #    rot=45,
    #    ylabel=ylabel,
    #    size=(800, 650),
    #    fontfamily="serif",
    #    legend=Symbol(:outer, :right),
    #    framestyle=:box,
    #    title=title,
    #    label=groupby_labels,
    #    color=colors,
    #    bg="#f0f0f0",
    #    legend_title="Lookahead\n(minutes)",
    #    bottom_margin=50px,
    #    yscale=scale,
    #)
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
        jld2_file,
        "100MWh BESS, Arbitrage with 100MWh throughput per day (pro-rata)\nNSW Prices 2021",
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

plotlyjs()
plot_standardarb_nodeg()
plot_standardarb_throughput_limits()
