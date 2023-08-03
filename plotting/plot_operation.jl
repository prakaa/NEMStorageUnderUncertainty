using Dates, DataFrames
using NEMStorageUnderUncertainty
using CairoMakie
using JLD2


function _get_arbitrage_100MW_data(sim_folder::String)
    categorisation = NEMStorageUnderUncertainty._categorise_simulation_results(sim_folder)
    region_data = Dict{String,Dict{String,DataFrame}}()
    for state in keys(categorisation)
        region_data[state] = Dict{String,DataFrame}()
        arb_file = categorisation[state]["arbitrage_no_degradation"][]
        all_sims = load(joinpath(sim_folder, "arbitrage_no_degradation", "results", arb_file))
        region_data[state]["actual"] = all_sims["actual/100.0MW"]
        region_data[state]["forecast"] = all_sims["forecast/100.0MW"]
    end
    return region_data
end

function _makie_plot_revenue_vs_price(data_dict::Dict{String,DataFrame})
    fig = Figure(; resolution=(800, 400))
    ax1 = Axis(fig[1, 1], xlabel="Energy Price (AUD/MW/hr)", ylabel="Revenue (AUD)", title="Simulation using actual prices", titlesize=18)
    ax2 = Axis(fig[1, 2], xlabel="Energy Price (AUD/MW/hr)", ylabel="Revenue (AUD)", title="Simulation using forecast prices", titlesize=18)
    linkyaxes!(ax1, ax2)
    linkxaxes!(ax1, ax2)
    for (ax, dtype) in zip((ax1, ax2), ("actual", "forecast"))
        df = data_dict[dtype]
        for (color, lk) in zip(Makie.wong_colors()[1:2], (60, 900))
            df_lk = df[df.lookahead_minutes.==lk, :]
            scatter!(ax, df_lk.actual_price, df_lk.revenue, label=string(lk), color=("#f0f0f0", 0.0), markersize=4, strokecolor=color, strokewidth=1.0)
        end
        xs = 500:15500
        lower_band = -15500.0 * 100.0 / 12.0
        band!(ax, xs, lower_band, fill(0.0, length(xs)), color=(:ivory4, 0.2))
        band!(ax, xs, fill(0.0, length(xs)), xs .* 100.0 ./ 12.0 .- 1e3, color=(:ivory3, 0.2))
        text!(ax, 1.55e4 + 5e2, 0.75e4; text="Lost opportunity", rotation=pi / 2, font="Source Sans Pro", align=(:left, :center), fontsize=9)
        text!(ax, 1.55e4 + 5e2, lower_band + 0.75e4; text="Detrimental decision", rotation=pi / 2, font="Source Sans Pro", align=(:left, :center), fontsize=9)
    end
    fig[1, 3] = Legend(fig, ax1, "Lookahead\n(minutes)", framevisible=false)
    fig[0, 1:2] = Label(fig, "100 MW/100 MWh BESS Arbitrage - BESS Revenue vs. NSW Energy Price", fontsize=22, font="Source Sans Pro")
    return fig
end

NEMStorageUnderUncertainty.set_project_plot_theme!()
save_path = joinpath("results", "plots", "operation")
if !isdir(save_path)
    mkpath(save_path)
end
data = _get_arbitrage_100MW_data("simulations")["NSW"]
fig = _makie_plot_revenue_vs_price(data)
save(joinpath(save_path, "NSW_100MW_100MWh_Revenue_Lookahead.pdf"), fig; pt_per_unit=1.0)
