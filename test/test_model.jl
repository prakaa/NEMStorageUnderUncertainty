import Dates: DateTime, Minute
using NEMStorageUnderUncertainty: NEMStorageUnderUncertainty
using HiGHS
using JuMP
using Test

function test_run_model(
    storage::NEMStorageUnderUncertainty.StorageDevice,
    data_path::String,
    start_time::DateTime,
    end_time::DateTime,
    binding_end_time::DateTime,
    formulation::NEMStorageUnderUncertainty.StorageModelFormulation;
    time_limit_sec::Union{Float64,Nothing}=nothing,
)
    actual_price_data_path = joinpath(data_path, "dispatch_price")
    actual_data = NEMStorageUnderUncertainty.get_all_actual_data(actual_price_data_path)
    actual = NEMStorageUnderUncertainty.get_ActualData(
        actual_data, "NSW1", (start_time, end_time)
    )
    model = NEMStorageUnderUncertainty.run_model(
        optimizer_with_attributes(HiGHS.Optimizer),
        storage,
        actual.prices,
        actual.times,
        binding_end_time,
        actual.τ,
        formulation,
        NEMStorageUnderUncertainty.NoDegradation();
        time_limit_sec=time_limit_sec,
    )
    if typeof(formulation) == NEMStorageUnderUncertainty.ArbitrageCapContracted
        return (model, actual)
    else
        return model
    end
end

@testset "Run Model Tests" begin
    test_data_path = joinpath(@__DIR__, "test_data")
    bess = NEMStorageUnderUncertainty.BESS(;
        power_capacity=30.0,
        energy_capacity=30.0,
        soc_min=0.1 * 30.0,
        soc_max=0.9 * 30.0,
        η_charge=0.9,
        η_discharge=0.9,
        soc₀=0.5 * 30.0,
        throughput=50.0,
    )
    test_times = DateTime(2021, 12, 1, 0, 5, 0), DateTime(2022, 1, 1, 0, 0, 0)
    test_interval_times = DateTime(2021, 12, 1, 0, 5, 0), DateTime(2021, 12, 1, 0, 5, 0)
    test_day_times = DateTime(2021, 12, 21, 0, 5, 0), DateTime(2021, 12, 22, 0, 5, 0)
    @testset "Test StandardArbitrage" begin
        formulation = NEMStorageUnderUncertainty.StandardArbitrage()
        month_model = test_run_model(
            bess, test_data_path, test_times[1], test_times[2], test_times[1], formulation
        )
        @test isapprox(JuMP.objective_value(month_model), 171697, atol=0.5)
        interval_model = test_run_model(
            bess,
            test_data_path,
            test_interval_times[1],
            test_interval_times[2],
            test_interval_times[2],
            formulation,
        )
        @test JuMP.num_constraints(
            interval_model; count_variable_in_set_constraints=false
        ) == 4
        @test_logs (
            :warn,
            (
                "Model run between 2021-12-01T00:05:00 and 2022-01-01T00:00:00 hit " *
                "iteration/time limit"
            ),
        ) test_run_model(
            bess,
            test_data_path,
            test_times[1],
            test_times[2],
            test_times[1],
            formulation;
            time_limit_sec=0.01,
        )
    end
    @testset "Test Throughput Limits" begin
        formulation = NEMStorageUnderUncertainty.StandardArbitrageThroughputLimit(
            bess.energy_capacity * 365
        )
        test_day_tp_times = DateTime(2021, 12, 1, 0, 5, 0), DateTime(2021, 12, 2, 0, 5, 0)
        day_model = test_run_model(
            bess,
            test_data_path,
            test_day_tp_times[1],
            test_day_tp_times[2],
            test_day_tp_times[1] + Minute(10),
            formulation,
        )
        con_ref = JuMP.constraint_by_name(day_model, "throughput_limit")
        binding_con_ref = JuMP.constraint_by_name(day_model, "binding_throughput_limit")
        @test isapprox(
            normalized_rhs(binding_con_ref),
            bess.throughput +
            formulation.throughput_mwh_per_year * (Minute(15) / Minute(60 * 24 * 365)),
        )
        @test isapprox(
            normalized_rhs(con_ref),
            bess.energy_capacity * (1.0 + 1.0 / 288.0) + bess.throughput,
        )
        @test value(day_model[:throughput_mwh][end]) ≤
            (bess.energy_capacity * bess.throughput)
        throughputs = Vector(JuMP.value.(day_model[:throughput_mwh]))
        discharges = Vector(JuMP.value.(day_model[:discharge_mw]))
        discharge_index = rand(findall(x -> x > 0, discharges))
        discharge_index = discharge_index[discharge_index .> 1]
        @test throughputs[discharge_index] ==
            throughputs[discharge_index - 1] + discharges[discharge_index] * (5.0 / 60.0)
        interval_model = test_run_model(
            bess,
            test_data_path,
            test_interval_times[1],
            test_interval_times[2],
            test_interval_times[2],
            formulation,
        )
        con_ref = JuMP.constraint_by_name(interval_model, "throughput_limit")
        @test isapprox(
            normalized_rhs(con_ref), (bess.energy_capacity / 288) + bess.throughput
        )
        @test JuMP.num_constraints(
            interval_model; count_variable_in_set_constraints=false
        ) == 5
        @test value.(interval_model[:throughput_mwh])[test_interval_times[1]] ==
            bess.throughput +
              value.(interval_model[:discharge_mw])[test_interval_times[1]] * (5.0 / 60.0)
    end

    @testset "Test Throughput Penalty" begin
        tp_lim = bess.energy_capacity * 365.0 * 10
        cap_cost_per_mwh = 1000.0 * 1000.0
        formulation = NEMStorageUnderUncertainty.ArbitrageThroughputPenalty(
            tp_lim, cap_cost_per_mwh
        )
        day_model = test_run_model(
            bess,
            test_data_path,
            test_day_times[1],
            test_day_times[2],
            test_day_times[1],
            formulation,
        )
        vals = Dict()
        discharge_mw = day_model[:discharge_mw]
        charge_mw = day_model[:charge_mw]
        throughput_mwh = day_model[:throughput_mwh]
        for t in test_day_times[1]:Minute(5):test_day_times[2]
            vals[discharge_mw[t]] = 0.0
            vals[charge_mw[t]] = 0.0
        end
        vals[throughput_mwh[test_day_times[2]]] = bess.throughput + 10.0
        objval = value(z -> vals[z], JuMP.objective_function(day_model))
        @test isapprox(objval, (-10.0 / tp_lim * bess.energy_capacity * cap_cost_per_mwh))
        vals = Dict()
        interval_model = test_run_model(
            bess,
            test_data_path,
            test_interval_times[1],
            test_interval_times[2],
            test_interval_times[2],
            formulation,
        )
        discharge_mw = interval_model[:discharge_mw]
        charge_mw = interval_model[:charge_mw]
        throughput_mwh = interval_model[:throughput_mwh]
        for t in test_interval_times[1]:Minute(5):test_interval_times[2]
            vals[discharge_mw[t]] = 0.0
            vals[charge_mw[t]] = 0.0
        end
        vals[throughput_mwh[test_interval_times[2]]] = bess.throughput + 10.0
        objval = value(z -> vals[z], JuMP.objective_function(interval_model))
        @test isapprox(objval, (-10.0 / tp_lim * bess.energy_capacity * cap_cost_per_mwh))
    end

    @testset "Test Cap Contracted" begin
        tp_lim = bess.energy_capacity * 365.0 * 10
        cap_cost_per_mwh = 1000.0 * 1000.0
        cap_contract_mw = bess.energy_capacity * 0.5
        formulation = NEMStorageUnderUncertainty.ArbitrageCapContracted(
            tp_lim, cap_cost_per_mwh, cap_contract_mw
        )
        day_model, day_actual = test_run_model(
            bess,
            test_data_path,
            test_day_times[1],
            test_day_times[2],
            test_day_times[1],
            formulation,
        )
        vals = Dict()
        discharge_mw = day_model[:discharge_mw]
        charge_mw = day_model[:charge_mw]
        throughput_mwh = day_model[:throughput_mwh]
        for t in test_day_times[1]:Minute(5):test_day_times[2]
            vals[discharge_mw[t]] = 0.0
            vals[charge_mw[t]] = 0.0
        end
        vals[throughput_mwh[test_day_times[2]]] = bess.throughput + 10.0
        cap_loss = sum(
            @. day_actual.τ *
                (day_actual.prices > 300.0) *
                cap_contract_mw *
                (day_actual.prices - 300.0)
        )
        @test cap_loss > 0.0
        objval = value(z -> vals[z], JuMP.objective_function(day_model))
        @test isapprox(
            objval, (-10.0 / tp_lim * bess.energy_capacity * cap_cost_per_mwh - cap_loss)
        )
        interval_model, interval_actual = test_run_model(
            bess,
            test_data_path,
            test_interval_times[1],
            test_interval_times[2],
            test_interval_times[2],
            formulation,
        )
        vals = Dict()
        discharge_mw = interval_model[:discharge_mw]
        charge_mw = interval_model[:charge_mw]
        throughput_mwh = interval_model[:throughput_mwh]
        cap_loss = sum(
            @. interval_actual.τ *
                (interval_actual.prices > 300.0) *
                cap_contract_mw *
                (interval_actual.prices - 300.0)
        )
        for t in test_interval_times[1]:Minute(5):test_interval_times[2]
            vals[discharge_mw[t]] = 0.0
            vals[charge_mw[t]] = 0.0
        end
        vals[throughput_mwh[test_interval_times[2]]] = bess.throughput + 10.0
        objval = value(z -> vals[z], JuMP.objective_function(interval_model))
        @test isapprox(
            objval, (-10.0 / tp_lim * bess.energy_capacity * cap_cost_per_mwh) - cap_loss
        )
    end
end
