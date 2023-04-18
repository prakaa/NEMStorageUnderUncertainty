using Dates, DataFrames
using NEMStorageUnderUncertainty
using CairoMakie
using JLD2

function _makie_plot(
    plot_data::DataFrame, title::String, ylabel::String, yscale::Function, fillto::Float64
)
    plot_data.revenue = Float64.(plot_data.revenue)
    sort!(plot_data, [:power_capacity, :data_type])
    plot_data.sim = @. plot_data[:, :data_type] *
        "/" *
        string(plot_data[:, :power_capacity]) *
        " MW"
    (sims, lookaheads) = (unique(plot_data.sim), unique(plot_data.lookahead))
    xs = [findfirst(x -> x == sim, sims) for sim in plot_data.sim]
    groups = [
        findfirst(x -> x == lookahead, lookaheads) for lookahead in plot_data.lookahead
    ]
    colors = [c for c in cgrad(:roma, length(lookaheads); categorical=true)]
    fig = Figure(; backgroundcolor="#f0f0f0", resolution=(800, 600))
    ax = Axis(fig[1, 1]; xticks=(1:length(sims), sims), title, ylabel=ylabel, yscale=yscale)
    barplot!(ax, xs, plot_data.revenue; dodge=groups, color=colors[groups], fillto=fillto)
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

function plot_revenues_across_formulations(
    data_path::String, percentage_of_perfect_foresight::Bool, save_path::String
)
    data_files = [f for f in readdir(data_path) if contains(f, "summary_results")]
    for file in data_files
        state = string(match(r"([A-Z]{2,3})_.*", file).captures[])
        data = load(joinpath(data_path, file))
        for (key, value) in pairs(data)
            energy = round(Int, unique(value.energy_capacity)[])
            if contains(key, "/")
                (formulation, param) = string.(split(key, "/"))
            else
                (formulation, param) = (key, nothing)
            end
            if percentage_of_perfect_foresight
                unstacked = unstack(
                    value, [:power_capacity, :data_type], :lookahead, :revenue
                )
                for col in propertynames(unstacked[:, 3:end])
                    unstacked[:, col] = @. unstacked[:, col] /
                                           unstacked[:, Symbol("Perfect Foresight")] * 100
                end
                unstacked = unstacked[:, Not(Symbol("Perfect Foresight"))]
                plot_data = stack(
                    unstacked,
                    Not([:power_capacity, :data_type]);
                    variable_name=:lookahead,
                    value_name=:revenue,
                )
                ylabel = "% of perfect foresight revenue"
                yscale = identity
                fillto = 0.0
                fn_tag = "per_rev"
            else
                ylabel = "Revenue (AUD)"
                yscale = log10
                fillto = 1.0
                plot_data = value
                fn_tag = "abs_rev"
            end
            title_stem = "$energy MWh BESS Revenue - "
            if isnothing(param)
                title = (
                    title_stem *
                    NEMStorageUnderUncertainty.plot_title_map[formulation] *
                    "- $state Prices 2021"
                )
                filename = "$(state)_$(energy)_$(formulation)_$(fn_tag).pdf"
            else
                title = (
                    title_stem *
                    NEMStorageUnderUncertainty.plot_title_map[formulation] *
                    " $param " *
                    "- $state Prices 2021"
                )
                filename = "$(state)_$(energy)_$(formulation)_$(param)_$(fn_tag).pdf"
            end
            fig = _makie_plot(plot_data, title, ylabel, yscale, fillto)
            save(joinpath(save_path, filename), fig; pt_per_unit=1)
        end
    end
end

data_path = joinpath("results", "data")
plot_path = joinpath("results", "plots", "revenues")
if !ispath(plot_path)
    mkpath(plot_path)
end

@assert ispath(data_path) "Results data not compiled. Run 'make compile_results'."

NEMStorageUnderUncertainty.set_project_plot_theme!()
for percentage_of_perfect_foresight in (false, true)
    plot_revenues_across_formulations(
        joinpath("results", "data"), percentage_of_perfect_foresight, plot_path
    )
end
