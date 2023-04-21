"""
Creates and sets a custom CairoMakie theme.
"""
function set_project_plot_theme!()
    sfont = "Source Sans Pro"
    theme = Theme(;
        Axis=(
            backgroundcolor="#f0f0f0",
            spinewidth=0,
            xticklabelrotation=45,
            titlesize=20,
            titlegap=15,
            titlefont=sfont,
            xlabelfont=sfont,
            ylabelfont=sfont,
            ylabelsize=16,
            xticklabelfont=sfont,
            xticklabelsize=14,
            yticklabelfont=sfont,
            yticklabelsize=14,
        ),
        Legend=(titlefont=sfont, labelfont=sfont, labelsize=14),
    )
    set_theme!(theme)
    return nothing
end

"""
Handles sorting of device power capacity strings for power capacities ``10^2`` MW.

# Arguments

  * `data`: `DataFrame`
  * `col`: Column in `data` that contains strings with power capacity followed by "MW".
  E.g. "12.5MW"

# Returns

`data` sorted by power capacities
"""
function sort_by_power_capacities(data::DataFrame, col::Symbol)
    for cap in ("12.5MW", "25.0MW", "50.0MW")
        data[:, col] = replace.(data[:, col], cap => lpad(cap, 7, "0"))
    end
    sort!(data, col)
    for cap in ("012.5MW", "025.0MW", "050.0MW")
        data[:, col] = replace.(data[:, col], cap => cap[2:end])
    end
    return data
end

"""
Generates Vector of colors used when plotting all formulations.

# Arguments

  * `param_formulations`: Name of formulations that take parameters
  * `non_param_formulations`: Name of formulations that do not take parameters
  * `sims`: Name of all simulations, i.e. formulations along with parameters

"""
function generate_formulation_colors(
    param_formulations::Vector{String},
    non_param_formulations::Vector{String},
    sims::Vector{String},
)
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
    return colors
end

plot_title_map = Dict(
    "arbitrage_no_degradation" => "Arbitrage",
    "arbitrage_throughputlimited_no_degradation" => "TP Limited (100 MWh/day)",
    "arbitrage_throughputpenalty_no_degradation" => "TP Penalty (AUD/MWh)",
    "arbitrage_capcontracted_no_degradation" => "Cap + TP Penalty (MW)",
    "arbitrage_discounted_no_degradation" => "Discounting + TP Pen.",
)

formulation_label_map = Dict(
    "arbitrage_no_degradation" => "Arbitrage",
    "arbitrage_throughputpenalty_no_degradation" => "TP Penalty",
    "arbitrage_throughputlimited_no_degradation" => "TP Limited",
    "arbitrage_capcontracted_no_degradation" => "Cap + TP Pen.",
    "arbitrage_discounted_no_degradation" => "Discounting + TP Pen.",
)
