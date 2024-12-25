"""
    opf_results(m::JuMP.AbstractModel, net::Network)

For all the symbols in `net.var_names` fill in a dictionary of variable values using the same
structure as the model variable containers.
"""
function opf_results(m::JuMP.AbstractModel, net::Network)
    d = DefaultDict{Symbol, DefaultDict{Any, DefaultDict}}(
        () -> DefaultDict{Any, DefaultDict}(
            () -> DefaultDict{Int, Union{Any, Missing}}(missing)
        )
    )
    for var_name in net.var_names, 
        bus_or_edge in keys(m[var_name]), 
        time_step in keys(m[var_name][bus_or_edge])
        
        d[var_name][bus_or_edge][time_step] = JuMP.value.(m[var_name][bus_or_edge][time_step])
    end
    return d
end


function get_variable_values(model_key::Any, m::JuMP.AbstractModel; digits=8)
    # collect vectors of time for each bus or edge
    # TODO how to handle matrix variables?
    # TODO this will only work for SinglePhase?
    return Dict(
        bus_or_edge_string => round.(value.(m[model_key][bus_or_edge_string]), digits=digits)
        for bus_or_edge_string in keys(m[model_key])
    )
end


# """
#     check_any_results_at_bounds(r::Results, net::Network)

# warn if any results are at their bounds
# """
# function check_any_results_at_bounds(r::Results, net::Network)

# end