using DataFrames
using Dates
using NEMStorageUnderUncertainty: NEMStorageUnderUncertainty
using Test

@testset "Run Simulation Period Tests" begin
    @testset "Run Actual Data Tests" begin
        test_data_path = joinpath(@__DIR__, "test_data")
        all_actual_data = NEMStorageUnderUncertainty.get_all_actual_data(
            joinpath(test_data_path, "dispatch_price")
        )
        actual = NEMStorageUnderUncertainty.get_ActualData(all_actual_data, "NSW1", nothing)
        decision_times = (DateTime(2021, 12, 1, 0, 5, 0), DateTime(2021, 12, 20, 0, 0, 0))
        times = actual.times
        @testset "Run input validation tests" begin
            @test_throws AssertionError NEMStorageUnderUncertainty._get_periods_for_simulation(
                decision_times[1] - Minute(5),
                decision_times[2],
                Minute(5),
                Minute(30),
                actual,
            )
            @test_throws AssertionError NEMStorageUnderUncertainty._get_periods_for_simulation(
                decision_times[1],
                decision_times[2] + Day(20),
                Minute(5),
                Minute(30),
                actual,
            )
            @test_throws AssertionError NEMStorageUnderUncertainty._get_periods_for_simulation(
                decision_times[1],
                decision_times[2],
                Minute(5),
                Minute(20 * 24 * 60),
                actual,
            )
        end
        @testset "Run single binding period tests" begin
            single_binding = NEMStorageUnderUncertainty._get_periods_for_simulation(
                decision_times[1], decision_times[2], Minute(5), Minute(60), actual
            )
            @test times[single_binding[1, :decision_interval]] == decision_times[1]
            @test times[single_binding[1, :binding_start]] == decision_times[1] + Minute(5)
            @test times[single_binding[1, :binding_end]] == decision_times[1] + Minute(5)
            @test times[single_binding[1, :horizon_end]] == decision_times[1] + Minute(60)
            @test times[single_binding[10, :binding_start]] ==
                decision_times[1] + Minute(50)
            @test times[single_binding[10, :binding_end]] == decision_times[1] + Minute(50)
            @test times[single_binding[end, :decision_interval]] == decision_times[2]
        end
        @testset "Run multiple binding period tests" begin
            @test_throws AssertionError NEMStorageUnderUncertainty._get_periods_for_simulation(
                decision_times[1], decision_times[2], Hour(1), Hour(2), actual
            )
            decision_times_hour = (
                DateTime(2021, 12, 1, 0, 5, 0), DateTime(2021, 12, 20, 2, 5, 0)
            )
            hour_binding = NEMStorageUnderUncertainty._get_periods_for_simulation(
                decision_times_hour[1], decision_times_hour[2], Hour(1), Hour(2), actual
            )
            @test times[hour_binding[1, :decision_interval]] == decision_times_hour[1]
            @test times[hour_binding[1, :binding_start]] ==
                decision_times_hour[1] + Minute(5)
            @test times[hour_binding[1, :binding_end]] ==
                decision_times_hour[1] + Minute(60)
            @test times[hour_binding[1, :horizon_end]] ==
                decision_times_hour[1] + Minute(120)
            @test times[hour_binding[10, :binding_start]] ==
                decision_times_hour[1] + Hour(9) + Minute(5)
            @test times[hour_binding[10, :binding_end]] ==
                decision_times_hour[1] + Hour(9) + Minute(60)
            @test times[hour_binding[end, :decision_interval]] == decision_times_hour[2]
        end
    end
    @testset "Run Forecast Data Tests" begin
        test_data_path = joinpath(@__DIR__, "test_data")
        (pd_df, p5_df) = NEMStorageUnderUncertainty.get_all_pd_and_p5_data(
            joinpath(test_data_path, "forecast_price", "PREDISPATCH"),
            joinpath(test_data_path, "forecast_price", "P5MIN"),
        )
        rtimes = (DateTime(2021, 1, 1, 5, 0, 0), DateTime(2021, 1, 20, 5, 0, 0))
        forecast = NEMStorageUnderUncertainty.get_ForecastData(
            pd_df, p5_df, "NSW1", rtimes, nothing
        )
        decision_times = (DateTime(2021, 1, 1, 5, 5, 0), DateTime(2021, 1, 20, 5, 0, 0))
        run_times = forecast.run_times
        forecasted_times = forecast.forecasted_times
        @testset "Run input validation tests" begin
            @test_throws AssertionError NEMStorageUnderUncertainty._get_periods_for_simulation(
                decision_times[1] - Minute(10),
                decision_times[2],
                Minute(5),
                Minute(30),
                forecast,
            )
            @test_throws AssertionError NEMStorageUnderUncertainty._get_periods_for_simulation(
                decision_times[1],
                decision_times[2] + Day(20),
                Minute(5),
                Minute(30),
                forecast,
            )
            @test_throws AssertionError NEMStorageUnderUncertainty._get_periods_for_simulation(
                decision_times[1],
                decision_times[2],
                Minute(5),
                Minute(45 * 24 * 60),
                forecast,
            )
        end
        @testset "Run single binding period tests" begin
            single_binding = NEMStorageUnderUncertainty._get_periods_for_simulation(
                decision_times[1], decision_times[2], Minute(5), Minute(60), forecast
            )
            @test run_times[single_binding[1, :decision_interval]] == decision_times[1]
            @test forecasted_times[single_binding[1, :binding_start]] ==
                decision_times[1] + Minute(5)
            @test forecasted_times[single_binding[1, :binding_end]] ==
                decision_times[1] + Minute(5)
            @test forecasted_times[single_binding[1, :horizon_end]] ==
                decision_times[1] + Minute(60)
            @test forecasted_times[single_binding[10, :binding_start]] ==
                decision_times[1] + Minute(50)
            @test forecasted_times[single_binding[10, :binding_end]] ==
                decision_times[1] + Minute(50)
            @test run_times[single_binding[end, :decision_interval]] == decision_times[2]
        end
        @testset "Run multiple binding period tests" begin
            @test_throws AssertionError NEMStorageUnderUncertainty._get_periods_for_simulation(
                decision_times[1], decision_times[2], Hour(1), Hour(2), forecast
            )
            decision_times_hour = (
                DateTime(2021, 1, 1, 5, 5, 0), DateTime(2021, 1, 20, 2, 5, 0)
            )
            hour_binding = NEMStorageUnderUncertainty._get_periods_for_simulation(
                decision_times_hour[1], decision_times_hour[2], Hour(1), Hour(2), forecast
            )
            @test run_times[hour_binding[1, :decision_interval]] == decision_times_hour[1]
            @test forecasted_times[hour_binding[1, :binding_start]] ==
                decision_times_hour[1] + Minute(5)
            @test forecasted_times[hour_binding[1, :binding_end]] ==
                decision_times_hour[1] + Minute(60)
            @test forecasted_times[hour_binding[1, :horizon_end]] ==
                decision_times_hour[1] + Minute(120)
            @test forecasted_times[hour_binding[10, :binding_start]] ==
                decision_times_hour[1] + Hour(9) + Minute(5)
            @test forecasted_times[hour_binding[10, :binding_end]] ==
                decision_times_hour[1] + Hour(9) + Minute(60)
            @test run_times[hour_binding[end, :decision_interval]] == decision_times_hour[2]
        end
    end
end
