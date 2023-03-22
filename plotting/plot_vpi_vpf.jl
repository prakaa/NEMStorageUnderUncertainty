using Dates, DataFrames
using NEMStorageUnderUncertainty
using CairoMakie
using JLD2

function _makie_plot(plot_data::DataFrame, title::String, yscale::Function, fillto::Float64)
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
                fig = _makie_plot(df, title, scale, 0.0)
                save(joinpath(save_path, filename), fig; pt_per_unit=1)
            else
                params = unique(df.param)
                for param in params
                    title = (
                        title_stem *
                        NEMStorageUnderUncertainty.plot_title_map[formulation] *
                        " $param AUD/MWh " *
                        "- $state Prices 2021"
                    )
                    filename = "$(state)_$(energy)_$(formulation)_$(param)_vpi_vpf.pdf"
                    param_df = df[df.param .== param, :]
                    fig = _makie_plot(param_df, title, scale, 0.0)
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
