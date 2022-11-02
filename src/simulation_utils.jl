function make_ActualData(
    data_path::String, region::String, time_window::Union{Tuple{DateTime,DateTime},Nothing}
)
    all_actual_data = NEMStorageUnderUncertainty.get_all_actual_data(data_path)
    actual = NEMStorageUnderUncertainty.get_ActualData(all_actual_data, region, time_window)
    return actual
end
