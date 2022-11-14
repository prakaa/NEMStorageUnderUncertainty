import MathOptInterface: OptimizerWithAttributes
using CSV
using Dates
using DataFrames
using HiGHS
using JuMP
using NEMStorageUnderUncertainty: NEMStorageUnderUncertainty
using ProgressMeter

function set_optimizer()
    mip_optim_gap = 0.005
    optimizer = optimizer_with_attributes(
        HiGHS.Optimizer, "mip_rel_gap" => mip_optim_gap, "threads" => 20
    )
    return optimizer
end

function collate_all_actual_and_forecast_data(
    region::String, start_time::DateTime, end_time::DateTime
)
    @info("Collating forecast data")
    all_actual_data = NEMStorageUnderUncertainty.get_all_actual_data("data/dispatch_price")
    (pd_df, p5_df) = NEMStorageUnderUncertainty.get_all_pd_and_p5_data(
        "data/forecast_price/PREDISPATCH", "data/forecast_price/P5MIN"
    )
    forecast_data = NEMStorageUnderUncertainty.get_ForecastData(
        pd_df, p5_df, region, (start_time, end_time), nothing
    )
    return all_actual_data, forecast_data
end

function simulate(
    storage::NEMStorageUnderUncertainty.StorageDevice,
    data::NEMStorageUnderUncertainty.ForecastData,
    binding::T,
    horizon::T;
    start_time::DateTime,
    end_time::DateTime,
) where {T<:Period}
    optimizer = set_optimizer()
    results = NEMStorageUnderUncertainty.simulate_storage_operation(
        optimizer,
        storage,
        data,
        NEMStorageUnderUncertainty.StandardArbitrageThroughputLimit(
            365 * storage.energy_capacity
        ),
        NEMStorageUnderUncertainty.NoDegradation();
        decision_start_time=start_time,
        decision_end_time=end_time,
        binding=binding,
        horizon=horizon,
        silent=true,
        show_progress=true,
        time_limit_sec=30.0,
        relative_gap_in_results=true,
    )
    return results
end

function simulate_forecast2021_ArbThroughputLimits_NoDeg_lookaheads(
    power::Float64, energy::Float64
)
    if !isdir(joinpath(@__DIR__, "results"))
        mkdir(joinpath(@__DIR__, "results"))
    end
    optimizer = set_optimizer()
    lookaheads = [
        Minute(5),
        Minute(15),
        Minute(30),
        Minute(60),
        Minute(120),
        Minute(240),
        Minute(480),
        Minute(15 * 60),
    ]
    (start_time, end_time) = (DateTime(2021, 1, 1, 0, 0, 0), DateTime(2022, 1, 1, 0, 0, 0))
    all_actual_data, forecast_data = collate_all_actual_and_forecast_data(
        "NSW1", start_time, end_time
    )
    (actual_data_start_time, actual_data_end_time) = (
        start_time, end_time + lookaheads[end]
    )
    actual_data = NEMStorageUnderUncertainty.get_ActualData(
        all_actual_data, "NSW1", (actual_data_start_time, actual_data_end_time)
    )
    storage = NEMStorageUnderUncertainty.BESS(;
        power_capacity=power,
        energy_capacity=energy,
        soc_min=0.1 * energy,
        soc_max=0.9 * energy,
        η_charge=0.95,
        η_discharge=0.95,
        soc₀=0.5 * energy,
        throughput=0.0,
    )
    @info("BESS $power MW $energy MWh")
    @info("Simulating perfect foresight")
    perfect_foresight_result = NEMStorageUnderUncertainty.run_perfect_foresight(
        optimizer,
        storage,
        actual_data,
        NEMStorageUnderUncertainty.StandardArbitrageThroughputLimit(365 * energy),
        NEMStorageUnderUncertainty.NoDegradation();
        silent=true,
    )
    @info("Finished simulating perfect foresight")
    all_results = DataFrame[]
    p = Progress(length(lookaheads))
    for horizon in lookaheads
        @info("Starting lookahead $horizon simulation")
        results = simulate(
            storage,
            forecast_data,
            Minute(5),
            horizon;
            start_time=start_time,
            end_time=end_time,
        )
        push!(all_results, results)
        @info("Completed lookahead $horizon simulation")
        next!(p)
    end
    df = vcat(all_results..., perfect_foresight_result)
    df = NEMStorageUnderUncertainty.calculate_actual_revenue!(
        df, all_actual_data, forecast_data.τ
    )
    return NEMStorageUnderUncertainty.results_to_jld2(
        joinpath(
            @__DIR__,
            "results",
            "NSW_$(energy)MWh_ArbThroughputLimits_NoDeg_2021_lookaheads.jld2",
        ),
        "forecast",
        "$(power)MW",
        df,
    )
end

@assert !isempty(ARGS) "Provide power and energy capacity as arguments (in that order)"
power_and_energy = parse.(Float64, ARGS)
simulate_forecast2021_ArbThroughputLimits_NoDeg_lookaheads(
    power_and_energy[1], power_and_energy[2]
)