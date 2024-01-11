using Dates, DataFrames
using NEMStorageUnderUncertainty
using CairoMakie
using JLD2

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

"""
Plots throughputs for each lookahead across the year.

Each figure is composed of 3 axes, each of which plots a particular device power rating
(specified in `selected_sims`).

# Arguments
  * `data`: Data as loaded from JLD2 file for a particular simulations
  * `selected_sims`: Selected simulations (and hence power ratings)
  * `title`: Title for figure

# Returns

Makie `Figure`
"""
function _plot_throughputs(
    data::Dict{String,Any}, selected_sims::Vector{String}, title::String
)
    @assert length(selected_sims) == 3
    tp_data = _get_throughput_data(data)
    @assert all([sim in tp_data.sim for sim in selected_sims])
    fig = Figure(; resolution=(800, 600))
    n = 0
    (elements, labels, axes) = (Lines[], String[], Axis[])
    for sim in selected_sims
        sim_data = filter(:sim => x -> x == sim, tp_data)
        (data_type, mw) = split(sim, "/")
        mw = convert(Int64, parse(Float64, mw[1:end-2]))
        data_type = uppercasefirst(data_type)
        ax = Axis(fig[1, n]; title="$(mw) MW")
        lookaheads = unique(sim_data.lookahead_minutes)
        colors = [c for c in cgrad(:roma, length(lookaheads); categorical=true)]
        for (i, lk) in enumerate(lookaheads)
            label = replace("$lk", "526500" => "Perfect Foresight")
            plot_df = filter(:lookahead_minutes => x -> x == lk, sim_data)
            l = lines!(ax, plot_df.throughput_mwh; color=colors[i])
            push!(elements, l)
            push!(labels, label)
        end
        xticks = unique(sim_data.simulated_time)
        month_start_index = [findfirst(x -> month(x) == i, xticks) for i in 1:12]
        month_start_label = [monthname(Date(xticks[x])) for x in month_start_index]
        ax.xticks = (month_start_index, month_start_label)
        ax.xticklabelrotation = π / 2
        l = lines!(ax, fill(100.0 * 365, length(xticks)); color=:red, linestyle=:dot)
        push!(elements, l)
        push!(labels, "1 cycle per day")
        push!(axes, ax)
        n += 1
    end
    Legend(
        fig[2, 1],
        elements[1:10],
        labels[1:10],
        "Lookaheads (minutes)";
        framevisible=false,
        orientation=:horizontal,
        nbanks=2,
        valign=:center,
    )
    linkaxes!(axes...)
    Label(fig[0, :]; text=title, fontsize=22, font="Source Sans Pro")
    fig.content[1].ylabel = "Cumulative Throughput (MWh)"
    trim!(fig.layout)
    return fig
end

"""
Wrapper function that plots throughput charts for all simulated formulations

# Arguments
  * `sim_folder`: Folder with simulated formulations and results
  * `selected_sims`: Selected simulations to plot. Should correspond to keys in JLD2 files

"""
function plot_all_throughputs(sim_folder::String, selected_sims::Vector{String})
    function _plot_formulation(
        data::Dict{String,Any},
        formulation::String,
        file::String,
        selected_sims::Vector{String},
        state::String,
        param::Union{String,Nothing}=nothing,
    )
        energy = parse(Float64, match(r"[A-Z]{2,3}_([0-9\.]*)MWh.*", file).captures[])
        energy = convert(Int64, energy)
        if isnothing(param)
            title = (
                "$energy MWh BESS - " *
                NEMStorageUnderUncertainty.plot_title_map[formulation] *
                "- $state Prices 2021 (Forecast)"
            )
        else
            title = (
                "$energy MWh BESS - " *
                NEMStorageUnderUncertainty.plot_title_map[formulation] *
                " [$param] " *
                "- $state Prices 2021"
            )
        end
        fig = _plot_throughputs(data, selected_sims, title)
        return fig, energy
    end

    save_path = joinpath("results", "plots", "throughput")
    if !isdir(save_path)
        mkpath(save_path)
    end
    categorisation = NEMStorageUnderUncertainty._categorise_simulation_results(sim_folder)
    for state in keys(categorisation)
        formulation_results = categorisation[state]
        for (formulation, results) in pairs(formulation_results)
            results_path = joinpath(sim_folder, formulation, "results")
            if length(results) == 1
                file = results[]
                data = load(joinpath(results_path, file))
                fig, energy = _plot_formulation(
                    data, formulation, file, selected_sims, state
                )
                save(
                    joinpath(
                        save_path, "$(state)_$(energy)_$(formulation)_throughputs.pdf"
                    ),
                    fig;
                    pt_per_unit=1,
                )
            else
                for file in results
                    data = load(joinpath(results_path, file))
                    param = match(r".*_param(.*)_NoDeg.*", file)
                    if !isnothing(param)
                        try
                            param = parse(Float64, param.captures[])
                            param = convert(Int64, param)
                        catch
                            param = uppercasefirst(param.captures[])
                        end
                    end
                    fig, energy = _plot_formulation(
                        data, formulation, file, selected_sims, state, string(param)
                    )
                    save(
                        joinpath(
                            save_path,
                            "$(state)_$(energy)_$(formulation)_$(param)_throughputs.pdf",
                        ),
                        fig;
                        pt_per_unit=1,
                    )
                end
            end
        end
    end
    return nothing
end

NEMStorageUnderUncertainty.set_project_plot_theme!()
selected_sims = ["forecast/25.0MW", "forecast/100.0MW", "forecast/400.0MW"]
plot_all_throughputs("simulations", selected_sims)
