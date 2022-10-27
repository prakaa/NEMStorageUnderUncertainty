import Dates: DateTime
using JuMP: JuMP

using HiGHS: HiGHS
using NEMStorageUnderUncertainty: NEMStorageUnderUncertainty
using Test

function test_run_model(data_path::String, start_time::DateTime, end_time::DateTime)
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
    actual = NEMStorageUnderUncertainty.get_all_actual_prices(actual_price_data_path)
    (times, prices) = NEMStorageUnderUncertainty.get_regional_times_and_prices(
        actual, "NSW1"; actual_data_window=(start_time, end_time)
    )
    if length(times) > 1
        τ = NEMStorageUnderUncertainty._get_times_frequency_in_hours(times)
    else
        τ = 5.0 / 12.0
    end
    model = NEMStorageUnderUncertainty._run_model(
        HiGHS.Optimizer,
        bess,
        times,
        prices,
        τ,
        NEMStorageUnderUncertainty.StandardArbitrage(),
    )
    return model
end

@testset "Run Model Tests" begin
    month_model = test_run_model(
        "test/test_data", DateTime(2021, 12, 1, 0, 5, 0), DateTime(2022, 1, 1, 0, 0, 0)
    )
    @test isapprox(JuMP.objective_value(model), 171887, atol=0.5)
    interval_model = test_run_model(
        "test/test_data", DateTime(2021, 12, 1, 0, 5, 0), DateTime(2021, 12, 1, 0, 5, 0)
    )
    @test JuMP.num_constraints(interval_model; count_variable_in_set_constraints=false) == 3
end
