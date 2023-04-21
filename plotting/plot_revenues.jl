using Dates, DataFrames
using NEMStorageUnderUncertainty
using CairoMakie
using JLD2

function _makie_plot_all(
    plot_data::Dict{String,Any},
    title::String,
    ylabel::String,
    yscale::Function,
    fillto::Float64,
)
    actual_rev = DataFrame[]
    forecast_rev = DataFrame[]
    for (key, value) in pairs(plot_data)
        hundred_mw_data = value[value.power_capacity .== 100.0, :]
        hundred_mw_data = hundred_mw_data[
            (hundred_mw_data.lookahead .!= "Perfect Foresight") .& (hundred_mw_data.lookahead .!= "5"),
            All(),
        ]
        if contains(key, "/")
            (formulation, param) = string.(split(key, "/"))
            hundred_mw_data[:, :param] .= fill(
                uppercasefirst(param), size(hundred_mw_data)[1]
            )
        else
            (formulation, param) = (key, nothing)
            hundred_mw_data[:, :param] .= fill("", size(hundred_mw_data)[1])
        end
        push!(actual_rev, hundred_mw_data[hundred_mw_data.data_type .== "actual", :])
        push!(forecast_rev, hundred_mw_data[hundred_mw_data.data_type .== "forecast", :])
    end
    actual_rev = vcat(actual_rev...)
    forecast_rev = vcat(forecast_rev...)
    non_param_formulations = unique(actual_rev[actual_rev.param .== "", :formulation])
    param_formulations = unique(actual_rev[actual_rev.param .!= "", :formulation])
    for df in (actual_rev, forecast_rev)
        df.formulation = map(
            x -> NEMStorageUnderUncertainty.formulation_label_map[x], df.formulation
        )
        df.label = fill("", size(df)[1])
        df[df.param .!= "", :label] .=
            df[df.param .!= "", :formulation] .* " [" .* df[df.param .!= "", :param] .* "]"
        df[df.param .== "", :label] .= df[df.param .== "", :formulation]
    end
    (sims, lookaheads) = (sort(unique(actual_rev.label)), unique(actual_rev.lookahead))
    colors = []
    seq_colormaps = (:Hokusai2, :Tam)
    append!(colors, Makie.wong_colors()[3:(2 + length(non_param_formulations))])
    for (i, f) in enumerate(param_formulations)
        append!(
            colors,
            [
                c for c in cgrad(
                    seq_colormaps[i],
                    length([
                        sim for sim in sims if
                        contains(sim, NEMStorageUnderUncertainty.formulation_label_map[f])
                    ]);
                    categorical=true,
                    alpha=0.8,
                )
            ],
        )
    end
    fig = Figure(; backgroundcolor="#f0f0f0", resolution=(800, 600))
    for (stroke_col, bar_colors, df) in
        zip((:gray, :black), (colors, :transparent), (actual_rev, forecast_rev))
        sort!(df, [:formulation, :param, :lookahead])
        xs = [findfirst(x -> x == lookahead, lookaheads) for lookahead in df.lookahead]
        groups = [findfirst(x -> x == sim, sims) for sim in df.label]
        ax = Axis(
            fig[1, 1];
            xticks=(1:length(lookaheads), lookaheads .* " min"),
            title,
            ylabel=ylabel,
            yscale=yscale,
        )
        if typeof(bar_colors) != Symbol
            bar_colors = bar_colors[groups]
        end
        barplot!(
            ax,
            xs,
            df.revenue;
            dodge=groups,
            color=bar_colors,
            strokecolor=stroke_col,
            strokewidth=1,
            fillto=fillto,
        )
        ylims!(ax, 1.0, 20000000.0)
    end
    Legend
    elements = [PolyElement(; polycolor=colors[i]) for i in 1:length(sims)]
    actual_forecast = [
        PolyElement(; polycolor=:transparent, strokecolor=c, strokewidth=1) for
        c in (:gray, :black)
    ]
    Legend(
        fig[1, 2],
        [actual_forecast, elements],
        [["Actual", "Forecast"], sims],
        ["Data type", "Simulated formulation"];
        framevisible=false,
        patchcolor="#f0f0f0",
    )
    energy = unique(actual_rev.energy_capacity)[]
    power = unique(actual_rev.power_capacity)[]
    return fig, energy, power
end

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
                param = uppercasefirst(param)
                title = (
                    title_stem *
                    NEMStorageUnderUncertainty.plot_title_map[formulation] *
                    " [$param] " *
                    "- $state Prices 2021"
                )
                filename = "$(state)_$(energy)_$(formulation)_$(param)_$(fn_tag).pdf"
            end
            fig = _makie_plot(plot_data, title, ylabel, yscale, fillto)
            save(joinpath(save_path, filename), fig; pt_per_unit=1)
        end
    end
end

function plot_revenues_all_formulations(data_path::String, save_path::String)
    data_files = [f for f in readdir(data_path) if contains(f, "summary_results")]
    for file in data_files
        state = string(match(r"([A-Z]{2,3})_.*", file).captures[])
        data = load(joinpath(data_path, file))
        ylabel = "Revenue (AUD)"
        yscale = identity
        fillto = 0.0
        title = ""
        (fig, energy, power) = _makie_plot_all(data, title, ylabel, yscale, fillto)
        title = "$power MW/$energy MWh BESS - Revenues - $state Prices, 2021"
        Label(fig[0, :]; text=title, fontsize=22, font="Source Sans Pro")
        filename = "$(state)_$(energy)MWh_$(power)MW_allformulations_revenue.pdf"
        save(joinpath(save_path, filename), fig; pt_per_unit=1)
    end
end

data_path = joinpath("results", "data")
plot_path = joinpath("results", "plots", "revenues")
if !ispath(plot_path)
    mkpath(plot_path)
end

@assert ispath(data_path) "Results data not compiled. Run 'make compile_results'."

NEMStorageUnderUncertainty.set_project_plot_theme!()
plot_revenues_all_formulations(joinpath("results", "data"), plot_path)
for percentage_of_perfect_foresight in (false, true)
    plot_revenues_across_formulations(
        joinpath("results", "data"), percentage_of_perfect_foresight, plot_path
    )
end
