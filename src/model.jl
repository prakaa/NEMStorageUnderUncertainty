using Dates, JuMP

function _initialise_model(
    optimizer;
    silent=false,
    time_limit_sec::Union{Float64, Nothing}=nothing
)

    model = Model(optimizer)
    if silent
        set_silent(model)
    end
    if !isnothing(time_limit_sec)
        set_time_limit_sec(model, time_limit_sec)
    end
    return model
end

function _add_power_vars(
    model::Model,
    storage::StorageDevice,
    t::Vector{DateTime}
)
    power_cap = storage.power_cap
    @variable(model, 0.0 ≤ discharge_mw[t] ≤ power_cap)
    @variable(model, 0.0 ≤ charge_mw[t] ≤ power_cap)
end

function _add_soc_var(
    model::Model,
    storage::StorageDevice,
    t::Vector{DateTime}
)
    min_soc = storage.soc_min
    max_soc = storage.soc_max
    @variable(model, min_soc ≤ soc_mwh[t] ≤ max_soc)
end

function _add_charge_state_var(
    model::Model,
    t::Vector{DateTime}
)
    @variable(model, charge_state[t], Bin)
end
