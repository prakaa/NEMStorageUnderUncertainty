import MathOptInterface: OptimizerWithAttributes
using Cbc
using CSV
using Dates
using DataFrames
using Gurobi
using HiGHS
using JuMP
using NEMStorageUnderUncertainty: NEMStorageUnderUncertainty

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
            HiGHS.Optimizer, "mip_rel_gap" => mip_optim_gap
        )
    elseif optimizer_str == "Cbc"
        optimizer = optimizer_with_attributes(Cbc.Optimizer, "ratioGap" => mip_optim_gap)
    else
        error("Specify valid optimizer")
    end
    return optimizer
end

function simulate_actual(
    data::NEMStorageUnderUncertainty.ActualData, binding::T, horizon::T
) where {T<:Period}
    optimizer = set_optimizer("Gurobi")
    storage = NEMStorageUnderUncertainty.BESS(;
        power_capacity=30.0,
        energy_capacity=30.0,
        soc_min=0.1 * 30.0,
        soc_max=0.9 * 30.0,
        η_charge=0.95,
        η_discharge=0.95,
        soc₀=0.5 * 30.0,
        throughput=0.0,
    )
    (start_time, end_time) = (DateTime(2021, 1, 1, 0, 0, 0), DateTime(2022, 1, 1, 0, 0, 0))
    @info("Starting simulations")
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
    @info("Collating actual data")
    actual_data = NEMStorageUnderUncertainty.make_ActualData(
        "data/dispatch_price", "NSW1", nothing
    )
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
    Threads.@threads for horizon in lookaheads
        @info("Starting lookahead $horizon")
        results = simulate_actual(actual_data, Minute(5), horizon)
        push!(all_results, results)
        @info("Completed lookahead $horizon")
    end
    return all_results
end

all_results = main()
df = vcat(all_results...)
if !isdir(joinpath(@__DIR__, "results"))
    mkdir(joinpath(@__DIR__, "results"))
end
CSV.write(joinpath(@__DIR__, "results", "actual_StandardArb_NoDeg_2021_lookaheads.csv"), df)
