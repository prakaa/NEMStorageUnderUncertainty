"""
"""
abstract type StorageDevice end

function Base.copy(x::T, soc₀::Float64, throughput::Float64) where {T<:StorageDevice}
    filtered_fields = [f for f ∈ fieldnames(T) if (f != :soc₀ || f != :throughput)]
    return T(;
        Dict(:($k) => getfield(x, k) for k in filtered_fields)...,
        :soc₀ => soc₀,
        :throughput => throughput,
    )
end

Base.@kwdef struct BESS <: StorageDevice
    "Maximum charge/discharge power capacity (MW)"
    power_capacity::Float64
    "Maximum energy capacity (MWh)"
    energy_capacity::Float64
    "Minimum allowable operational state of charge (MWh)"
    soc_min::Float64
    "Maximum allowable operational state of charge (MWh)"
    soc_max::Float64
    "Charging efficiency (0-1)"
    η_charge::Float64
    "Discharge efficiency (0-1)"
    η_discharge::Float64
    "Initial state of charge (MWh)"
    soc₀::Float64
    "Total initial energy throughput (MWh)"
    throughput::Float64 = 0.0

    @doc """
    Initialises a battery energy storage system (BESS).

    `throughput` (in MWh) can be supplied in cases where the BESS has already undertaken
    energy storage and discharge. This is akin to cycling but is independent of
    storage capacity (significant where calendar and/or cycling degradation is
    accounted for). If not supplied, default value is `0.0`.

    # Returns
    A [`BESS`](@ref)
    """
    function BESS(
        power_capacity::Float64,
        energy_capacity::Float64,
        soc_min::Float64,
        soc_max::Float64,
        η_charge::Float64,
        η_discharge::Float64,
        soc₀::Float64,
        throughput::Float64=0.0,
    )
        if any([cap ≤ 0 for cap in (power_capacity, energy_capacity)])
            throw(DomainError("Capacities should be > 0"))
        end
        if any([soc < 0 for soc in (soc_min, soc_max)])
            throw(DomainError("SoC limits should be ≥ 0"))
        end
        if soc₀ < 0
            throw(DomainError("soc₀ ($(soc₀)) should be ≥ 0"))
        end
        if throughput < 0
            throw(DomainError("Energy throughput ($(throughput)) should be ≥ 0"))
        end
        if any([soc > energy_capacity for soc in (soc_min, soc_max, soc₀)])
            throw(DomainError("SoC values should be ≤ the BESS energy capacity"))
        end
        if soc_min ≥ soc_max
            throw(ArgumentError("Max SoC limit should be greater than the min SoC limit"))
        end
        if any([(η < 0) | (η > 1) for η in (η_charge, η_discharge)])
            throw(DomainError("Efficiency values should be between 0 (0%) and 1 (100%)"))
        end
        return new(
            power_capacity,
            energy_capacity,
            soc_min,
            soc_max,
            η_charge,
            η_discharge,
            soc₀,
            throughput,
        )
    end
end
