using Dates, DataFrames
using NEMStorageUnderUncertainty
using CairoMakie
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
        :lookahead => string.(lookaheads),
        :rel_gap => fill(0.01, length(lookaheads)),
    )
    summary_data.lookahead =
        replace.(summary_data.lookahead, "526500" => "Perfect Foresight")
    summary_data = _sort_bess_capacities(summary_data)
    return summary_data
end

function plot_revenues_across_simulations(
    jld2_path::String, title::String; percentage_of_perfect_foresight=false
)
    function _makie_plot(
        plot_data::DataFrame,
        title::String,
        ylabel::String,
        yscale::Function,
        fillto::Float64,
    )
        plot_data.revenue = Float64.(plot_data.revenue)
        (sims, lookaheads) = (unique(plot_data.sim), unique(plot_data.lookahead))
        xs = [findfirst(x -> x == sim, sims) for sim in plot_data.sim]
        groups = [
            findfirst(x -> x == lookahead, lookaheads) for lookahead in plot_data.lookahead
        ]
        colors = [c for c in cgrad(:roma, length(lookaheads); categorical=true)]
        fig = Figure(; backgroundcolor="#f0f0f0", resolution=(800, 600))
        ax = Axis(
            fig[1, 1]; xticks=(1:length(sims), sims), title, ylabel=ylabel, yscale=yscale
        )
        barplot!(
            ax, xs, plot_data.revenue; dodge=groups, color=colors[groups], fillto=fillto
        )
        ylims!(ax, 1.0, nothing)
        # Legend
        elements = [PolyElement(; polycolor=colors[i]) for i in 1:length(lookaheads)]
        Legend(
            fig[1, 2],
            elements,
            lookaheads,
            "Lookaheads\n(minutes)";
            framevisible=false,
            patchcolor="#f0f0f0",
        )
        return fig
    end

    data = load(jld2_path)
    plot_data = _get_revenue_summary_data(data)
    if percentage_of_perfect_foresight
        unstacked = unstack(plot_data, :sim, :lookahead, :revenue)
        for col in propertynames(unstacked[:, 2:end])
            unstacked[:, col] = @. unstacked[:, col] /
                                   unstacked[:, Symbol("Perfect Foresight")] * 100
        end
        unstacked = unstacked[:, Not(Symbol("Perfect Foresight"))]
        plot_data = stack(
            unstacked, Not(:sim); variable_name=:lookahead, value_name=:revenue
        )
        plot_data = _sort_bess_capacities(plot_data)
        ylabel = "% of perfect foresight revenue"
        yscale = identity
        fillto = 0.0
    else
        ylabel = "Revenue (AUD)"
        yscale = log10
        fillto = 1.0
    end
    fig = _makie_plot(plot_data, title, ylabel, yscale, fillto)
    return fig
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
        jld2_file, "100MWh BESS - Arbitrage - NSW Prices 2021"
    )
    save(
        joinpath(
            results_path, "NSW_100.0MWh_StandardArb_NoDeg_2021_revenues_lookaheads.pdf"
        ),
        abs_revenues;
        pt_per_unit=1,
    )
    percentage_revenues = plot_revenues_across_simulations(
        jld2_file,
        "100MWh BESS - Arbitrage - NSW Prices 2021",
        ;
        percentage_of_perfect_foresight=true,
    )
    save(
        joinpath(
            results_path,
            "NSW_100.0MWh_StandardArb_NoDeg_2021_percentage_revenues_lookaheads.pdf",
        ),
        percentage_revenues;
        pt_per_unit=1,
    )
    return nothing
end

function plot_standardarb_throughput_limits()
    results_path = "simulations/arbitrage_throughputlimited_no_degradation/results"
    jld2_file = joinpath(
        results_path, "NSW_100.0MWh_ArbThroughputLimits_NoDeg_2021_lookaheads.jld2"
    )
    abs_revenues = plot_revenues_across_simulations(
        jld2_file, "100MWh BESS - Throughput Limited (100 MWh) - NSW Prices 2021"
    )
    save(
        joinpath(
            results_path,
            "NSW_100.0MWh_ArbThroughputLimits_NoDeg_2021_revenues_lookaheads.pdf",
        ),
        abs_revenues;
        pt_per_unit=1,
    )
    percentage_revenues = plot_revenues_across_simulations(
        jld2_file,
        "100MWh BESS - Throughput Limited (100 MWh) - NSW Prices 2021";
        percentage_of_perfect_foresight=true,
    )
    return save(
        joinpath(
            results_path,
            "NSW_100.0MWh_ArbThroughputLimits_NoDeg_2021_percentage_revenues_lookaheads.pdf",
        ),
        percentage_revenues;
        pt_per_unit=1,
    )
end

font = "Source Sans Pro"
theme = Theme(;
    Axis=(
        backgroundcolor="#f0f0f0",
        spinewidth=0,
        xticklabelrotation=45,
        titlesize=25,
        titlegap=15,
        titlefont=font,
        xlabelfont=font,
        ylabelfont=font,
        ylabelsize=18,
        xticklabelfont=font,
        xticklabelsize=16,
        yticklabelfont=font,
        yticklabelsize=14,
    ),
    Legend=(titlefont=font, labelfont=font, labelsize=14),
)
set_theme!(theme)
plot_standardarb_nodeg()
plot_standardarb_throughput_limits()
