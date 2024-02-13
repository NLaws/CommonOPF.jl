"""
    resistance(e::AbstractEdge) = 0.0
"""
resistance(e::AbstractEdge) = 0.0


"""
    reactance(e::AbstractEdge) = 0.0
"""
reactance(e::AbstractEdge) = 0.0


"""
    resistance_per_length(e::AbstractEdge) = 0.0
"""
resistance_per_length(e::AbstractEdge) = 0.0


"""
    reactance_per_length(e::AbstractEdge) = 0.0
"""
reactance_per_length(e::AbstractEdge) = 0.0


"""
    rij(i::AbstractString, j::AbstractString, net::Network)

    resistance(net[(i,j)])

Resistance of edge i-j
"""
function rij(i::AbstractString, j::AbstractString, net::Network)
    resistance(net[(i,j)])
end


"""
    rij_per_unit(i::AbstractString, j::AbstractString, net::Network)

    resistance(net[(i,j)]) / net.Zbase

Resistance of edge i-j normalized by `net.Zbase`
"""
function rij_per_unit(i::AbstractString, j::AbstractString, net::Network)
    resistance(net[(i,j)]) / net.Zbase
end


"""
    xij(i::AbstractString, j::AbstractString, net::Network)

Reactance of edge i-j
"""
function xij(i::AbstractString, j::AbstractString, net::Network)
    reactance(net[(i,j)])
end


"""
    xij_per_unit(i::AbstractString, j::AbstractString, net::Network)

Reactance of edge i-j normalized by `net.Zbase`
"""
function xij_per_unit(i::AbstractString, j::AbstractString, net::Network)
    reactance(net[(i,j)]) / net.Zbase
end


"""
    resistance_per_length(c::Conductor)

    if ismissing(c.phases)  # single phase
        return c.r1
    end
    return c.rmatrix
"""
function resistance_per_length(c::Conductor)
    if ismissing(c.phases)  # single phase
        return c.r1
    end
    return c.rmatrix
end


"""
    resistance(c::Conductor)

`resistance_per_length(c) * c.length`

The absolute resistance of the conductor (in the units provided by the user)
"""
function resistance(c::Conductor)
    resistance_per_length(c) * c.length
end
"""
    reactance_per_length(c::Conductor)

    if ismissing(c.phases)  # single phase
        return c.x1
    end
    return c.xmatrix
"""
function reactance_per_length(c::Conductor)
    if ismissing(c.phases)  # single phase
        return c.x1
    end
    return c.xmatrix
end


"""
    reactance(c::Conductor)

`reactance_per_length(c) * c.length`

The absolute reactance of the conductor (in the units provided by the user)
"""
function reactance(c::Conductor)
    reactance_per_length(c) * c.length
end


"""
    resistance(vr::VoltageRegulator)

    vr.resistance
"""
function resistance(vr::VoltageRegulator)
    vr.resistance
end


"""
    reactance(vr::VoltageRegulator)

    vr.reactance
"""
function reactance(vr::VoltageRegulator)
    vr.reactance
end


function resistance(trfx::Transformer)
    
end


"""
    function zij(i::AbstractString, j::AbstractString, net::Network{SinglePhase})::Tuple{Real, Real}

Impedance for single phase models. 

Returns `(r1, x1) * length / net.Zbase` for the `Conductor` at `net[(i, j)]`.

TODO convert impedance methods to dispatch on edge type
TODO MultiPhase
"""
function zij(i::AbstractString, j::AbstractString, net::Network{SinglePhase})::Tuple{Real, Real}
    # only have Conductor edges now, later add impedances of other devices
    conductor = net[(i, j)]
    if ismissing(conductor)
        throw(ErrorException("No conductor found for edge ($i, $j)"))
    elseif typeof(conductor) != CommonOPF.Conductor
        throw(@error "Was looking for a Conductor in edge ($i, $j) but found a $(typeof(conductor))")
    end
    # TODO should instead dispatch on edge type
    # check for template 
    if !ismissing(conductor.template)
        conds = collect(conductors(net))
        results = filter(cond -> !ismissing(cond.name) && cond.name == conductor.template, conds)
        if length(results) == 0
            throw(ErrorException("No conductor template with name $conductor.template found."))
        end
        template_conductor = results[1]
        r1, x1 = template_conductor.r1, template_conductor.x1
    else  # get impedance from the conductor
        r1, x1 = conductor.r1, conductor.x1
    end
    if ismissing(r1) || ismissing(x1)
        throw(ErrorException("Missing at least one of r1 and x1 for edge ($i, $j)"))
    end
    L = conductor.length
    return (r1 * L / net.Zbase, x1 * L / net.Zbase)
end