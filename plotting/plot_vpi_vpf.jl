using Dates, DataFrames
using NEMStorageUnderUncertainty
using CairoMakie
using JLD2

function add_legend!(
    fig::Figure,
    x_loc,
    y_loc,
    value_colors::Vector{PolyElement},
    value_labels::Vector{String},
    value_title::String,
)
    v_lg = [
        PolyElement(; polycolor=:transparent, strokecolor=c, strokewidth=1) for
        c in (:gray, :black)
    ]
    Legend(
        fig[y_loc, x_loc],
        [v_lg, value_colors],
        [["Value of perfect foresight", "Value of perfect information"], value_labels],
        ["Values", value_title];
        framevisible=false,
    )
    return nothing
end

function _makie_plot_each_formulation(
    plot_data::DataFrame, title::String, yscale::Function, fillto::Float64
)
    (bess_mw, lookaheads) = (unique(plot_data.power_capacity), unique(plot_data.lookahead))
    xs = [findfirst(x -> x == bess, bess_mw) for bess in plot_data.power_capacity]
    groups = [
        findfirst(x -> x == lookahead, lookaheads) for lookahead in plot_data.lookahead
    ]
    v_pf_colors = [c for c in cgrad(:roma, length(lookaheads); categorical=true, alpha=0.8)]
    fig = Figure(; resolution=(800, 600))
    ylabel = "Value (% of perfect foresight revenue)"
    ax = Axis(
        fig[1, 1];
        xticks=(1:length(bess_mw), string.(round.(Int, bess_mw)) .* " MW"),
        yticks=(range(0, 100; step=20), string.(range(0, 100; step=20))),
        ylabel=ylabel,
        yscale=yscale,
    )
    barplot!(
        ax,
        xs,
        plot_data.vpf_per;
        dodge=groups,
        color=v_pf_colors[groups],
        fillto=fillto,
        strokecolor=:gray,
        strokewidth=1,
    )
    barplot!(
        ax,
        xs,
        plot_data.vpi_per;
        dodge=groups,
        color=:transparent,
        fillto=fillto,
        strokewidth=1,
    )
    ylims!(ax, 0.0, 100.0)
    # Legend
    lk_lg = [PolyElement(; polycolor=v_pf_colors[i]) for i in 1:length(lookaheads)]
    add_legend!(fig, 2, 1, lk_lg, lookaheads .* " min", "Lookahead\n(minutes)")
    Label(fig[0, :]; text=title, fontsize=22, font="Source Sans Pro")
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
    ylabel = "Value\n(% of perfect foresight revenue)"
    lookaheads = unique(plot_data.lookahead)
    ax = Axis(
        fig[position, 1];
        xticks=(1:length(lookaheads), string.(lookaheads) .* " min"),
        yticks=(range(0, 100; step=20), string.(range(0, 100; step=20))),
        title,
        ylabel=ylabel,
    )
    xs = [findfirst(x -> x == lk, lookaheads) for lk in plot_data.lookahead]
    groups = [findfirst(x -> x == f, formulations) for f in plot_data.label]
    barplot!(
        ax,
        xs,
        plot_data.vpf_per;
        dodge=groups,
        color=colors[groups],
        fillto=0.0,
        strokecolor=:gray,
        strokewidth=1,
    )
    barplot!(
        ax,
        xs,
        plot_data.vpi_per;
        dodge=groups,
        color=:transparent,
        fillto=0.0,
        strokewidth=1,
    )
    return ylims!(ax, 0.0, 100.0)
end

function plot_value_of_information_and_foresight_across_formulations(
    data_path::String, save_path::String
)
    data_file = [f for f in readdir(data_path) if f == "vpi_vpf.jld2"][]
    all_data = load(joinpath(data_path, data_file))
    for (state, value) in pairs(all_data)
        energy = round(Int, unique(value.energy_capacity)[])
        state_data = all_data[state]
        plot_mw_capacities = (25, 100, 400)
        plot_lookaheads = ("5", "60", "240", "480", "900")
        fig = Figure(; resolution=(800, 1000))
        state_data.label = map(
            x -> NEMStorageUnderUncertainty.formulation_label_map[x], state_data.formulation
        )
        state_data.param = replace(state_data.param, missing => "")
        non_param_formulations = unique(state_data[state_data.param .== "", :formulation])
        param_formulations = unique(state_data[state_data.param .!= "", :formulation])
        state_data[state_data.param .!= "", :label] =
            state_data[state_data.param .!= "", :label] .* " [" .*
            uppercasefirst.(string.(state_data[state_data.param .!= "", :param])) .* "]"
        sims = sort(unique(state_data.label))
        colors = NEMStorageUnderUncertainty.generate_formulation_colors(
            param_formulations, non_param_formulations, sims
        )
        for (i, mw_capacity) in enumerate(plot_mw_capacities)
            energy = round(Int, unique(state_data.energy_capacity)[])
            mw_df = state_data[state_data.power_capacity .== mw_capacity, :]
            mw_df = mw_df[mw_df.lookahead .∈ (plot_lookaheads,), :]
            mw_df.lookahead = parse.(Int64, mw_df.lookahead)
            _makie_plot_across_formulation(fig, mw_df, i, mw_capacity, sims, colors)
        end
        f_lg = [PolyElement(; polycolor=colors[i]) for i in 1:length(sims)]
        add_legend!(fig, 2, :, f_lg, sims, "Simulated formulation")
        title = "$energy MWh BESS - VPI & VPF - $state Prices, 2021"
        Label(fig[0, :]; text=title, fontsize=22, font="Source Sans Pro")
        filename = "$(state)_$(energy)_allformulations_vpi_vpf.pdf"
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
