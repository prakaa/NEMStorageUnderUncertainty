function calculate_actual_revenue!(sim_results::DataFrame, actual_price_data::DataFrame)
    binding_sim_results = filter(:status => status -> status == "binding", sim_results)
    sort!(binding_sim_results, :simulated_time)
    sort!(actual_price_data, :SETTLEMENTDATE)
    @assert(
        actual_price_data.SETTLEMENTDATE[1] ≥ binding_sim_results.simulated_time[1],
        "Actual price data starts after the first simulated datetime"
    )
    @assert(
        actual_price_data.SETTLEMENTDATE[end] ≤ binding_sim_results.simulated_time[end],
        "Actual price data ends before the last simulated datetime"
    )
    actual_price_data = rename(
        actual_price_data, :SETTLEMENTDATE => :simulated_time, :RRP => :actual_price
    )
    merged = leftjoin(
        binding_sim_results, actual_price_data; on=[:simulated_time, :REGIONID]
    )
    merged[!, :revenue] =
        merged[!, :actual_price_data] .* (merged[!, :discharge_mw] .- merged[!, :charge_mw])
    return merged
end
