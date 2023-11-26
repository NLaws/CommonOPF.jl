"""
    get_variable_values(var::Symbol, m::JuMP.AbstractModel, p::Inputs{SinglePhase}; digits=6)

!!! note
    Rounding can be necessary for values that require `sqrt` and have optimal values of zero like 
    `-3.753107219618953e-31`
"""
function get_variable_values(var::Symbol, m::JuMP.AbstractModel, p::Inputs{SinglePhase}; digits=8)
    d = Dict()
    if var in [:Pj, :Qj, :vsqrd]  # TODO make these a const in CommonOPF
        vals = value.(m[var])
        for b in p.busses
            d[b] = round.(vals[b,:].data, digits=digits)
            if var == :vsqrd
                d[b] = sqrt.(d[b])
            else
                d[b] *= p.Sbase  # scale powers back to absolute units TODO in BFM
            end
        end
    elseif var in [:Pij, :Qij, :lij]  # TODO make these a const in CommonOPF TODO in BFM
        vals = value.(m[var])
        for ek in p.edge_keys
            d[ek] = round.(vals[ek,:].data, digits=digits)
            if var == :lij
                d[ek] = sqrt.(d[ek])
            else
                d[ek] *= p.Sbase  # scale powers back to absolute units
            end
        end
    else
        @warn "$var is not a valid variable symbol"
    end
    return d
end


function get_variable_values(var::Symbol, m::JuMP.AbstractModel, net::Network{SinglePhase}; digits=8)
    d = Dict()
    if var in [:Pj, :Qj, :vsqrd]  # TODO make these a const in CommonOPF
        vals = value.(m[var])
        for b in busses(net)
            d[b] = round.(vals[b,:].data, digits=digits)
            if var == :vsqrd
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