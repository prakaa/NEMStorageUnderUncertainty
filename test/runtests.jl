import Dates: DateTime
import DataFrames: DataFrame
using JuMP: JuMP
using Logging: Logging
using HiGHS: HiGHS
using NEMStorageUnderUncertainty: NEMStorageUnderUncertainty
using Test

@testset "Run Actual Data Tests" begin
    test_data_path = joinpath(@__DIR__, "test_data")
    all_actual_data = NEMStorageUnderUncertainty.get_all_actual_data(
        joinpath(test_data_path, "dispatch_price")
    )
    actual_data = NEMStorageUnderUncertainty.get_ActualData(
        all_actual_data,
        "SA1",
        (DateTime(2021, 12, 5, 12, 0, 0), DateTime(2021, 12, 5, 12, 30, 0)),
    )
    @test all_actual_data.SETTLEMENTDATE[1] == DateTime(2021, 12, 1, 0, 5, 0)
    @test actual_data.times[1] == DateTime(2021, 12, 5, 12, 0, 0)
    @test actual_data.times[end] == DateTime(2021, 12, 5, 12, 30, 0)
end

@testset "Run Forecast Data Tests" begin
    test_data_path = joinpath(@__DIR__, "test_data")
    (pd_df, p5_df) = NEMStorageUnderUncertainty.get_all_pd_and_p5_data(
        joinpath(test_data_path, "forecast_price", "PD"),
        joinpath(test_data_path, "forecast_price", "P5MIN"),
    )
    @test p5_df.run_time[1] == DateTime(2021, 1, 1, 0, 5, 0)
    @test pd_df.run_time[1] == DateTime(2021, 1, 1, 4, 30, 0)
    warning = ("PD and P5 datasets not aligned to the same forecasted times")
    @test_logs (:warn, warning) NEMStorageUnderUncertainty.get_ForecastData(
        pd_df, p5_df, "NSW1", nothing, nothing
    )
    unaligned = NEMStorageUnderUncertainty.get_ForecastData(
        pd_df, p5_df, "NSW1", nothing, nothing
    )
    unaligned_df = convert(DataFrame, unaligned)
    unaligned_times = unique(unaligned_df.actual_run_times)
    @test size(unaligned_df[unaligned_df.actual_run_times .== unaligned_times[1], :], 1) ==
        12
    @test size(
        unaligned_df[unaligned_df.actual_run_times .== unaligned_times[100], :], 1
    ) >= 12
    @testset "Run forecasted time tests" begin
        ftimes = (DateTime(2021, 1, 12, 0, 0, 0), DateTime(2021, 1, 12, 23, 55, 0))
        aligned_ftime = NEMStorageUnderUncertainty.get_ForecastData(
            pd_df, p5_df, "NSW1", nothing, ftimes
        )
        @test aligned_ftime.aligned == true
        aligned_ftime = convert(DataFrame, aligned_ftime)
        @test aligned_ftime.forecasted_times[1] == ftimes[1]
        @test aligned_ftime.forecasted_times[end] == ftimes[end]
    end
    @testset "Run run time tests" begin
        p5_but_no_pd_times = (DateTime(2021, 1, 1, 0, 5, 0), DateTime(2021, 1, 1, 12, 0, 0))
        @test p5_df.run_time[1] == p5_but_no_pd_times[1]
        @test_throws AssertionError NEMStorageUnderUncertainty.get_ForecastData(
            pd_df, p5_df, "NSW1", p5_but_no_pd_times, nothing
        )
        rtimes = (DateTime(2021, 1, 1, 4, 35, 0), DateTime(2021, 1, 1, 12, 0, 0))
        aligned_rtime = NEMStorageUnderUncertainty.get_ForecastData(
            pd_df, p5_df, "NSW1", rtimes, nothing
        )
        @test aligned_rtime.aligned == false
        aligned_rtime = convert(DataFrame, aligned_rtime)
        @test aligned_rtime.actual_run_times[1] == rtimes[1]
        @test aligned_rtime.actual_run_times[end] == rtimes[end]
    end
    @testset "Run imputation checks" begin
        ftimes = (DateTime(2021, 1, 2, 4, 30, 0), DateTime(2021, 1, 5, 12, 0, 0))
        @test_logs (min_level = Logging.Warn) NEMStorageUnderUncertainty.get_ForecastData(
            pd_df, p5_df, "NSW1", nothing, ftimes
        )
        data = convert(
            DataFrame,
            NEMStorageUnderUncertainty.get_ForecastData(
                pd_df, p5_df, "NSW1", nothing, ftimes
            ),
        )
        rtimes = unique(data[!, :actual_run_times])
        random_rtime = rtimes[rand(1:288)]
        data_subset = data[data.actual_run_times .== random_rtime, :]
        @show data_subset[1, :actual_run_times]
        if hour(random_rtime) >= 13
            end_date = DateTime(2021, 1, day(random_rtime) + 2, 4, 0, 0)
        else
            end_date = DateTime(2021, 1, day(random_rtime) + 1, 4, 0, 0)
        end
        @test data_subset[end, :forecasted_times] == end_date
        times = (random_rtime + Minute(5)):Minute(5):end_date
        @test times == unique(data_subset.forecasted_times)
    end
end

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
    actual_data = NEMStorageUnderUncertainty.get_all_actual_data(actual_price_data_path)
    actual = NEMStorageUnderUncertainty.get_ActualData(
        actual_data, "NSW1", (start_time, end_time)
    )
    model = NEMStorageUnderUncertainty._run_model(
        HiGHS.Optimizer,
        bess,
        actual.prices,
        actual.times,
        actual.τ,
        NEMStorageUnderUncertainty.StandardArbitrage(),
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
    @test JuMP.num_constraints(interval_model; count_variable_in_set_constraints=false) == 3
end
