"""
Finds simulation results given a simulation folder and categorises results by
state/market region and model formulation.

# Arguments

  * `sim_path`: Path containing simulations of different formulations and their results.

# Returns

A `Dict` that categorises simulation result file names by state/market region, and then by
the model formulation used in the simulation.

Result files are mapped to a formulation in a Dict{String, Vector{String}}
"""
function _categorise_simulation_results(sim_path::String)
    @assert isdir(sim_path)
    sim_formulations = readdir(sim_path)
    categorisation = Dict{String,Dict}()
    for formulation in sim_formulations
        if ispath(joinpath(sim_path, formulation, "results"))
            sim_files = [x for x in readdir(joinpath(sim_path, formulation, "results"))]
            results = filter(x -> splitext(x)[2] == ".jld2", sim_files)
        else
            continue
        end
        states = unique([x[1:3] for x in results])
        for state in states
            state_results = filter(x -> contains(x, state), results)
            if state ∉ keys(categorisation)
                categorisation[state] = Dict(formulation => state_results)
            else
                categorisation[state][formulation] = state_results
            end
        end
    end
    return categorisation
end

"""
Summarises data from the results of each simulation iteration.

Columns in summary output include:
  1. `formulation` name
  2. `energy_capacity`, which is the energy capacity of the device in MWh
  3. `power_capacity`, which is the power capacity of the device in MW
  4. `data_type`, which is forecast or actual (data)
  5. `lookahead` of the simulation in minutes
  6. `revenue`, which is the total annual revenue of the simulated device in AUD
  7. `mean_rel_gap`, which is the mean relative gap across all decision times

# Arguments

  * `data`: Data as loaded from results JLD2 file
  * `formulation`: Formulation name
  * `energy_capacity`: Energy capacity of device in simulation (in MWh)

# Returns

  `DataFrame` with data summarised for all simulations using `formulation`.

"""
function _summarise_simulations(
    data::Dict{String,Any}, formulation::String, energy_capacity::Float64
)
    revenues = Float64[]
    bess_powers = Float64[]
    data_types = String[]
    lookaheads = Int64[]
    average_gaps = Float64[]
    for key in keys(data)
        df = data[key]
        for lookahead in unique(df.lookahead_minutes)
            lookahead_df = df[df.lookahead_minutes.==lookahead, :]
            lookahead_df = lookahead_df[lookahead_df.status.=="binding", :]
            revenue = sum(lookahead_df.revenue)
            average_gap = mean(unique(lookahead_df, "decision_time").relative_gap)
            bess_power = string(match(r"([0-9\.]*)MW", split(key, "/")[2]).captures[])
            data_type = split(key, "/")[1]
            push!(revenues, float(revenue))
            push!(lookaheads, lookahead)
            push!(average_gaps, average_gap)
            push!(bess_powers, parse(Float64, bess_power))
            push!(data_types, data_type)
        end
    end
    summary_data = DataFrame(
        :formulation => fill(formulation, length(lookaheads)),
        :energy_capacity => fill(energy_capacity, length(lookaheads)),
        :power_capacity => bess_powers,
        :data_type => data_types,
        :lookahead => string.(lookaheads),
        :revenue => revenues,
        :mean_rel_gap => average_gaps,
    )
    summary_data = sort(summary_data, "power_capacity")
    summary_data.lookahead =
        replace.(summary_data.lookahead, "526500" => "Perfect Foresight")
    return summary_data
end

@doc raw"""
Calculates values of perfect lookahead and information as absolute values (in AUD) and as
a percentage of perfect foresight revenue.

**Value of perfect lookahead**: What is the additional benefit (revenue) that a participant
could gain if they were to know exactly what the market prices will be in the *lookahead
horizon*.
  * ``VPL = \textrm{Revenue}_\textrm{Actual Data Simulation} -  \textrm{Revenue}_\textrm{Forecast Data Simulation}``

**Value of perfect information**: What is the additional benefit (revenue) that a
participant could gain if they were to know exactly what the market prices will be
*over the entire year*
  * ``VPI = \textrm{Revenue}_\textrm{Perfect Foresight} -  \textrm{Revenue}_\textrm{Forecast Data Simulation}``

N.B. This function assumes that the input `df` only has data that corresponds to a device
of a particular `energy_capacity`.

# Arguments

  * `df`: `DataFrame` produced by `_summarise_simulations`

# Returns

`DataFrame` with absolute values of perfect lookahead and information, and the same values
as a percentage of perfect foresight revenue.
"""
function calculate_vpl_vpi(df::DataFrame)
    (v_pl_abs, v_pi_abs) = (Float64[], Float64[])
    (v_pl_percentage, v_pi_percentage) = (Float64[], Float64[])
    (power_caps, data) = (Float64[], String[])
    actual_caps = unique(df[df.data_type.=="actual", :power_capacity])
    forecast_caps = unique(df[df.data_type.=="forecast", :power_capacity])
    capacities = intersect(actual_caps, forecast_caps)
    lookaheads = [lk for lk in unique(df.lookahead) if lk != "Perfect Foresight"]
    for cap in capacities
        for lookahead in lookaheads
            lk_mask = df.lookahead .== lookahead
            cap_mask = df.power_capacity .== cap
            actual_mask = df.data_type .== "actual"
            forecast_mask = df.data_type .== "forecast"
            forecast_rev = df[cap_mask.&forecast_mask.&lk_mask, :revenue]
            pf_rev = df[
                cap_mask.&forecast_mask.&(df.lookahead.=="Perfect Foresight"),
                :revenue,
            ]
            pi_rev = df[cap_mask.&actual_mask.&lk_mask, :revenue]
            v_pl = pi_rev - forecast_rev
            v_pi = pf_rev - forecast_rev
            v_pl_percentage_pf = @. v_pl / pf_rev * 100
            v_pi_percentage_pf = @. v_pi / pf_rev * 100
            push!(power_caps, cap)
            push!(data, lookahead)
            push!(v_pl_abs, v_pl[])
            push!(v_pi_abs, v_pi[])
            push!(v_pl_percentage, v_pl_percentage_pf[])
            push!(v_pi_percentage, v_pi_percentage_pf[])
        end
    end
    return DataFrame(
        :formulation => fill(unique(df.formulation)[], length(power_caps)),
        :energy_capacity => fill(unique(df.energy_capacity)[], length(power_caps)),
        :power_capacity => power_caps,
        :lookahead => data,
        :vpl_abs => v_pl_abs,
        :vpi_abs => v_pi_abs,
        :vpl_per => v_pl_percentage,
        :vpi_per => v_pi_percentage,
    )
end

"""
Calculates values of perfect lookahead and information

For each state, this function cycles through each simulated formulation calculates
the value of perfect lookahead and value of information

For a single state, the VPLs and VPIs across simulated formulations are then released
in a JLD2 file in the `results` folder

# Arguments
  * `sim_folder`: Path containing simulations of different formulations and their results.

# Returns

`Nothing`

"""
function calculate_vpl_vpi_across_scenarios(summary_folder::String)
    @assert isdir(summary_folder)
    state_summary_results = [
        file for file in readdir(summary_folder) if contains(file, "summary_results.jld2")
    ]
    for file in state_summary_results
        state = string(
            match(r"([A-Z]{2,3})_summary_results.jld2", file).captures[]
        )

        @info "Calculating VPL and VPI for $state"
        summary_data = load(joinpath(summary_folder, file))
        vpl_vpi_data = DataFrame[]
        for (formulation, summary) in pairs(summary_data)
            vpl_vpi = calculate_vpl_vpi(summary)
            if contains(formulation, "/")
                param = string(match(r".*/(.*)", formulation).captures[])
                vpl_vpi[!, :param] = fill(param, size(vpl_vpi, 1))
            else
                vpl_vpi[!, :param] = fill(missing, size(vpl_vpi, 1))
            end
            push!(vpl_vpi_data, vpl_vpi)
        end
        state_vpl_vpi = vcat(vpl_vpi_data...)
        @info "Saving VPL and VPI data for $state"
        jldopen(joinpath(summary_folder, "vpl_vpi.jld2"), "w"; compress=true) do f
            f["$(state)"] = state_vpl_vpi
        end
    end
    return nothing
end

"""
Summarises results, revenues and VPL and VPI for each simulated formulation

For each state, this function cycles through each simulated formulation and:

  1. Calculates summary results (i.e. annual net revenue and mean relative gap)
  1. Calculates revenues (i.e. annual net revenue, annual negative revenue)
  2. Calculates the value of perfect lookahead and value of perfect information

A JLD2 file for each of these (with data for each simulated formulation) is released in
the `results` folder

# Arguments
  * `sim_folder`: Path containing simulations of different formulations and their results.

# Returns

`Nothing`

lookahead.
"""
function calculate_summaries_and_vpl_vpi_across_scenarios(sim_folder::String)
    save_path = joinpath("results", "data")
    if !isdir(save_path)
        mkpath(save_path)
    end
    categorisation = _categorise_simulation_results(sim_folder)
    for state in keys(categorisation)
        summary_file_name = joinpath(save_path, "$(state)_summary_results.jld2")
        if !isfile(summary_file_name)
            summary_data = Dict{String,DataFrame}()
            formulation_results = categorisation[state]
            for (formulation, results) in pairs(formulation_results)
                formulation_results_path = joinpath(sim_folder, formulation, "results")
                if length(results) == 1
                    file = results[]
                    energy = parse(
                        Float64, match(r"[A-Z]{2,3}_([0-9\.]*)MWh_.*", file).captures[]
                    )
                    data = load(joinpath(formulation_results_path, file))
                    @info "Calculating summary information for $state $formulation"
                    summary = _summarise_simulations(data, formulation, energy)
                    summary_data["$(formulation)"] = summary
                else
                    for file in results
                        energy_param_capture = match(
                            r"[A-Z]{2,3}_([0-9\.]*)MWh_.*_param(.*)_NoDeg_2021.jld2", file
                        )
                        energy = parse(Float64, energy_param_capture.captures[1])
                        param = string(energy_param_capture.captures[2])
                        data = load(joinpath(formulation_results_path, file))
                        summary = _summarise_simulations(data, formulation, energy)
                        @info "Calculating summary information for $state $formulation $param"
                        summary_data["$(formulation)/$(param)"] = summary
                    end
                end
            end
            summary_file_name = joinpath(save_path, "$(state)_summary_results.jld2")
            jldopen(summary_file_name, "w"; compress=true) do f
                for (key, value) in pairs(summary_data)
                    f[key] = value
                end
            end
        end
    end
    vpl_vpi_file_name = joinpath(save_path, "vpl_vpi.jld2")
    if !isfile(vpl_vpi_file_name)
        @info "Calculating VPL and VPI across scenarios"
        calculate_vpl_vpi_across_scenarios(save_path)
    end
    return nothing
end
