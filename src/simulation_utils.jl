function make_ActualData(
    data_path::String, region::String, time_window::Union{Tuple{DateTime,DateTime},Nothing}
)
    all_actual_data = NEMStorageUnderUncertainty.get_all_actual_data(data_path)
    actual = NEMStorageUnderUncertainty.get_ActualData(all_actual_data, region, time_window)
    return actual
end

function simulate_standard_arbitrage_with_actual_data(
    optimizer::OptimizerWithAttributes,
    storage::NEMStorageUnderUncertainty.StorageDevice,
    data::NEMStorageUnderUncertainty.ActualData,
    decision_start_time::DateTime,
    decision_end_time::DateTime,
    binding::T,
    horizon::T,
) where {T<:Period}
    results = NEMStorageUnderUncertainty.simulate_storage_operation(
        optimizer,
        storage,
        data,
        NEMStorageUnderUncertainty.StandardArbitrage(),
        NEMStorageUnderUncertainty.NoDegradation();
        decision_start_time=decision_start_time,
        decision_end_time=decision_end_time,
        binding=binding,
        horizon=horizon,
        silent=true,
    )
    return results
end
