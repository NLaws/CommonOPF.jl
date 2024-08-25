"""
    Results(m::JuMP.AbstractModel, net::Network)

Create a dictionary of results from the solved model `m`. The returned dictionary has keys from
CommonOPF.VARIABLE_NAMES. If `net.var_name_map` contains any entries we check the model `m` for the
names in the map first. Then we check for any remaining `VARIABLE_NAMES` that are not in the map.
"""
function Results(m::JuMP.AbstractModel, net::Network)
    vnames = Set(VARIABLE_NAMES)
    d = Dict{String, Any}()
    # first get any values from variable names defined in var_name_map
    for (vname, model_key) in net.var_name_map
        delete!(vnames, vname)

        if endswith(var_name, "_squared")
            d[vname] = get_variable_values(model_key, vname, m, net)
        end
    end
    # then check for any of the VARIABLE_NAMES
    for vname in vnames
        if vname in keys(m.obj_dict)
            d[vname] = get_variable_values(vname, vname, m, net)
        end
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


"""

Create a Dict of variables values assuming that the model `m` used the
`CommonOPF.VariableContainer`. The bus or edge labels are used as outer keys (strings) with
time-vector or matrix values. When `var_name` ends with "_squared" we return the `sqrt` of values.
"""
function get_variable_values(model_key, var_name::String, m::JuMP.AbstractModel, net::Network{SinglePhase}; digits=8)
    d = Dict()
    if var in [:Pj, :Qj, :vsqrd]
        vals = value.(m[model_key])  # time, bus 
        for b in busses(net)
            d[b] = round.(vals[b,:].data, digits=digits)
            if endswith(var_name, "_squared")
                d[b] = sqrt.(d[b])
            else
                d[b] *= net.Sbase  # scale powers back to absolute units TODO in BFM
            end
        end
    elseif var in [:Pij, :Qij, :lij]  # TODO make these a const in CommonOPF TODO in BFM
        vals = value.(m[var])
        for ek in edges(net)
            d[ek] = round.(vals[ek,:].data, digits=digits)
            if var == :lij
                d[ek] = sqrt.(d[ek])
            else
                d[ek] *= net.Sbase  # scale powers back to absolute units
            end
        end
    else
        @warn "$var is not a valid variable symbol"
    end
    return d
end


# """
#     check_any_results_at_bounds(r::Results, net::Network)

# warn if any results are at their bounds
# """
# function check_any_results_at_bounds(r::Results, net::Network)

# end