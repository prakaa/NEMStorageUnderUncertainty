import Dates: DateTime
using NEMStorageUnderUncertainty: NEMStorageUnderUncertainty
using HiGHS
using JuMP
using Test

function test_run_model(
    data_path::String,
    start_time::DateTime,
    end_time::DateTime;
    time_limit_sec::Union{Float64,Nothing}=nothing,
)
    bess = NEMStorageUnderUncertainty.BESS(;
        power_capacity=30.0,
        energy_capacity=30.0,
        soc_min=0.1 * 30.0,
        soc_max=0.9 * 30.0,
        η_charge=0.9,
        η_discharge=0.9,
        soc₀=0.5 * 30.0,
        throughput=0.0,
    )
    actual_price_data_path = joinpath(data_path, "dispatch_price")
    actual_data = NEMStorageUnderUncertainty.get_all_actual_data(actual_price_data_path)
    actual = NEMStorageUnderUncertainty.get_ActualData(
        actual_data, "NSW1", (start_time, end_time)
    )
    model = NEMStorageUnderUncertainty.run_model(
        optimizer_with_attributes(HiGHS.Optimizer),
        bess,
        actual.prices,
        actual.times,
        actual.τ,
        NEMStorageUnderUncertainty.StandardArbitrage();
        time_limit_sec=time_limit_sec,
    )
    return model
end

@testset "Run Model Tests" begin
    test_data_path = joinpath(@__DIR__, "test_data")
    month_model = test_run_model(
        test_data_path, DateTime(2021, 12, 1, 0, 5, 0), DateTime(2022, 1, 1, 0, 0, 0)
    )
    @test isapprox(JuMP.objective_value(month_model), 171887, atol=0.5)
    interval_model = test_run_model(
        test_data_path, DateTime(2021, 12, 1, 0, 5, 0), DateTime(2021, 12, 1, 0, 5, 0)
    )
    @test JuMP.num_constraints(interval_model; count_variable_in_set_constraints=false) == 5
    @test_logs (
        :warn,
        (
            "Model run between 2021-12-01T00:05:00 and 2022-01-01T00:00:00 hit " *
            "iteration/time limit"
        ),
    ) test_run_model(
        test_data_path,
        DateTime(2021, 12, 1, 0, 5, 0),
        DateTime(2022, 1, 1, 0, 0, 0);
        time_limit_sec=1.0,
    )
end
