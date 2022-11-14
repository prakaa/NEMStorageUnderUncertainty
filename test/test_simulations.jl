using DataFrames
using Dates
using HiGHS
using JuMP
using JLD2
using NEMStorageUnderUncertainty: NEMStorageUnderUncertainty
using Test

@testset "Run Simulation Period Tests" begin
    test_data_path = joinpath(@__DIR__, "test_data")
    @testset "Run Actual Data Tests" begin
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

function test_common_expected_results(
    results::DataFrame,
    binding::Period,
    lookahead::Period,
    decision_start_time::DateTime,
    decision_end_time::DateTime;
    capture_all_decisions::Bool=false,
)
    @test results[1, :simulated_time] == decision_start_time + Minute(5)
    if capture_all_decisions
        @test results[end, :simulated_time] == decision_end_time + lookahead
    else
        @test results[end, :simulated_time] == decision_end_time + binding
    end
    @test unique(results.lookahead_minutes)[] == Dates.value(lookahead)
    @test unique(results.REGIONID)[] == "NSW1"
    return nothing
end

@testset "Run Actual Data Simulation Tests" begin
    test_data_path = joinpath(@__DIR__, "test_data")
    all_actual_data = NEMStorageUnderUncertainty.get_all_actual_data(
        joinpath(test_data_path, "dispatch_price")
    )
    actual_data = NEMStorageUnderUncertainty.get_ActualData(
        all_actual_data, "NSW1", nothing
    )
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
    decision_start_time = DateTime(2021, 12, 1, 12, 0, 0)
    decision_end_time = DateTime(2021, 12, 2, 12, 00, 0)
    @testset "Test single period" begin
        results = NEMStorageUnderUncertainty.simulate_storage_operation(
            optimizer_with_attributes(HiGHS.Optimizer),
            storage,
            actual_data,
            NEMStorageUnderUncertainty.StandardArbitrage(),
            NEMStorageUnderUncertainty.NoDegradation();
            decision_start_time=decision_start_time,
            decision_end_time=decision_end_time,
            binding=Minute(5),
            horizon=Minute(5),
        )
        test_common_expected_results(
            results, Minute(5), Minute(5), decision_start_time, decision_end_time
        )
        @test unique(results.status)[] == "binding"
        @testset "Test revenue calculations" begin
            revenue = NEMStorageUnderUncertainty.calculate_actual_revenue(
                results, all_actual_data, actual_data.τ
            )
            test_row = revenue[rand(1:size(revenue)[1]), :]
            @test test_row[:revenue] ==
                test_row[:actual_price] *
                  (test_row[:discharge_mw] - test_row[:charge_mw]) *
                  actual_data.τ
        end
        @testset "Testing SoC evolution" begin
            charge_test_index = rand(findall(x -> x > 0, results.charge_mw))
            discharge_test_index = rand(findall(x -> x > 0, results.discharge_mw))
            for test_index in (charge_test_index, discharge_test_index)
                soc_next = results[test_index + 1, :soc_mwh]
                calc_soc = (
                    results[test_index, :soc_mwh] +
                    results[test_index + 1, :charge_mw] * storage.η_charge * actual_data.τ -
                    results[test_index + 1, :discharge_mw] / storage.η_discharge *
                    actual_data.τ
                )
                @test isapprox(calc_soc, soc_next, atol=0.1)
            end
        end
        @testset "Test intersim updates" begin
            test_indices = findall(
                x -> x > Millisecond(0),
                results[2:end, :decision_time] - results[1:(end - 1), :decision_time],
            )
            test_index = rand(test_indices)
            @test results[test_index + 1, :throughput_mwh] ==
                results[test_index, :throughput_mwh] +
                  results[test_index + 1, :discharge_mw] * actual_data.τ
            calc_soc = (
                results[test_index, :soc_mwh] +
                results[test_index + 1, :charge_mw] * storage.η_charge * actual_data.τ -
                results[test_index + 1, :discharge_mw] / storage.η_discharge *
                actual_data.τ
            )
            @test isapprox(calc_soc, results[test_index + 1, :soc_mwh], atol=0.1)
        end
    end
    @testset "Test multi period" begin
        results = NEMStorageUnderUncertainty.simulate_storage_operation(
            optimizer_with_attributes(HiGHS.Optimizer),
            storage,
            actual_data,
            NEMStorageUnderUncertainty.StandardArbitrage(),
            NEMStorageUnderUncertainty.NoDegradation();
            decision_start_time=decision_start_time + Minute(20),
            decision_end_time=decision_end_time + Minute(20),
            binding=Minute(5),
            horizon=Minute(10),
            capture_all_decisions=true,
            relative_gap_in_results=true,
        )
        test_common_expected_results(
            results,
            Minute(5),
            Minute(10),
            decision_start_time + Minute(20),
            decision_end_time + Minute(20);
            capture_all_decisions=true,
        )
        @test unique(results.status) == Vector(["binding", "non binding"])
        @test typeof(results.relative_gap) == Vector{Float64}
        @test all(0.0 .≤ results.relative_gap .≤ 1.0)
        @testset "Test revenue calculations" begin
            revenue = NEMStorageUnderUncertainty.calculate_actual_revenue(
                results, all_actual_data, actual_data.τ
            )
            binding_revenue = revenue[revenue.status .== "binding", :]
            test_row = binding_revenue[rand(1:size(binding_revenue)[1]), :]
            @test test_row[:revenue] ==
                test_row[:actual_price] *
                  (test_row[:discharge_mw] - test_row[:charge_mw]) *
                  actual_data.τ
            non_binding_revenue = revenue[revenue.status .== "non binding", :]
            @test all(ismissing.(non_binding_revenue.revenue))
        end
        @testset "Testing SoC evolution" begin
            filter!(:status => x -> x == "binding", results)
            charge_test_index = rand(findall(x -> x > 0, results.charge_mw))
            discharge_test_index = rand(findall(x -> x > 0, results.discharge_mw))
            for test_index in (charge_test_index, discharge_test_index)
                soc_next = results[test_index + 1, :soc_mwh]
                calc_soc = (
                    results[test_index, :soc_mwh] +
                    results[test_index + 1, :charge_mw] * storage.η_charge * actual_data.τ -
                    results[test_index + 1, :discharge_mw] / storage.η_discharge *
                    actual_data.τ
                )
                @test isapprox(calc_soc, soc_next, atol=0.01)
            end
        end
        @testset "Test intersim updates" begin
            test_indices = findall(
                x -> x > Millisecond(0),
                results[2:end, :decision_time] - results[1:(end - 1), :decision_time],
            )
            test_index = rand(test_indices)
            @test results[test_index + 1, :throughput_mwh] ==
                results[test_index, :throughput_mwh] +
                  results[test_index + 1, :discharge_mw] * actual_data.τ
            calc_soc = (
                results[test_index, :soc_mwh] +
                results[test_index + 1, :charge_mw] * storage.η_charge * actual_data.τ -
                results[test_index + 1, :discharge_mw] / storage.η_discharge *
                actual_data.τ
            )
            @test isapprox(calc_soc, results[test_index + 1, :soc_mwh], atol=0.1)
        end
    end
    @testset "Test multi binding, multi period" begin
        results = NEMStorageUnderUncertainty.simulate_storage_operation(
            optimizer_with_attributes(HiGHS.Optimizer),
            storage,
            actual_data,
            NEMStorageUnderUncertainty.StandardArbitrage(),
            NEMStorageUnderUncertainty.NoDegradation();
            decision_start_time=decision_start_time + Minute(10),
            decision_end_time=decision_end_time - Minute(5),
            binding=Minute(15),
            horizon=Minute(30),
        )
        test_common_expected_results(
            results,
            Minute(15),
            Minute(30),
            decision_start_time + Minute(10),
            decision_end_time - Minute(5),
        )
        unique_decision_times = unique(results.decision_time)
        @test unique(diff(unique_decision_times))[] == Minute(15)
        @testset "Test revenue calculations" begin
            revenue = NEMStorageUnderUncertainty.calculate_actual_revenue(
                results, all_actual_data, actual_data.τ
            )
            test_row = revenue[rand(1:size(revenue)[1]), :]
            @test test_row[:revenue] ==
                test_row[:actual_price] *
                  (test_row[:discharge_mw] - test_row[:charge_mw]) *
                  actual_data.τ
        end
        @testset "Testing SoC evolution" begin
            charge_test_index = findall(x -> x > 0, results.charge_mw)
            charge_test_index = rand(charge_test_index[1:(end - 1)])
            discharge_test_index = findall(x -> x > 0, results.discharge_mw)
            discharge_test_index = rand(discharge_test_index[1:(end - 1)])
            for test_index in (charge_test_index, discharge_test_index)
                soc_next = results[test_index + 1, :soc_mwh]
                calc_soc = (
                    results[test_index, :soc_mwh] +
                    results[test_index + 1, :charge_mw] * storage.η_charge * actual_data.τ -
                    results[test_index + 1, :discharge_mw] / storage.η_discharge *
                    actual_data.τ
                )
                @test isapprox(calc_soc, soc_next, atol=0.01)
            end
        end
        @testset "Test intersim updates" begin
            test_indices = findall(
                x -> x > Millisecond(0),
                results[2:end, :decision_time] - results[1:(end - 1), :decision_time],
            )
            test_index = rand(test_indices)
            @test results[test_index + 1, :throughput_mwh] ==
                results[test_index, :throughput_mwh] +
                  results[test_index + 1, :discharge_mw] * actual_data.τ
            calc_soc = (
                results[test_index, :soc_mwh] +
                results[test_index + 1, :charge_mw] * storage.η_charge * actual_data.τ -
                results[test_index + 1, :discharge_mw] / storage.η_discharge *
                actual_data.τ
            )
            @test isapprox(calc_soc, results[test_index + 1, :soc_mwh], atol=0.1)
        end
    end
end

@testset "Run Forecasted Data Simulation Tests" begin
    test_data_path = joinpath(@__DIR__, "test_data", "forecast_price")
    pd_path = joinpath(test_data_path, "PREDISPATCH")
    p5_path = joinpath(test_data_path, "P5MIN")
    (pd_df, p5_df) = NEMStorageUnderUncertainty.get_all_pd_and_p5_data(pd_path, p5_path)
    all_actual_data = NEMStorageUnderUncertainty.get_all_actual_data(
        joinpath(@__DIR__, "test_data", "dispatch_price_for_forecast")
    )
    unaligned_forecast_data = NEMStorageUnderUncertainty.get_ForecastData(
        pd_df, p5_df, "NSW1", nothing, nothing
    )
    aligned_forecast_data = NEMStorageUnderUncertainty.get_ForecastData(
        pd_df,
        p5_df,
        "NSW1",
        (DateTime(2021, 1, 1, 4, 30, 0), DateTime(2021, 1, 2, 4, 30, 0)),
        nothing,
    )
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
    decision_start_time = DateTime(2021, 1, 1, 12, 0, 0)
    decision_end_time = DateTime(2021, 1, 2, 2, 00, 0)
    @testset "Test single period" begin
        results = NEMStorageUnderUncertainty.simulate_storage_operation(
            optimizer_with_attributes(HiGHS.Optimizer),
            storage,
            aligned_forecast_data,
            NEMStorageUnderUncertainty.StandardArbitrage(),
            NEMStorageUnderUncertainty.NoDegradation();
            decision_start_time=decision_start_time,
            decision_end_time=decision_end_time,
            binding=Minute(5),
            horizon=Minute(5),
        )
        test_common_expected_results(
            results, Minute(5), Minute(5), decision_start_time, decision_end_time
        )
        @test unique(results.status)[] == "binding"
        @testset "Test revenue calculations" begin
            revenue = NEMStorageUnderUncertainty.calculate_actual_revenue(
                results, all_actual_data, aligned_forecast_data.τ
            )
            test_row = revenue[rand(1:size(revenue)[1]), :]
            @test test_row[:revenue] ==
                test_row[:actual_price] *
                  (test_row[:discharge_mw] - test_row[:charge_mw]) *
                  aligned_forecast_data.τ
        end
        @testset "Testing SoC evolution" begin
            charge_test_index = rand(findall(x -> x > 0, results.charge_mw))
            discharge_test_index = rand(findall(x -> x > 0, results.discharge_mw))
            for test_index in (charge_test_index, discharge_test_index)
                soc_next = results[test_index + 1, :soc_mwh]
                calc_soc = (
                    results[test_index, :soc_mwh] +
                    results[test_index + 1, :charge_mw] *
                    storage.η_charge *
                    aligned_forecast_data.τ -
                    results[test_index + 1, :discharge_mw] / storage.η_discharge *
                    aligned_forecast_data.τ
                )
                @test isapprox(calc_soc, soc_next, atol=0.1)
            end
        end
        @testset "Test intersim updates" begin
            test_indices = findall(
                x -> x > Millisecond(0),
                results[2:end, :decision_time] - results[1:(end - 1), :decision_time],
            )
            test_index = rand(test_indices)
            @test results[test_index + 1, :throughput_mwh] ==
                results[test_index, :throughput_mwh] +
                  results[test_index + 1, :discharge_mw] * aligned_forecast_data.τ
            calc_soc = (
                results[test_index, :soc_mwh] +
                results[test_index + 1, :charge_mw] *
                storage.η_charge *
                aligned_forecast_data.τ -
                results[test_index + 1, :discharge_mw] / storage.η_discharge *
                aligned_forecast_data.τ
            )
            @test isapprox(calc_soc, results[test_index + 1, :soc_mwh], atol=0.1)
        end
    end
    @testset "Test multi period" begin
        results = NEMStorageUnderUncertainty.simulate_storage_operation(
            optimizer_with_attributes(HiGHS.Optimizer),
            storage,
            aligned_forecast_data,
            NEMStorageUnderUncertainty.StandardArbitrage(),
            NEMStorageUnderUncertainty.NoDegradation();
            decision_start_time=decision_start_time + Minute(20),
            decision_end_time=decision_end_time + Minute(20),
            binding=Minute(5),
            horizon=Minute(10),
            capture_all_decisions=true,
            relative_gap_in_results=true,
        )
        test_common_expected_results(
            results,
            Minute(5),
            Minute(10),
            decision_start_time + Minute(20),
            decision_end_time + Minute(20);
            capture_all_decisions=true,
        )
        @test unique(results.status) == Vector(["binding", "non binding"])
        @test typeof(results.relative_gap) == Vector{Float64}
        @test all(0.0 .≤ results.relative_gap .≤ 1.0)
        @testset "Test revenue calculations" begin
            revenue = NEMStorageUnderUncertainty.calculate_actual_revenue(
                results, all_actual_data, aligned_forecast_data.τ
            )
            binding_revenue = revenue[revenue.status .== "binding", :]
            test_row = binding_revenue[rand(1:size(binding_revenue)[1]), :]
            @test test_row[:revenue] ==
                test_row[:actual_price] *
                  (test_row[:discharge_mw] - test_row[:charge_mw]) *
                  aligned_forecast_data.τ
            non_binding_revenue = revenue[revenue.status .== "non binding", :]
            @test all(ismissing.(non_binding_revenue.revenue))
        end
        @testset "Testing SoC evolution" begin
            filter!(:status => x -> x == "binding", results)
            charge_test_index = rand(findall(x -> x > 0, results.charge_mw))
            discharge_test_index = rand(findall(x -> x > 0, results.discharge_mw))
            for test_index in (charge_test_index, discharge_test_index)
                soc_next = results[test_index + 1, :soc_mwh]
                calc_soc = (
                    results[test_index, :soc_mwh] +
                    results[test_index + 1, :charge_mw] *
                    storage.η_charge *
                    aligned_forecast_data.τ -
                    results[test_index + 1, :discharge_mw] / storage.η_discharge *
                    aligned_forecast_data.τ
                )
                @test isapprox(calc_soc, soc_next, atol=0.01)
            end
        end
        @testset "Test intersim updates" begin
            test_indices = findall(
                x -> x > Millisecond(0),
                results[2:end, :decision_time] - results[1:(end - 1), :decision_time],
            )
            test_index = rand(test_indices)
            @test isapprox(
                results[test_index + 1, :throughput_mwh],
                results[test_index, :throughput_mwh] +
                results[test_index + 1, :discharge_mw] * aligned_forecast_data.τ,
            )
            calc_soc = (
                results[test_index, :soc_mwh] +
                results[test_index + 1, :charge_mw] *
                storage.η_charge *
                aligned_forecast_data.τ -
                results[test_index + 1, :discharge_mw] / storage.η_discharge *
                aligned_forecast_data.τ
            )
            @test isapprox(calc_soc, results[test_index + 1, :soc_mwh], atol=0.1)
        end
    end
    @testset "Test multi binding, multi period" begin
        results = NEMStorageUnderUncertainty.simulate_storage_operation(
            optimizer_with_attributes(HiGHS.Optimizer),
            storage,
            aligned_forecast_data,
            NEMStorageUnderUncertainty.StandardArbitrage(),
            NEMStorageUnderUncertainty.NoDegradation();
            decision_start_time=decision_start_time + Minute(10),
            decision_end_time=decision_end_time - Minute(5),
            binding=Minute(15),
            horizon=Minute(30),
        )
        test_common_expected_results(
            results,
            Minute(15),
            Minute(30),
            decision_start_time + Minute(10),
            decision_end_time - Minute(5),
        )
        unique_decision_times = unique(results.decision_time)
        @test unique(diff(unique_decision_times))[] == Minute(15)
        @testset "Test revenue calculations" begin
            revenue = NEMStorageUnderUncertainty.calculate_actual_revenue(
                results, all_actual_data, aligned_forecast_data.τ
            )
            test_row = revenue[rand(1:size(revenue)[1]), :]
            @test test_row[:revenue] ==
                test_row[:actual_price] *
                  (test_row[:discharge_mw] - test_row[:charge_mw]) *
                  aligned_forecast_data.τ
        end
        @testset "Testing SoC evolution" begin
            charge_test_index = rand(findall(x -> x > 0, results.charge_mw))
            discharge_test_index = rand(findall(x -> x > 0, results.discharge_mw))
            for test_index in (charge_test_index, discharge_test_index)
                soc_next = results[test_index + 1, :soc_mwh]
                calc_soc = (
                    results[test_index, :soc_mwh] +
                    results[test_index + 1, :charge_mw] *
                    storage.η_charge *
                    aligned_forecast_data.τ -
                    results[test_index + 1, :discharge_mw] / storage.η_discharge *
                    aligned_forecast_data.τ
                )
                @test isapprox(calc_soc, soc_next, atol=0.01)
            end
        end
        @testset "Test intersim updates" begin
            test_indices = findall(
                x -> x > Millisecond(0),
                results[2:end, :decision_time] - results[1:(end - 1), :decision_time],
            )
            test_index = rand(test_indices)
            @test results[test_index + 1, :throughput_mwh] ==
                results[test_index, :throughput_mwh] +
                  results[test_index + 1, :discharge_mw] * aligned_forecast_data.τ
            calc_soc = (
                results[test_index, :soc_mwh] +
                results[test_index + 1, :charge_mw] *
                storage.η_charge *
                aligned_forecast_data.τ -
                results[test_index + 1, :discharge_mw] / storage.η_discharge *
                aligned_forecast_data.τ
            )
            @test isapprox(calc_soc, results[test_index + 1, :soc_mwh], atol=0.1)
        end
    end
end

@testset "Run Perfect Foresight Simulation Tests" begin
    test_data_path = joinpath(@__DIR__, "test_data")
    all_actual_data = NEMStorageUnderUncertainty.get_all_actual_data(
        joinpath(test_data_path, "dispatch_price")
    )
    actual_data = NEMStorageUnderUncertainty.get_ActualData(
        all_actual_data, "NSW1", nothing
    )
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
    results = NEMStorageUnderUncertainty.run_perfect_foresight(
        optimizer_with_attributes(HiGHS.Optimizer),
        storage,
        actual_data,
        NEMStorageUnderUncertainty.StandardArbitrage(),
        NEMStorageUnderUncertainty.NoDegradation();
        silent=true,
    )
    @test unique(results.lookahead_minutes)[] == Dates.value(
        Minute(all_actual_data.SETTLEMENTDATE[end] - all_actual_data.SETTLEMENTDATE[1])
    )
    @test unique(results.decision_time)[] == all_actual_data.SETTLEMENTDATE[1]
    @test typeof(results.relative_gap) == Vector{Float64}
    @test all(0.0 .≤ results.relative_gap .≤ 1.0)
    @testset "Test to JLD2" begin
        @test_throws AssertionError NEMStorageUnderUncertainty.results_to_jld2(
            "test.jld", "test", "perfect", results
        )
        NEMStorageUnderUncertainty.results_to_jld2("test.jld2", "test", "perfect", results)
        @test load("test.jld2", "test/perfect") == results
        rm("test.jld2")
    end
end
