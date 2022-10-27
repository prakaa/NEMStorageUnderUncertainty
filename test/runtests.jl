import Dates: DateTime
using JuMP: JuMP

using HiGHS: HiGHS
using NEMStorageUnderUncertainty: NEMStorageUnderUncertainty
using Test

function test_run_model(data_path::String)
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
        actual,
        "NSW1";
        actual_data_window=(DateTime(2021, 12, 1, 0, 5, 0), DateTime(2022, 1, 1, 0, 0, 0)),
    )

    model = NEMStorageUnderUncertainty._run_model(
        HiGHS.Optimizer, bess, times, prices, NEMStorageUnderUncertainty.StandardArbitrage()
    )
    return JuMP.objective_value(model)
end

@testset "NEMStorageUnderUncertainty.jl" begin
    @test isapprox(test_run_model("test/test_data"), 171887, atol=0.5)
end
