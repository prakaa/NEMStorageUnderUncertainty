using Dates, DataFrames
using NEMStorageUnderUncertainty
using CairoMakie
using JLD2
using Statistics

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

function _get_throughput_data(data::Dict{String,Any})
    throughput_data = DataFrame[]
    for key in keys(data)
        df = data[key]
        df = df[:, [:simulated_time, :throughput_mwh, :lookahead_minutes]]
        df[:, :sim] .= key
        push!(throughput_data, df)
    end
    return vcat(throughput_data...)
end

function plot_throughputs(data::Dict{String,Any}, sim::String, title::String)
    tp_data = _get_throughput_data(data)
    tp_data = _sort_bess_capacities(tp_data)
    @assert sim in tp_data.sim
    sim_data = filter(:sim => x -> x == sim, tp_data)
    fig = Figure(; backgroundcolor="#f0f0f0", resolution=(800, 600))
    ax = Axis(fig[1, 1]; title=title, ylabel="Throughput (MWh)")
    lookaheads = unique(sim_data.lookahead_minutes)
    colors = [c for c in cgrad(:roma, length(lookaheads); categorical=true)]
    for (i, lk) in enumerate(lookaheads)
        label = replace("$lk", "526500" => "Perfect Foresight")
        plot_df = filter(:lookahead_minutes => x -> x == lk, sim_data)
        lines!(ax, plot_df.throughput_mwh; label=label, color=colors[i])
    end
    xticks = unique(sim_data.simulated_time)
    lines!(
        ax,
        fill(100.0 * 365, length(xticks));
        color=:red,
        linestyle=:dot,
        label="1 cycle per day",
    )
    fig[1, 2] = Legend(
        fig, ax, "Lookaheads\n(minutes)"; framevisible=false, patchcolor="#f0f0f0"
    )
    month_start_index = [findfirst(x -> month(x) == i, xticks) for i in 1:12]
    month_start_label = [string(Date(xticks[x])) for x in month_start_index]
    ax.xticks = (month_start_index, month_start_label)
    ax.xticklabelrotation = π / 4
    return fig
end

function plot_throughputs_arb_nodeg()
    results_path = "simulations/arbitrage_no_degradation/results"
    plot_path = joinpath(results_path, "plots")
    if !isdir(plot_path)
        mkdir(plot_path)
    end
    jld2_file = joinpath(
        results_path, "NSW_100.0MWh_StandardArb_NoDeg_2021_lookaheads.jld2"
    )
    data = load(jld2_file)
    selected = [
        key for key in keys(data) if
        (contains(key, "forecast") & any(contains.(key, ["25.0MW", "100.0MW", "400.0MW"])))
    ]
    for key in selected
        (data_type, mw) = split(key, "/")
        data_type = uppercasefirst(data_type)
        title = "100MWh/$(mw) BESS - Arbitrage - NSW Prices 2021 ($(data_type))"
        fig = plot_throughputs(data, key, title)
        int_mw = split(mw, ".")[1]
        save(
            joinpath(plot_path, "NSW_100MWh$(int_mw)MW_throughputs.pdf"), fig; pt_per_unit=1
        )
    end
end

function plot_throughputs_arbthroughputlimit_nodeg()
    results_path = "simulations/arbitrage_throughputlimited_no_degradation/results"
    plot_path = joinpath(results_path, "plots")
    if !isdir(plot_path)
        mkdir(plot_path)
    end
    jld2_file = joinpath(
        results_path, "NSW_100.0MWh_ArbThroughputLimits_NoDeg_2021_lookaheads.jld2"
    )
    data = load(jld2_file)
    selected = [
        key for key in keys(data) if
        (contains(key, "forecast") & any(contains.(key, ["25.0MW", "100.0MW", "400.0MW"])))
    ]
    for key in selected
        (data_type, mw) = split(key, "/")
        data_type = uppercasefirst(data_type)
        title = "100MWh/$(mw) BESS - Throughput Limited - NSW Prices 2021 ($(data_type))"
        fig = plot_throughputs(data, key, title)
        int_mw = split(mw, ".")[1]
        save(
            joinpath(plot_path, "NSW_100MWh$(int_mw)MW_throughputs.pdf"), fig; pt_per_unit=1
        )
    end
end

function plot_throughputs_arbthroughputpenalty_nodeg()
    results_path = "simulations/arbitrage_throughputpenalty_no_degradation/results"
    plot_path = joinpath(results_path, "plots")
    if !isdir(plot_path)
        mkdir(plot_path)
    end
    files = [f for f in readdir(results_path) if endswith(f, ".jld2")]
    for file in files
        jld2_file = joinpath(results_path, file)
        data = load(jld2_file)
        selected = [
            key for key in keys(data) if (
                contains(key, "forecast") &
                any(contains.(key, ["25.0MW", "100.0MW", "400.0MW"]))
            )
        ]
        throughput_penalty = match(r".*_ArbThroughputPenalty([0-9.]*)_.*", file)[1]
        throughput_penalty = round(Int, parse(Float64, throughput_penalty))
        for key in selected
            (data_type, mw) = split(key, "/")
            data_type = uppercasefirst(data_type)
            title = (
                "100MWh/$(mw) BESS - TP Penalty $(throughput_penalty)AUD/MWh - " *
                "NSW Prices 2021 ($(data_type))"
            )
            fig = plot_throughputs(data, key, title)
            int_mw = split(mw, ".")[1]
            save(
                joinpath(
                    plot_path,
                    "NSW_$(throughput_penalty)AUDpMWh_100MWh$(int_mw)MW_throughputs.pdf",
                ),
                fig;
                pt_per_unit=1,
            )
        end
    end
end

font = "Source Sans Pro"
theme = Theme(;
    Axis=(
        backgroundcolor="#f0f0f0",
        spinewidth=0,
        xticklabelrotation=45,
        titlesize=20,
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
plot_throughputs_arb_nodeg()
plot_throughputs_arbthroughputlimit_nodeg()
plot_throughputs_arbthroughputpenalty_nodeg()
