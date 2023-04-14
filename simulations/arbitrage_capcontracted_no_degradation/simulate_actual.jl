import MathOptInterface: OptimizerWithAttributes
using CSV
using Dates
using DataFrames
using HiGHS
using JuMP
using NEMStorageUnderUncertainty: NEMStorageUnderUncertainty
using ProgressMeter

function set_optimizer()
    mip_optim_gap = 0.01
    optimizer = optimizer_with_attributes(
        HiGHS.Optimizer, "mip_rel_gap" => mip_optim_gap, "threads" => 20
    )
    return optimizer
end

function collate_actual_data(region::String, start_time::DateTime, end_time::DateTime)
    @info("Collating actual data")
    all_actual_data = NEMStorageUnderUncertainty.get_all_actual_data("data/dispatch_price")
    actual_data = NEMStorageUnderUncertainty.get_ActualData(
        all_actual_data, region, (start_time, end_time)
    )
    return all_actual_data, actual_data
end

function simulate(
    storage::NEMStorageUnderUncertainty.StorageDevice,
    data::NEMStorageUnderUncertainty.ActualData,
    formulation::NEMStorageUnderUncertainty.ArbitrageCapContracted,
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
        formulation,
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

"""
N.B. capital_cost should be in AUD/MWh
"""
function simulate_actual2021_ArbCapContracted_NoDeg(
    power::Float64, energy::Float64, cap_contracted::Float64
)
    if !isdir(joinpath(@__DIR__, "results"))
        mkdir(joinpath(@__DIR__, "results"))
    end
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
    (data_start, data_end) = (start_time, end_time + lookaheads[end])
    all_actual_data, actual_data = collate_actual_data("NSW1", data_start, data_end)
    storage = NEMStorageUnderUncertainty.BESS(;
        power_capacity=power,
        energy_capacity=energy,
        soc_min=0.1 * energy,
        soc_max=0.9 * energy,
        η_charge=0.91,
        η_discharge=0.91,
        soc₀=0.5 * energy,
        throughput=0.0,
    )
    @info("BESS $power MW $energy MWh cost $cap_contracted")
    @info("Simulating perfect foresight")
    d_lifetime = storage.energy_capacity * 365.0 * 10.0
    # Middle of the range capital cost for 2022-23
    formulation = NEMStorageUnderUncertainty.ArbitrageCapContracted(
        d_lifetime, 600000.0, cap_contracted
    )
    perfect_foresight_result = NEMStorageUnderUncertainty.run_perfect_foresight(
        optimizer_with_attributes(HiGHS.Optimizer, "threads" => 20),
        storage,
        actual_data,
        formulation,
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
            actual_data,
            formulation,
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
    df = NEMStorageUnderUncertainty.calculate_actual_revenue(
        df, all_actual_data, actual_data.τ
    )
    NEMStorageUnderUncertainty.results_to_jld2(
        joinpath(
            @__DIR__,
            "results",
            ("NSW_$(energy)MWh_ArbCapContracted_param$(cap_contracted)_NoDeg_2021.jld2"),
        ),
        "actual",
        "$(power)MW",
        df,
    )
    return nothing
end

@assert !isempty(ARGS) "Provide power and energy capacity and cap contract quantity (MW) as arguments (in that order)"
args = parse.(Float64, ARGS)
simulate_actual2021_ArbCapContracted_NoDeg(args[1], args[2], args[3])
