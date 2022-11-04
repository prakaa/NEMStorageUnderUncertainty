import MathOptInterface: OptimizerWithAttributes
using Cbc
using CSV
using Dates
using DataFrames
using Gurobi
using HiGHS
using JuMP
using NEMStorageUnderUncertainty: NEMStorageUnderUncertainty
using ProgressMeter

# suppresses Gurobi solver output
const GUROBI_ENV = Gurobi.Env()

function set_optimizer(optimizer_str::String)
    mip_optim_gap = 0.0001
    if optimizer_str == "Gurobi"
        # Suppresses Gurobi solver output
        optimizer = optimizer_with_attributes(
            () -> Gurobi.Optimizer(GUROBI_ENV), "MIPGap" => mip_optim_gap
        )
    elseif optimizer_str == "HiGHS"
        optimizer = optimizer_with_attributes(
            HiGHS.Optimizer, "mip_rel_gap" => mip_optim_gap, "threads" => 10
        )
    elseif optimizer_str == "Cbc"
        optimizer = optimizer_with_attributes(Cbc.Optimizer, "ratioGap" => mip_optim_gap)
    else
        error("Specify valid optimizer")
    end
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

function simulate_actual(
    storage::NEMStorageUnderUncertainty.StorageDevice,
    data::NEMStorageUnderUncertainty.ActualData,
    binding::T,
    horizon::T;
    start_time::DateTime,
    end_time::DateTime,
) where {T<:Period}
    optimizer = set_optimizer("Gurobi")
    results = NEMStorageUnderUncertainty.simulate_storage_operation(
        optimizer,
        storage,
        data,
        NEMStorageUnderUncertainty.StandardArbitrage(),
        NEMStorageUnderUncertainty.NoDegradation();
        decision_start_time=start_time,
        decision_end_time=end_time,
        binding=binding,
        horizon=horizon,
        silent=true,
        show_progress=false,
    )
    return results
end

function main()
    if !isdir(joinpath(@__DIR__, "results"))
        mkdir(joinpath(@__DIR__, "results"))
    end
    optimizer = set_optimizer("Gurobi")
    (start_time, end_time) = (DateTime(2021, 1, 1, 0, 0, 0), DateTime(2022, 1, 1, 0, 0, 0))
    (data_start, data_end) = (start_time, end_time + Minute(5))
    all_actual_data, actual_data = collate_actual_data(
        "NSW1", data_start, data_end
    )
    p = Progress(5)
    Threads.@threads for c_multiplier in (0.25, 0.5, 1.0, 2.0, 5.0)
        energy = 100.0
        power = energy * c_multiplier
        storage = NEMStorageUnderUncertainty.BESS(;
            power_capacity=power,
            energy_capacity=energy,
            soc_min=0.1 * 30.0,
            soc_max=0.9 * 30.0,
            η_charge=0.95,
            η_discharge=0.95,
            soc₀=0.5 * 30.0,
            throughput=0.0,
        )
        @info("BESS $power MW $energy MWh")
        @info("Simulating perfect foresight")
        perfect_foresight_result = NEMStorageUnderUncertainty.run_perfect_foresight(
            optimizer,
            storage,
            actual_data,
            NEMStorageUnderUncertainty.StandardArbitrage();
            silent=false,
        )
        @info("Finished simulating perfect foresight")
        lookaheads = [
            Minute(5),
            Minute(15),
            Minute(30),
            Minute(60),
            Minute(240),
            Minute(480),
            Minute(24 * 60),
        ]
        all_results = DataFrame[]
        for horizon in lookaheads
            @info("Starting lookahead $horizon simulation")
            results = simulate_actual(
                storage,
                actual_data,
                Minute(5),
                horizon;
                start_time=start_time,
                end_time=end_time,
            )
            push!(all_results, results)
            @info("Completed lookahead $horizon simulation")
        end
        df = vcat(all_results..., perfect_foresight_result)
        df = NEMStorageUnderUncertainty.calculate_actual_revenue!(
            df, all_actual_data, actual_data.τ
        )
        CSV.write(
            joinpath(
                @__DIR__,
                "results",
                "NSW_$(power)MW_$(energy)MWh_actual_StandardArb_NoDeg_2021_lookaheads.csv",
            ),
            df,
        )
        next!(p)
    end
end

main()