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
    Legend(
        fig[y_loc, x_loc],
        [value_colors],
        [value_labels],
        [value_title];
        framevisible=false,
    )
    return nothing
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
    ylabel = L"\frac{\textrm{NegRev}_{\textrm{Actual}} -\textrm{NegRev}_{\textrm{Forecast}}}{\textrm{Revenue}_{\textrm{Actual}}-\textrm{Revenue}_{\textrm{Forecast}}}"
    lookaheads = unique(plot_data.lookahead)
    ax = Axis(
        fig[position, 1];
        xticks=(1:length(lookaheads), string.(lookaheads) .* " min"),
        yticks=(range(0, 100; step=20), string.(range(0, 100; step=20))),
        title,
        ylabel=ylabel,
        xlabel="Lookahead (minutes)",
    )
    xs = [findfirst(x -> x == lk, lookaheads) for lk in plot_data.lookahead]
    groups = [findfirst(x -> x == f, formulations) for f in plot_data.label]
    barplot!(
        ax,
        xs,
        plot_data.ddm;
        dodge=groups,
        color=colors[groups],
        fillto=0.0,
        strokecolor=:gray,
        strokewidth=1,
    )
    return ylims!(ax, 0.0, 100.0)
end

function plot_ddm_across_formulations(
    data_path::String, save_path::String
)
    data_file = [f for f in readdir(data_path) if f == "ddm_vpl_vpi.jld2"][]
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
        non_param_formulations = unique(state_data[state_data.param.=="", :formulation])
        param_formulations = unique(state_data[state_data.param.!="", :formulation])
        state_data[state_data.param.!="", :label] =
            state_data[state_data.param.!="", :label] .* " [" .*
            uppercasefirst.(string.(state_data[state_data.param.!="", :param])) .* "]"
        sims = sort(unique(state_data.label))
        colors = NEMStorageUnderUncertainty.generate_formulation_colors(
            param_formulations, non_param_formulations, sims
        )
        for (i, mw_capacity) in enumerate(plot_mw_capacities)
            energy = round(Int, unique(state_data.energy_capacity)[])
            mw_df = state_data[state_data.power_capacity.==mw_capacity, :]
            mw_df = mw_df[mw_df.lookahead.∈(plot_lookaheads,), :]
            mw_df.lookahead = parse.(Int64, mw_df.lookahead)
            _makie_plot_across_formulation(fig, mw_df, i, mw_capacity, sims, colors)
        end
        f_lg = [PolyElement(; polycolor=colors[i]) for i in 1:length(sims)]
        add_legend!(fig, 2, :, f_lg, sims, "Simulated formulation")
        title = "$energy MWh BESS - DDM - $state Prices, 2021"
        Label(fig[0, :]; text=title, fontsize=22, font="Source Sans Pro")
        filename = "$(state)_$(energy)_allformulations_ddm.pdf"
        save(joinpath(save_path, filename), fig; pt_per_unit=1)
    end
end


data_path = joinpath("results", "data")
plot_path = joinpath("results", "plots", "neg_rev")
if !ispath(plot_path)
    mkpath(plot_path)
end

@assert ispath(data_path) "Results data not compiled. Run 'make compile_results'."

NEMStorageUnderUncertainty.set_project_plot_theme!()
plot_ddm_across_formulations(
    joinpath("results", "data"), plot_path
)
