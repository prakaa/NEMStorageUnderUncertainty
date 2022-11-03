var documenterSearchIndex = {"docs":
[{"location":"formulations/#Model-Formulations","page":"Model Formulations","title":"Model Formulations","text":"","category":"section"},{"location":"formulations/","page":"Model Formulations","title":"Model Formulations","text":"Modules = [NEMStorageUnderUncertainty]\nPages = [\"model/formulations.jl\"]","category":"page"},{"location":"formulations/#NEMStorageUnderUncertainty.DegradationModel","page":"Model Formulations","title":"NEMStorageUnderUncertainty.DegradationModel","text":"abstract type DegradationModel <: NEMStorageUnderUncertainty.Formulation\n\n\n\n\n\n","category":"type"},{"location":"formulations/#NEMStorageUnderUncertainty.NoDegradation","page":"Model Formulations","title":"NEMStorageUnderUncertainty.NoDegradation","text":"struct NoDegradation <: NEMStorageUnderUncertainty.DegradationModel\n\nNo storage degradation modelled in simulations.\n\n\n\n\n\n","category":"type"},{"location":"formulations/#NEMStorageUnderUncertainty.StandardArbitrage","page":"Model Formulations","title":"NEMStorageUnderUncertainty.StandardArbitrage","text":"struct StandardArbitrage <: NEMStorageUnderUncertainty.StorageModelFormulation\n\nSummary\n\nMaximises storage revenue:\n\nAll periods are treated (weighted) equally\nNo cycling/throughput limits are modelled\nRevenue is purely defined by the spot price for energy\nIntertemporal SoC constraints are applied, including from soc₀ to soc₁\n\nbeginaligned\n  max_t quad  sum_t=1^Ttaulambda_t(p_t-q_t)\n  textrmst quad  u_t in 01    \n   p_t geq 0 \n   q_t geq 0 \n   p_t - barpleft(1-u_tright) leq 0\n   q_t - barpu_t leq 0\n   underlinee leq e_t leq bare    \n   e_t-e_t-1- left( q_teta_chargetauright)+fracp_ttaueta_discharge = 0\n   e_1 - e_0 - left( q_1eta_chargetauright)+fracp_1taueta_discharge = 0\nendaligned\n\n\n\n\n\n","category":"type"},{"location":"formulations/#NEMStorageUnderUncertainty.StandardArbitrageThroughputLimit","page":"Model Formulations","title":"NEMStorageUnderUncertainty.StandardArbitrageThroughputLimit","text":"struct StandardArbitrageThroughputLimit <: NEMStorageUnderUncertainty.StorageModelFormulation\n\nthroughput_mwh_per_year::Float64\n\nSummary\n\nMaximises storage revenue:\n\nAll periods are treated (weighted) equally\nA throughput limit is modelled, with an annual throughput limit specified\nEach simulation includes this limit applied on a pro rata basis\ni.e. d_max for a simulation period is that period's proportion of a year\nRevenue is purely defined by the spot price for energy\nIntertemporal SoC constraints are applied, including from soc₀ to soc₁\n\nbeginaligned\n  max_t quad  sum_t=1^Ttaulambda_t(p_t-q_t)\n  textrmst quad  u_t in 01    \n   p_t geq 0 \n   q_t geq 0 \n   p_t - barpleft(1-u_tright) leq 0\n   q_t - barpu_t leq 0\n   underlinee leq e_t leq bare    \n   e_t-e_t-1- left( q_teta_chargetauright)+fracp_ttaueta_discharge = 0\n   e_1 - e_0 - left( q_1eta_chargetauright)+fracp_1taueta_discharge = 0\n   d_t-d_t-1 - p_ttau = 0\n   d_1 - d_0 - p_1tau = 0\n   d_end  d_max\nendaligned\n\n\n\n\n\n","category":"type"},{"location":"formulations/#NEMStorageUnderUncertainty.StorageModelFormulation","page":"Model Formulations","title":"NEMStorageUnderUncertainty.StorageModelFormulation","text":"abstract type StorageModelFormulation <: NEMStorageUnderUncertainty.Formulation\n\n\n\n\n\n","category":"type"},{"location":"formulations/#NEMStorageUnderUncertainty._initialise_model-Tuple{}","page":"Model Formulations","title":"NEMStorageUnderUncertainty._initialise_model","text":"_initialise_model(\n;\n    silent,\n    time_limit_sec,\n    string_names\n) -> JuMP.Model\n\n\nSummary\n\nArguments\n\nsilent: Default false. If true, turn off JuMP/solver output\ntime_limit_sec: Default nothing. Number of seconds before solver times out.\nstring_names: Default true. If false, disables JuMP string names, which can improve speed/performance.\n\nReturns\n\nA JuMP model\n\nMethods\n\n_initialise_model(; silent, time_limit_sec, string_names)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/model/formulations.jl:78.\n\n\n\n\n\n","category":"method"},{"location":"formulations/#Model-Components","page":"Model Formulations","title":"Model Components","text":"","category":"section"},{"location":"formulations/","page":"Model Formulations","title":"Model Formulations","text":"Variables\nConstraints\nObjectives","category":"page"},{"location":"simulations/#Simulations","page":"Simulations","title":"Simulations","text":"","category":"section"},{"location":"simulations/","page":"Simulations","title":"Simulations","text":"Modules = [NEMStorageUnderUncertainty]\nPages = [\"simulations.jl\"]","category":"page"},{"location":"simulations/#NEMStorageUnderUncertainty._get_periods_for_simulation-Union{Tuple{T}, Tuple{Dates.DateTime, Dates.DateTime, T, T, NEMStorageUnderUncertainty.ActualData}} where T<:Dates.Period","page":"Simulations","title":"NEMStorageUnderUncertainty._get_periods_for_simulation","text":"_get_periods_for_simulation(\n    decision_start_time::Dates.DateTime,\n    decision_end_time::Dates.DateTime,\n    binding::Dates.Period,\n    horizon::Dates.Period,\n    data::NEMStorageUnderUncertainty.ActualData\n) -> DataFrames.DataFrame\n\n\nSummary\n\nGets decision points, binding intervals and horizon ends given ActualData and simulation parameters.\n\nArguments\n\ndecision_start_time: Decision start time.\ndecision_end_time: Decision end time.\nbinding: decision_time + binding gives the last binding period\nhorizon: decision_time + horizon gives the end of the simulation horizon\ndata: ActualData\n\nReturns\n\nDataFrame with the following columns:\n\ndecision_interval: data.times indices that correspond to decision points\nbinding_start: data.times indices that correspond to the first binding period for each simulation.\nbinding_end: data.times indices that correspond to the last binding period for each simulation.\nhorizon_end: data.times indices that correspond to the horizon end for each simulation\n\nMethods\n\n_get_periods_for_simulation(\n    decision_start_time,\n    decision_end_time,\n    binding,\n    horizon,\n    data\n)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/simulations.jl:26.\n\n\n\n\n\n","category":"method"},{"location":"simulations/#NEMStorageUnderUncertainty._get_periods_for_simulation-Union{Tuple{T}, Tuple{Dates.DateTime, Dates.DateTime, T, T, NEMStorageUnderUncertainty.ForecastData}} where T<:Dates.Period","page":"Simulations","title":"NEMStorageUnderUncertainty._get_periods_for_simulation","text":"_get_periods_for_simulation(\n    decision_start_time::Dates.DateTime,\n    decision_end_time::Dates.DateTime,\n    binding::Dates.Period,\n    horizon::Dates.Period,\n    data::NEMStorageUnderUncertainty.ForecastData\n) -> DataFrames.DataFrame\n\n\nSummary\n\nGets decision points, binding intervals and horizon ends given ForecastData and simulation parameters.\n\nArguments\n\ndecision_start_time: Decision start time. Applies to run_time\ndecision_end_time: Decision end time. Applies to run_time\nbinding: decision_time + binding gives the last binding period. Applies to forecasted_time\nhorizon: decision_time + horizon gives the end of the simulation horizon. Applies to forecasted_time\ndata: ForecastData\n\nReturns\n\nDataFrame with the following columns:\n\ndecision_interval: data.times indices that correspond to run_time decision points\nbinding_start: data.times indices that correspond to the first binding period for each simulation. Applies to forecasted_time.\nbinding_end: data.times indices that correspond to the last binding period for each simulation. Applies to forecasted_time\nhorizon_end: data.times indices that correspond to the horizon end for each simulation. Applies to forecasted_time\n\nMethods\n\n_get_periods_for_simulation(\n    decision_start_time,\n    decision_end_time,\n    binding,\n    horizon,\n    data\n)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/simulations.jl:116.\n\n\n\n\n\n","category":"method"},{"location":"simulations/#NEMStorageUnderUncertainty._update_storage_state-Tuple{NEMStorageUnderUncertainty.StorageDevice, DataFrames.DataFrame, Float64, NEMStorageUnderUncertainty.NoDegradation}","page":"Simulations","title":"NEMStorageUnderUncertainty._update_storage_state","text":"_update_storage_state(\n    storage::NEMStorageUnderUncertainty.StorageDevice,\n    binding_results::DataFrames.DataFrame,\n    τ::Float64,\n    _::NEMStorageUnderUncertainty.NoDegradation\n) -> Any\n\n\nSummary\n\n\"Updates\" (via new StorageDevice) storage state between model runs. Specifically:\n\nUpdates soc₀ to reflect soc at end of binding decisions from last model run\nUpdates storage throughput based on model run\nthroughput is defined as discharged energy, and hence does not consider η_discharge\n\nArguments\n\nstorage: StorageDevice\nbinding_results: Binding results from last model run\nτ: Interval duration in hours\ndegradation: No degradation model NoDegradation\n\nReturns\n\nNew StorageDevice with updated soc₀ and throughput\n\nMethods\n\n_update_storage_state(storage, binding_results, τ, _)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/simulations.jl:258.\n\n\n\n\n\n","category":"method"},{"location":"variables/#Variables","page":"Variables","title":"Variables","text":"","category":"section"},{"location":"variables/","page":"Variables","title":"Variables","text":"Modules = [NEMStorageUnderUncertainty]\nPages = [\"model/variables.jl\"]","category":"page"},{"location":"variables/#NEMStorageUnderUncertainty._add_variable_charge_state!-Tuple{JuMP.Model, Vector{Dates.DateTime}}","page":"Variables","title":"NEMStorageUnderUncertainty._add_variable_charge_state!","text":"_add_variable_charge_state!(\n    model::JuMP.Model,\n    times::Vector{Dates.DateTime}\n) -> JuMP.Containers.DenseAxisArray{JuMP.VariableRef, 1, Tuple{Vector{Dates.DateTime}}, Tuple{JuMP.Containers._AxisLookup{Dict{Dates.DateTime, Int64}}}}\n\n\nSummary\n\nAdds binary variable that indicates charging (i.e. u_t=1) when charging.\n\nArguments\n\nmodel: JuMP model\ntimes: A Vector of DateTimes\n\nMethods\n\n_add_variable_charge_state!(model, times)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/model/variables.jl:55.\n\n\n\n\n\n","category":"method"},{"location":"variables/#NEMStorageUnderUncertainty._add_variable_soc!-Tuple{JuMP.Model, NEMStorageUnderUncertainty.StorageDevice, Vector{Dates.DateTime}}","page":"Variables","title":"NEMStorageUnderUncertainty._add_variable_soc!","text":"_add_variable_soc!(\n    model::JuMP.Model,\n    storage::NEMStorageUnderUncertainty.StorageDevice,\n    times::Vector{Dates.DateTime}\n) -> JuMP.Containers.DenseAxisArray\n\n\nSummary\n\nAdds variable that tracks state-of-charge (SoC, e_t).\n\nThe following variable bound is applied: underlinee leq e_t leq bare, where the limits represent the lower and upper SoC limits obtained from storage.\n\nArguments\n\nmodel: JuMP model\nstorage: A StorageDevice\ntimes: A Vector of DateTimes\n\nMethods\n\n_add_variable_soc!(model, storage, times)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/model/variables.jl:39.\n\n\n\n\n\n","category":"method"},{"location":"variables/#NEMStorageUnderUncertainty._add_variable_throughput!-Tuple{JuMP.Model, NEMStorageUnderUncertainty.StorageDevice, Vector{Dates.DateTime}}","page":"Variables","title":"NEMStorageUnderUncertainty._add_variable_throughput!","text":"_add_variable_throughput!(\n    model::JuMP.Model,\n    storage::NEMStorageUnderUncertainty.StorageDevice,\n    times::Vector{Dates.DateTime}\n) -> JuMP.Containers.DenseAxisArray\n\n\nSummary\n\nAdds variable that tracks throughput in MWh (d_t).\n\nThe following variable bound is applied: d_0 leq d_t, where the limit represents the initial throughput obtained from storage.\n\nArguments\n\nmodel: JuMP model\nstorage: A StorageDevice\ntimes: A Vector of DateTimes\n\nMethods\n\n_add_variable_throughput!(model, storage, times)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/model/variables.jl:72.\n\n\n\n\n\n","category":"method"},{"location":"variables/#NEMStorageUnderUncertainty._add_variables_power!-Tuple{JuMP.Model, NEMStorageUnderUncertainty.StorageDevice, Vector{Dates.DateTime}}","page":"Variables","title":"NEMStorageUnderUncertainty._add_variables_power!","text":"_add_variables_power!(\n    model::JuMP.Model,\n    storage::NEMStorageUnderUncertainty.StorageDevice,\n    times::Vector{Dates.DateTime}\n) -> Tuple{JuMP.Containers.DenseAxisArray, JuMP.Containers.DenseAxisArray}\n\n\nSummary\n\nAdds variables for charging in MW (q_t) and discharging in MW (p_t).\n\nThe following variable bounds are applied:\n\n0 leq p_t leq barp\n0 leq q_t leq barp\n\nArguments\n\nmodel: JuMP model\nstorage: A StorageDevice\ntimes: A Vector of DateTimes\n\nMethods\n\n_add_variables_power!(model, storage, times)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/model/variables.jl:14.\n\n\n\n\n\n","category":"method"},{"location":"constraints/#Constraints","page":"Constraints","title":"Constraints","text":"","category":"section"},{"location":"constraints/","page":"Constraints","title":"Constraints","text":"Modules = [NEMStorageUnderUncertainty]\nPages = [\"model/constraints.jl\"]","category":"page"},{"location":"constraints/#NEMStorageUnderUncertainty._add_constraint_initial_soc!-Tuple{JuMP.Model, NEMStorageUnderUncertainty.StorageDevice, Vector{Dates.DateTime}, Float64}","page":"Constraints","title":"NEMStorageUnderUncertainty._add_constraint_initial_soc!","text":"_add_constraint_initial_soc!(\n    model::JuMP.Model,\n    storage::NEMStorageUnderUncertainty.StorageDevice,\n    times::Vector{Dates.DateTime},\n    τ::Float64\n) -> JuMP.ConstraintRef{JuMP.Model}\n\n\nSummary\n\nAdds the following constraint to model:\n\ne_1 - e_0 - left( q_1eta_chargetauright)+fracp_1taueta_discharge = 0\n\nwhere e_0 and eta are obtained from storage.\n\nArguments\n\nmodel: JuMP model\nstorage: A StorageDevice\ntimes: A Vector of DateTimes\ntau: Interval length in hours\n\nMethods\n\n_add_constraint_initial_soc!(model, storage, times, τ)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/model/constraints.jl:43.\n\n\n\n\n\n","category":"method"},{"location":"constraints/#NEMStorageUnderUncertainty._add_constraint_initial_throughput!-Tuple{JuMP.Model, NEMStorageUnderUncertainty.StorageDevice, Vector{Dates.DateTime}, Float64}","page":"Constraints","title":"NEMStorageUnderUncertainty._add_constraint_initial_throughput!","text":"_add_constraint_initial_throughput!(\n    model::JuMP.Model,\n    storage::NEMStorageUnderUncertainty.StorageDevice,\n    times::Vector{Dates.DateTime},\n    τ::Float64\n) -> JuMP.ConstraintRef{JuMP.Model}\n\n\nSummary\n\nAdds the following constraint to model:\n\nd_1 - d_0 - p_1tau = 0\n\nwhere d_0 is obtained from storage.\n\nArguments\n\nmodel: JuMP model\nstorage: A StorageDevice\ntimes: A Vector of DateTimes\ntau: Interval length in hours\n\nMethods\n\n_add_constraint_initial_throughput!(\n    model,\n    storage,\n    times,\n    τ\n)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/model/constraints.jl:115.\n\n\n\n\n\n","category":"method"},{"location":"constraints/#NEMStorageUnderUncertainty._add_constraint_intertemporal_soc!-Tuple{JuMP.Model, NEMStorageUnderUncertainty.StorageDevice, Vector{Dates.DateTime}, Float64}","page":"Constraints","title":"NEMStorageUnderUncertainty._add_constraint_intertemporal_soc!","text":"_add_constraint_intertemporal_soc!(\n    model::JuMP.Model,\n    storage::NEMStorageUnderUncertainty.StorageDevice,\n    times::Vector{Dates.DateTime},\n    τ::Float64\n) -> JuMP.Containers.DenseAxisArray\n\n\nSummary\n\nAdds the following constraint to model if times has length ≥ 2:\n\ne_t-e_t-1- left( q_teta_chargetauright)+fracp_ttaueta_discharge = 0\n\neta are obtained from storage.\n\nArguments\n\nmodel: JuMP model\nstorage: A StorageDevice\ntimes: A Vector of DateTimes\ntau: Interval length in hours\n\nMethods\n\n_add_constraint_intertemporal_soc!(model, storage, times, τ)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/model/constraints.jl:76.\n\n\n\n\n\n","category":"method"},{"location":"constraints/#NEMStorageUnderUncertainty._add_constraint_intertemporal_throughput!-Tuple{JuMP.Model, Vector{Dates.DateTime}, Float64}","page":"Constraints","title":"NEMStorageUnderUncertainty._add_constraint_intertemporal_throughput!","text":"_add_constraint_intertemporal_throughput!(\n    model::JuMP.Model,\n    times::Vector{Dates.DateTime},\n    τ::Float64\n) -> JuMP.Containers.DenseAxisArray\n\n\nSummary\n\nAdds the following constraint to model if times has length ≥ 2:\n\nd_t-d_t-1 - p_ttau = 0\n\nArguments\n\nmodel: JuMP model\ntimes: A Vector of DateTimes\ntau: Interval length in hours\n\nMethods\n\n_add_constraint_intertemporal_throughput!(model, times, τ)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/model/constraints.jl:141.\n\n\n\n\n\n","category":"method"},{"location":"constraints/#NEMStorageUnderUncertainty._add_constraint_throughput_limit!-Tuple{JuMP.Model, Vector{Dates.DateTime}, Float64}","page":"Constraints","title":"NEMStorageUnderUncertainty._add_constraint_throughput_limit!","text":"_add_constraint_throughput_limit!(\n    model::JuMP.Model,\n    times::Vector{Dates.DateTime},\n    d_max::Float64\n) -> JuMP.ConstraintRef{JuMP.Model}\n\n\nSummary\n\nAdds the following constraint to model:\n\nd_end  d_max\n\nwhere d_max is supplied\n\nArguments\n\nmodel: JuMP model\ntimes: A Vector of DateTimes\nd_max: Throughput limit in MWh, applicable at the end of times\n\nMethods\n\n_add_constraint_throughput_limit!(model, times, d_max)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/model/constraints.jl:174.\n\n\n\n\n\n","category":"method"},{"location":"constraints/#NEMStorageUnderUncertainty._add_constraints_charge_state!-Tuple{JuMP.Model, NEMStorageUnderUncertainty.StorageDevice, Vector{Dates.DateTime}}","page":"Constraints","title":"NEMStorageUnderUncertainty._add_constraints_charge_state!","text":"_add_constraints_charge_state!(\n    model::JuMP.Model,\n    storage::NEMStorageUnderUncertainty.StorageDevice,\n    times::Vector{Dates.DateTime}\n) -> Tuple{JuMP.Containers.DenseAxisArray, JuMP.Containers.DenseAxisArray}\n\n\nSummary\n\nAdds two constraints to model:\n\np_t - barpleft(1-u_tright) leq 0\nq_t - barpu_t leq 0\n\nArguments\n\nmodel: JuMP model\nstorage: A StorageDevice\ntimes: A Vector of DateTimes\n\nMethods\n\n_add_constraints_charge_state!(model, storage, times)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/model/constraints.jl:12.\n\n\n\n\n\n","category":"method"},{"location":"devices/#Storage-Devices","page":"Storage Devices","title":"Storage Devices","text":"","category":"section"},{"location":"devices/","page":"Storage Devices","title":"Storage Devices","text":"Modules = [NEMStorageUnderUncertainty]\nPages = [\"devices.jl\"]","category":"page"},{"location":"devices/#NEMStorageUnderUncertainty.BESS","page":"Storage Devices","title":"NEMStorageUnderUncertainty.BESS","text":"BESS(\n    power_capacity::Float64,\n    energy_capacity::Float64,\n    soc_min::Float64,\n    soc_max::Float64,\n    η_charge::Float64,\n    η_discharge::Float64,\n    soc₀::Float64\n)\nBESS(\n    power_capacity::Float64,\n    energy_capacity::Float64,\n    soc_min::Float64,\n    soc_max::Float64,\n    η_charge::Float64,\n    η_discharge::Float64,\n    soc₀::Float64,\n    throughput::Float64\n) -> BESS\n\n\nSummary\n\nInitialises a battery energy storage system (BESS).\n\nthroughput (in MWh) can be supplied in cases where the BESS has already undertaken energy storage and discharge. This is akin to cycling but is independent of storage capacity (significant where calendar and/or cycling degradation is accounted for). If not supplied, default value is 0.0.\n\nReturns\n\nA BESS\n\nMethods\n\nBESS(\n    power_capacity,\n    energy_capacity,\n    soc_min,\n    soc_max,\n    η_charge,\n    η_discharge,\n    soc₀\n)\nBESS(\n    power_capacity,\n    energy_capacity,\n    soc_min,\n    soc_max,\n    η_charge,\n    η_discharge,\n    soc₀,\n    throughput\n)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/devices.jl:43.\n\n\n\n\n\n","category":"type"},{"location":"devices/#NEMStorageUnderUncertainty.StorageDevice","page":"Storage Devices","title":"NEMStorageUnderUncertainty.StorageDevice","text":"abstract type StorageDevice\n\n\n\n\n\n","category":"type"},{"location":"data/#Price-Data-Compilers","page":"Price Data Compilers","title":"Price Data Compilers","text":"","category":"section"},{"location":"data/","page":"Price Data Compilers","title":"Price Data Compilers","text":"Modules = [NEMStorageUnderUncertainty]\nPages = [\"data.jl\"]","category":"page"},{"location":"data/#NEMStorageUnderUncertainty.ActualData","page":"Price Data Compilers","title":"NEMStorageUnderUncertainty.ActualData","text":"struct ActualData{T<:AbstractFloat} <: NEMStorageUnderUncertainty.NEMData\n\nregion::String\ntimes::Vector{Dates.DateTime}\nprices::Vector{T} where T<:AbstractFloat\nτ::AbstractFloat\n\nA data structure used to store actual price data and metadata\n\n\n\n\n\n","category":"type"},{"location":"data/#NEMStorageUnderUncertainty.ForecastData","page":"Price Data Compilers","title":"NEMStorageUnderUncertainty.ForecastData","text":"struct ForecastData{T<:AbstractFloat} <: NEMStorageUnderUncertainty.NEMData\n\nregion::String\nrun_times::Vector{Dates.DateTime}\nforecasted_times::Vector{Dates.DateTime}\nprices::Vector{T} where T<:AbstractFloat\nτ::AbstractFloat\nrun_time_aligned::Bool\n\nA data structure used to store forecast price data and metadata\n\nrun_time_aligned indicates whether PD and P5MIN raw data used to construct a ForecastData instance were aligned along actual_run_time, i.e. same start and end actual_run_time.\n\n\n\n\n\n","category":"type"},{"location":"data/#NEMStorageUnderUncertainty._get_data_by_times!-Tuple{DataFrames.DataFrame, String}","page":"Price Data Compilers","title":"NEMStorageUnderUncertainty._get_data_by_times!","text":"_get_data_by_times!(\n    forecast_data::DataFrames.DataFrame,\n    forecast_type::String;\n    run_times,\n    forecasted_times\n)\n\n\nSummary\n\nFilters forecast data based on supplied run_times (start, end) and forecasted_times (start, end)\n\nArguments\n\nforecast_data': DataFrame withactualruntimeandforecasted_time`\nforecast_type: For assertion error outputs\nforecasted_times: (start_time, end_time), inclusive\nrun_times: (start_time, end_time), inclusive\n\nReturns\n\nFiltered forecast data\n\nMethods\n\n_get_data_by_times!(\n    forecast_data,\n    forecast_type;\n    run_times,\n    forecasted_times\n)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/data.jl:252.\n\n\n\n\n\n","category":"method"},{"location":"data/#NEMStorageUnderUncertainty._impute_predispatch_data-Tuple{DataFrames.DataFrame}","page":"Price Data Compilers","title":"NEMStorageUnderUncertainty._impute_predispatch_data","text":"_impute_predispatch_data(\n    regional_pd_data::DataFrames.DataFrame\n) -> Any\n\n\nSummary\n\nImputes PREDISPATCH data.\n\nSpecifically, this involves:\n\nBackwards filling forecasted_time\nA forecast at the end of a settlement period should reflect previous 5 intervals\ne.g. price at 13:30 is back filled for 13:25, 13:20 ... 13:05\nForward filling run_time\nLatest forecast should be used until a new forecast is run\ne.g. prices from run at 13:30 are used for 13:35, 13:40 ... 13:55\nWe then ened to remove periods when run_time < forecasted_time\n\nImputation is carried out using Impute.jl.\n\nArguments\n\nregional_pd_data: DataFrame with one region's worth of PD data\n\nReturns\n\nImputed PD DataFrame\n\nMethods\n\n_impute_predispatch_data(regional_pd_data)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/data.jl:173.\n\n\n\n\n\n","category":"method"},{"location":"data/#NEMStorageUnderUncertainty.get_ActualData","page":"Price Data Compilers","title":"NEMStorageUnderUncertainty.get_ActualData","text":"get_ActualData(\n    actual_data::DataFrames.DataFrame,\n    region::String\n) -> NEMStorageUnderUncertainty.ActualData\nget_ActualData(\n    actual_data::DataFrames.DataFrame,\n    region::String,\n    actual_time_window::Union{Nothing, Tuple{Dates.DateTime, Dates.DateTime}}\n) -> NEMStorageUnderUncertainty.ActualData\n\n\nSummary\n\nGet an ActualData instance.\n\nArguments:\n\nactual_data: DataFrame generated by get_all_actual_data\nregion: Market region in the NEM\nactual_time_window: Tuple used to filter DataFrame\n\nReturns:\n\nAn ActualData instance.\n\nMethods\n\nget_ActualData(actual_data, region)\nget_ActualData(actual_data, region, actual_time_window)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/data.jl:83.\n\n\n\n\n\n","category":"function"},{"location":"data/#NEMStorageUnderUncertainty.get_ForecastData","page":"Price Data Compilers","title":"NEMStorageUnderUncertainty.get_ForecastData","text":"get_ForecastData(\n    pd_data::DataFrames.DataFrame,\n    p5_data::DataFrames.DataFrame,\n    region::String\n) -> NEMStorageUnderUncertainty.ForecastData\nget_ForecastData(\n    pd_data::DataFrames.DataFrame,\n    p5_data::DataFrames.DataFrame,\n    region::String,\n    run_time_window::Union{Nothing, Tuple{Dates.DateTime, Dates.DateTime}}\n) -> NEMStorageUnderUncertainty.ForecastData\nget_ForecastData(\n    pd_data::DataFrames.DataFrame,\n    p5_data::DataFrames.DataFrame,\n    region::String,\n    run_time_window::Union{Nothing, Tuple{Dates.DateTime, Dates.DateTime}},\n    forecasted_time_window::Union{Nothing, Tuple{Dates.DateTime, Dates.DateTime}}\n) -> NEMStorageUnderUncertainty.ForecastData\n\n\nSummary\n\nGet a ForecastData instance.\n\nArguments:\n\npd_data, p5_data: DataFrames generated by get_all_pd_and_p5_data\nregion: Market region in the NEM\nrun_time_window: Tuple used to filter DataFrame based on run times\nforecasted_time_window: Tuple used to filter DataFrame based for forecasted time\n\nReturns:\n\nAn ForecastData instance.\n\nMethods\n\nget_ForecastData(pd_data, p5_data, region)\nget_ForecastData(pd_data, p5_data, region, run_time_window)\nget_ForecastData(\n    pd_data,\n    p5_data,\n    region,\n    run_time_window,\n    forecasted_time_window\n)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/data.jl:305.\n\n\n\n\n\n","category":"function"},{"location":"data/#NEMStorageUnderUncertainty.get_all_actual_data-Tuple{String}","page":"Price Data Compilers","title":"NEMStorageUnderUncertainty.get_all_actual_data","text":"get_all_actual_data(path::String) -> DataFrames.DataFrame\n\n\nSummary\n\nObtains actual data from parquet files located at path\n\nArguments\n\npath: Path to parquet partitions\n\nReturns\n\nDataFrame with settlement date, region and corresponding energy prices\n\nMethods\n\nget_all_actual_data(path)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/data.jl:51.\n\n\n\n\n\n","category":"method"},{"location":"data/#NEMStorageUnderUncertainty.get_all_pd_and_p5_data-Tuple{String, String}","page":"Price Data Compilers","title":"NEMStorageUnderUncertainty.get_all_pd_and_p5_data","text":"get_all_pd_and_p5_data(\n    pd_path::String,\n    p5_path::String\n) -> Tuple{DataFrames.DataFrame, DataFrames.DataFrame}\n\n\nSummary\n\nObtains and compiles all forecasted price data from parquet files located at the P5MIN path (p5_path) and the PREDISPATCH path (pd_path)\n\nNote that Parquet.jl cannot parse Timestamps from .parquet, so we use unix2datetime.\n\nArguments\n\npd_path: Path to PREDISPATCH parquet partitions\np5_path: Path to P5MIN parquet partitions\n\nReturns\n\nCompiled forecast data with nominal run times, forecasted times, regions and their corresponding energy prices.\n\nMethods\n\nget_all_pd_and_p5_data(pd_path, p5_path)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/data.jl:130.\n\n\n\n\n\n","category":"method"},{"location":"objectives/#Objectives","page":"Objectives","title":"Objectives","text":"","category":"section"},{"location":"objectives/","page":"Objectives","title":"Objectives","text":"Modules = [NEMStorageUnderUncertainty]\nPages = [\"model/objectives.jl\"]","category":"page"},{"location":"objectives/#NEMStorageUnderUncertainty._add_objective_standard!-Tuple{JuMP.Model, Vector{<:AbstractFloat}, Vector{Dates.DateTime}, Float64}","page":"Objectives","title":"NEMStorageUnderUncertainty._add_objective_standard!","text":"_add_objective_standard!(\n    model::JuMP.Model,\n    prices::Vector{<:AbstractFloat},\n    times::Vector{Dates.DateTime},\n    τ::Float64\n) -> Any\n\n\nSummary\n\nAdds a standard revenue-maximising objective function:\n\nbeginaligned\nmax_t quad  sum_ttaulambda_t(p_t - q_t)\nendaligned\n\nArguments\n\nmodel: JuMP model\nprices: A Vector of prices in /MWh\ntimes: A Vector of DateTimes\nτ: Frequency of prices in hours\n\nMethods\n\n_add_objective_standard!(model, prices, times, τ)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/model/objectives.jl:17.\n\n\n\n\n\n","category":"method"},{"location":"#NEMStorageUnderUncertainty-Documentation","page":"Home","title":"NEMStorageUnderUncertainty Documentation","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"A modelling framework built to explore the impact of future market information (forecasts) on the operation of energy storage in the National Electricity Market (NEM).","category":"page"},{"location":"","page":"Home","title":"Home","text":"Pages = [\"devices.md\", \"data.md\", \"formulations.md\"]\nDepth = 1","category":"page"},{"location":"build/#Model-Building-and-Execution","page":"Model Building and Execution","title":"Model Building and Execution","text":"","category":"section"},{"location":"build/","page":"Model Building and Execution","title":"Model Building and Execution","text":"Modules = [NEMStorageUnderUncertainty]\nPages = [\"model/build_and_run.jl\"]","category":"page"},{"location":"build/#NEMStorageUnderUncertainty._build_storage_model-Tuple{NEMStorageUnderUncertainty.StorageDevice, Vector{<:AbstractFloat}, Vector{Dates.DateTime}, Float64, NEMStorageUnderUncertainty.StandardArbitrage}","page":"Model Building and Execution","title":"NEMStorageUnderUncertainty._build_storage_model","text":"_build_storage_model(\n    storage::NEMStorageUnderUncertainty.StorageDevice,\n    prices::Vector{<:AbstractFloat},\n    times::Vector{Dates.DateTime},\n    τ::Float64,\n    ::NEMStorageUnderUncertainty.StandardArbitrage;\n    silent,\n    time_limit_sec,\n    string_names\n) -> JuMP.Model\n\n\nSummary\n\nBuild a StandardArbitrage model\n\nArguments\n\nstorage: StorageDevice\nprices: Energy prices in /MW/hr that corresponds to prices at times\ntimes: Times to run model for\nτ: Interval duration in hours\nStandardArbitrage\nsilent: default false. true to suppress solver output\ntime_limit_sec: default nothing. Float64 to impose solver time limit in seconds\nstring_names: default true. false to disable JuMP string names\n\nReturns\n\nBuilt JuMP model\n\nMethods\n\n_build_storage_model(\n    storage,\n    prices,\n    times,\n    τ,\n    ;\n    silent,\n    time_limit_sec,\n    string_names\n)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/model/build_and_run.jl:23.\n\n\n\n\n\n","category":"method"},{"location":"build/#NEMStorageUnderUncertainty.run_model-Tuple{MathOptInterface.OptimizerWithAttributes, NEMStorageUnderUncertainty.StorageDevice, Vector{<:AbstractFloat}, Vector{Dates.DateTime}, Float64, NEMStorageUnderUncertainty.StorageModelFormulation}","page":"Model Building and Execution","title":"NEMStorageUnderUncertainty.run_model","text":"run_model(\n    optimizer::MathOptInterface.OptimizerWithAttributes,\n    storage::NEMStorageUnderUncertainty.StorageDevice,\n    prices::Vector{<:AbstractFloat},\n    times::Vector{Dates.DateTime},\n    τ::Float64,\n    formulation::NEMStorageUnderUncertainty.StorageModelFormulation;\n    silent,\n    time_limit_sec,\n    string_names\n) -> JuMP.Model\n\n\nSummary\n\nRuns a model using data in prices, times and τ (interval duration in hours). The type of model constructed and run is dependent on the formulation\n\nArguments\n\noptimizer: A solver optimizer\nstorage: StorageDevice\nprices: Energy prices in /MW/hr that corresponds to prices at times\ntimes: Times to run model for\nτ: Interval duration in hours\nformulation: A model formulation (StorageModelFormulation)\n\nReturns\n\nA JuMP model if the solution is optimal (within solver tolerances)\nA JuMP model with warning if a time/iteration limit is hit\nThrows and error if infeasible/unbounded/etc.\n\nMethods\n\nrun_model(\n    optimizer,\n    storage,\n    prices,\n    times,\n    τ,\n    formulation;\n    silent,\n    time_limit_sec,\n    string_names\n)\n\ndefined at /home/runner/work/NEMStorageUnderUncertainty/NEMStorageUnderUncertainty/src/model/build_and_run.jl:72.\n\n\n\n\n\n","category":"method"}]
}
