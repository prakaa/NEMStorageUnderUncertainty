function _simulate_actual_prices(
    optimizer::DataType,
    storage::StorageDevice,
    actual_price_data_path::String,
    region::String;
    time_window::Union{Nothing,Tuple{DateTime,DateTime}}=nothing,
)
    if region ∉ ("QLD1", "NSW1", "VIC1", "SA1", "TAS1")
        throw(ArgumentError("Invalid region"))
    end
    actual = get_all_actual_prices(actual_price_data_path)
    if !isnothing(time_window)
        actual = get_prices_by_times(actual, time_window)
    end
    df = actual.data
    filter!(:REGIONID => x -> x == region, df)
    times = df[:, :SETTLEMENTDATE]
    prices = df[:, :RRP]
    model = build_storage_model(storage, prices, times, StandardFormulation())
    JuMP.set_optimizer(model, optimizer)
    return model
end
