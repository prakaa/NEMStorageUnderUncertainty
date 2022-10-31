using NEMStorageUnderUncertainty: NEMStorageUnderUncertainty
using Dates
using DataFrames
using Logging
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
        if hour(random_rtime) >= 13
            end_date = DateTime(2021, 1, day(random_rtime) + 2, 4, 0, 0)
        else
            end_date = DateTime(2021, 1, day(random_rtime) + 1, 4, 0, 0)
        end
        @test data_subset[end, :forecasted_times] == end_date
        start_time = maximum([ftimes[1], random_rtime + Minute(5)])
        times = Vector(start_time:Minute(5):end_date)
        @test times == unique(data_subset.forecasted_times)
    end
end
