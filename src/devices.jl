abstract type StorageDevice end

mutable struct BESS <: StorageDevice
    const power_capacity::Float64
    energy_capacity::Float64
    soc_min::Float64
    soc_max::Float64
    const η_charge::Float64
    const η_discharge::Float64
    const soc₀::Float64
    throughput::Float64
    @doc """
        BESS(
            power_capacity::Float64,
            nominal_energy_capacity::Float64,
            soc_min::Float64,
            soc_max::Float64,
            η_charge::Float64,
            η_discharge::Float64,
            soc₀::Float64
        )

    Initialises a battery energy storage system (BESS)

    # Arguments

      * `power_capacity`: Maximum charge/discharge power capacity (MW)
      * `energy_capacity`: Maximum energy capacity (MWh)
      * `soc_min`: Minimum allowable operational state of charge (MWh)
      * `soc_max`: Maximum allowable operational state of charge (MWh)
      * `η_charge`: Charging efficiency (0-1)
      * `η_discharge`: Discharge efficiency (0-1)
      * `soc₀`: Initial state of charge (MWh)
      * `throughput`: Energy throughput (MWh)

    # Returns

    A BESS with mutable `energy_capacity`, `soc_min`, `soc_max` and `throughput`.
    """
    function BESS(
        power_capacity::Float64,
        energy_capacity::Float64,
        soc_min::Float64,
        soc_max::Float64,
        η_charge::Float64,
        η_discharge::Float64,
        soc₀::Float64;
        throughput::Float64 = 0.0
    )
        if any([cap ≤ 0 for cap in (power_capacity, energy_capacity)])
            throw(DomainError("Capacities should be > 0"))
        end
        if any([soc < 0 for soc in (soc₀, soc_min, soc_max)])
            throw(
                DomainError("SoC values should be ≥ 0")
            )
        end
        if throughput < 0
            throw(
                DomainError("Energy throughput should be ≥ 0")
            )
        end
        if any([soc > energy_capacity for soc in (soc_min, soc_max, soc₀)])
            throw(
                DomainError("SoC values should be ≤ the BESS energy capacity")
            )
        end
        if soc_min ≥ soc_max
            throw(
                ArgumentError("Max SoC limit should be greater than the min SoC limit")
            )
        end
        if any([(η < 0) | (η > 1) for η in (η_charge, η_discharge)])
            throw(
                DomainError("Efficiency values should be between 0 (0%) and 1 (100%)")
            )
        end
        return new(
            power_capacity, energy_capacity, soc_min, soc_max,
            η_charge, η_discharge, soc₀, throughput
        )
    end
end
