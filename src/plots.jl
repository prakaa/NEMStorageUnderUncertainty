plot_title_map = Dict(
    "arbitrage_no_degradation" => "Arbitrage",
    "arbitrage_throughputlimited_no_degradation" => "TP Limited (100 MWh/day)",
    "arbitrage_throughputpenalty_no_degradation" => "TP Penalty",
)

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
