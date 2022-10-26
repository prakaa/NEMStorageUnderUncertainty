function _initialise_model(
    optimizer;
    silent::Bool=false,
    time_limit_sec::Union{Float64,Nothing}=nothing,
    string_names::Bool=true,
)
    model = JuMP.Model(optimizer)
    if silent
        JuMP.set_silent(model)
    end
    if !isnothing(time_limit_sec)
        JuMP.set_time_limit_sec(model, time_limit_sec)
    end
    if !string_names
        JuMP.set_string_names_on_creation(model, false)
    end
    return model
end
