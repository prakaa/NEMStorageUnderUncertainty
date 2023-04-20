using Dates, DataFrames
using NEMStorageUnderUncertainty
using CairoMakie
using JLD2

function _makie_plot_each_formulation(
    plot_data::DataFrame, title::String, yscale::Function, fillto::Float64
)
    (bess_mw, lookaheads) = (unique(plot_data.power_capacity), unique(plot_data.lookahead))
    xs = [findfirst(x -> x == bess, bess_mw) for bess in plot_data.power_capacity]
    groups = [
        findfirst(x -> x == lookahead, lookaheads) for lookahead in plot_data.lookahead
    ]
    v_pf_colors = [c for c in cgrad(:roma, length(lookaheads); categorical=true, alpha=0.8)]
    fig = Figure(; backgroundcolor="#f0f0f0", resolution=(800, 600))
    ylabel = "Revenue reduction (% of perfect foresight revenue)"
    ax = Axis(
        fig[1, 1];
        xticks=(1:length(bess_mw), string.(round.(Int, bess_mw)) .* " MW"),
        title,
        ylabel=ylabel,
        yscale=yscale,
    )
    barplot!(
        ax,
        xs,
        plot_data.vpf_per .* -1;
        dodge=groups,
        color=v_pf_colors[groups],
        fillto=fillto,
        strokecolor=:gray,
        strokewidth=1,
    )
    barplot!(
        ax,
        xs,
        plot_data.vpi_per .* -1;
        dodge=groups,
        color=:transparent,
        fillto=fillto,
        strokewidth=1,
    )
    ylims!(ax, -100.0, -1.0)
    # Legend
    lk_lg = [PolyElement(; polycolor=v_pf_colors[i]) for i in 1:length(lookaheads)]
    v_lg = [
        PolyElement(; polycolor=:transparent, strokecolor=c, strokewidth=1) for
        c in (:gray, :black)
    ]
    Legend(
        fig[1, 2],
        [v_lg, lk_lg],
        [["Perfect foresight", "Perfect information"], lookaheads],
        ["Value of:", "Lookaheads\n(minutes)"];
        framevisible=false,
        patchcolor="#f0f0f0",
    )
    return fig
end

function _makie_plot_across_formulation(
    fig::Figure,
    plot_data::DataFrame,
    position::Int64,
    mw_capacity::Int64,
    formulations::Vector{String},
    colors,
)
    title = string(round(Int, mw_capacity)) * " MW"
    ylabel = "Revenue reduction\n(% of perfect foresight revenue)"
    lookaheads = unique(plot_data.lookahead)
    ax = Axis(
        fig[position, 1];
        xticks=(1:length(lookaheads), string.(lookaheads) .* " min"),
        title,
        ylabel=ylabel,
    )
    xs = [findfirst(x -> x == lk, lookaheads) for lk in plot_data.lookahead]
    groups = [findfirst(x -> x == f, formulations) for f in plot_data.label]
    barplot!(
        ax,
        xs,
        plot_data.vpf_per .* -1;
        dodge=groups,
        color=colors[groups],
        fillto=0.0,
        strokecolor=:gray,
        strokewidth=1,
    )
    barplot!(
        ax,
        xs,
        plot_data.vpi_per .* -1;
        dodge=groups,
        color=:transparent,
        fillto=0.0,
        strokewidth=1,
    )
    return ylims!(ax, -100.0, -1.0)
end

function plot_value_of_information_and_foresight_across_formulations(
    data_path::String, save_path::String
)
    formulation_label_map = Dict(
        "arbitrage_no_degradation" => "Arb",
        "arbitrage_throughputpenalty_no_degradation" => "TP Penalty",
        "arbitrage_throughputlimited_no_degradation" => "TP Limited",
        "arbitrage_capcontracted_no_degradation" => "Cap + TP Pen.",
        "arbitrage_discounted_no_degradation" => "Discounting + TP Pen.",
    )
    seq_colormaps = (:Hokusai2, :Tam)
    data_file = [f for f in readdir(data_path) if f == "vpi_vpf.jld2"][]
    all_data = load(joinpath(data_path, data_file))
    for (state, value) in pairs(all_data)
        energy = round(Int, unique(value.energy_capacity)[])
        state_data = all_data[state]
        plot_mw_capacities = (25, 100, 400)
        plot_lookaheads = ("5", "60", "480", "900")
        fig = Figure(; backgroundcolor="#f0f0f0", resolution=(800, 1000))
        state_data.label = map(x -> formulation_label_map[x], state_data.formulation)
        state_data.param = replace(state_data.param, missing => "")
        non_param_formulations = unique(state_data[state_data.param .== "", :formulation])
        param_formulations = unique(state_data[state_data.param .!= "", :formulation])
        state_data[state_data.param .!= "", :label] =
            state_data[state_data.param .!= "", :label] .* " [" .*
            uppercasefirst.(string.(state_data[state_data.param .!= "", :param])) .* "]"
        formulations = sort(unique(state_data.label))
        colors = []
        append!(colors, Makie.wong_colors()[3:(2 + length(non_param_formulations))])
        for (i, f) in enumerate(param_formulations)
            append!(
                colors,
                [
                    c for c in cgrad(
                        seq_colormaps[i],
                        length([
                            form for
                            form in formulations if contains(form, formulation_label_map[f])
                        ]);
                        categorical=true,
                        alpha=0.8,
                    )
                ],
            )
        end
        for (i, mw_capacity) in enumerate(plot_mw_capacities)
            energy = round(Int, unique(state_data.energy_capacity)[])
            mw_df = state_data[state_data.power_capacity .== mw_capacity, :]
            mw_df = mw_df[mw_df.lookahead .∈ (plot_lookaheads,), :]
            mw_df.lookahead = parse.(Int64, mw_df.lookahead)
            _makie_plot_across_formulation(fig, mw_df, i, mw_capacity, formulations, colors)
        end
        #Legend
        f_lg = [PolyElement(; polycolor=colors[i]) for i in 1:length(formulations)]
        v_lg = [
            PolyElement(; polycolor=:transparent, strokecolor=c, strokewidth=1) for
            c in (:gray, :black)
        ]
        Legend(
            fig[:, 2],
            [v_lg, f_lg],
            [["Perfect foresight", "Perfect information"], formulations],
            ["Value of:", "Simulated formulation"];
            framevisible=false,
            patchcolor="#f0f0f0",
        )
        title = "$energy MWh BESS - VPI & VPF - $state Prices, 2021"
        Label(fig[0, :]; text=title, fontsize=22, font="Source Sans Pro")
        filename = "$(state)_$(energy)_allformulations_vpi_vpf.png"
        save(joinpath(save_path, filename), fig; pt_per_unit=1)
    end
end

function plot_value_of_information_and_foresight_for_each_formulation(
    data_path::String, save_path::String
)
    data_file = [f for f in readdir(data_path) if f == "vpi_vpf.jld2"][]
    all_data = load(joinpath(data_path, data_file))
    scale = identity
    for (state, value) in pairs(all_data)
        energy = round(Int, unique(value.energy_capacity)[])
        state_data = all_data[state]
        for formulation in unique(state_data.formulation)
            df = state_data[state_data.formulation .== formulation, :]
            energy = round(Int, unique(df.energy_capacity)[])
            title_stem = "$energy MWh BESS VPI & VPF - "
            if all(ismissing.(unique(df.param)))
                title = (
                    title_stem *
                    NEMStorageUnderUncertainty.plot_title_map[formulation] *
                    "- $state Prices 2021"
                )
                filename = "$(state)_$(energy)_$(formulation)_vpi_vpf.pdf"
                fig = _makie_plot_each_formulation(df, title, scale, 0.0)
                save(joinpath(save_path, filename), fig; pt_per_unit=1)
            else
                params = unique(df.param)
                for param in params
                    filename = "$(state)_$(energy)_$(formulation)_$(param)_vpi_vpf.pdf"
                    param_df = df[df.param .== param, :]
                    param = uppercasefirst(param)
                    title = (
                        title_stem *
                        NEMStorageUnderUncertainty.plot_title_map[formulation] *
                        " [$param] " *
                        "- $state Prices 2021"
                    )
                    fig = _makie_plot_each_formulation(param_df, title, scale, 0.0)
                    save(joinpath(save_path, filename), fig; pt_per_unit=1)
                end
            end
        end
    end
end

data_path = joinpath("results", "data")
plot_path = joinpath("results", "plots", "vpi_vpf")
if !ispath(plot_path)
    mkpath(plot_path)
end

@assert ispath(data_path) "Results data not compiled. Run 'make compile_results'."

NEMStorageUnderUncertainty.set_project_plot_theme!()
plot_value_of_information_and_foresight_for_each_formulation(
    joinpath("results", "data"), plot_path
)
plot_value_of_information_and_foresight_across_formulations(
    joinpath("results", "data"), plot_path
)
