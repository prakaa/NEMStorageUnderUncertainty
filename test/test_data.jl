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
        joinpath(test_data_path, "forecast_price", "PREDISPATCH"),
        joinpath(test_data_path, "forecast_price", "P5MIN"),
    )
    @test p5_df.run_time[1] == DateTime(2021, 1, 1, 0, 5, 0)
    @test pd_df.run_time[1] == DateTime(2021, 1, 1, 4, 30, 0)
    warning = ("PD and P5 datasets not aligned to the same run times")
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
        ftime_filter = NEMStorageUnderUncertainty.get_ForecastData(
            pd_df, p5_df, "NSW1", nothing, ftimes
        )
        @test ftime_filter.run_time_aligned == false
        ftime_filter = convert(DataFrame, ftime_filter)
        @test ftime_filter.forecasted_times[1] == ftimes[1]
        @test ftime_filter.forecasted_times[end] == ftimes[end]
    end

    @testset "Run run time tests" begin
        p5_but_no_pd_times = (DateTime(2021, 1, 1, 0, 5, 0), DateTime(2021, 1, 1, 12, 0, 0))
        @test p5_df.run_time[1] == p5_but_no_pd_times[1]
        @test_throws AssertionError NEMStorageUnderUncertainty.get_ForecastData(
            pd_df, p5_df, "NSW1", p5_but_no_pd_times, nothing
        )
        rtimes = (DateTime(2021, 1, 1, 4, 35, 0), DateTime(2021, 1, 1, 12, 0, 0))
        filter_rtime = NEMStorageUnderUncertainty.get_ForecastData(
            pd_df, p5_df, "NSW1", rtimes, nothing
        )
        @test filter_rtime.run_time_aligned == true
        filter_rtime = convert(DataFrame, filter_rtime)
        @test filter_rtime.actual_run_times[1] == rtimes[1]
        @test filter_rtime.actual_run_times[end] == rtimes[end]
    end

    @testset "Run imputation checks" begin
        @testset "Run imputation with forecasted times" begin
            ftimes = (DateTime(2021, 1, 2, 4, 30, 0), DateTime(2021, 1, 5, 12, 0, 0))
            @test_logs (:warn, warning) NEMStorageUnderUncertainty.get_ForecastData(
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
            if hour(random_rtime) > 12 ||
                (hour(random_rtime) == 12 && minute(random_rtime) >= 30)
                end_date = DateTime(2021, 1, day(random_rtime) + 2, 4, 0, 0)
            else
                end_date = DateTime(2021, 1, day(random_rtime) + 1, 4, 0, 0)
            end
            @test data_subset[end, :forecasted_times] == end_date
            start_time = maximum([ftimes[1], random_rtime + Minute(5)])
            times = Vector(start_time:Minute(5):end_date)
            @test times == unique(data_subset.forecasted_times)
        end
        @testset "Run imputation with run times" begin
            rtimes = (DateTime(2021, 1, 1, 4, 30, 0), DateTime(2021, 1, 1, 12, 00, 0))
            @test_logs (min_level = Logging.Warn) NEMStorageUnderUncertainty.get_ForecastData(
                pd_df, p5_df, "NSW1", rtimes, nothing
            )
            data = convert(
                DataFrame,
                NEMStorageUnderUncertainty.get_ForecastData(
                    pd_df, p5_df, "NSW1", rtimes, nothing
                ),
            )
            ftimes = unique(data.forecasted_times)
            @test Vector((rtimes[1] + Minute(5)):Minute(5):DateTime(2021, 1, 2, 4, 0, 0)) == ftimes
        end
    end
end
