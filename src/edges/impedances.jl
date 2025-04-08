function _default_impedances(phase_type::Type{T}) where {T <: Phases}
    if phase_type == SinglePhase
        return Inf
    end
    return ones(3, 3) * Inf
end


"""
    resistance(::Type{MissingEdge}, phase_type::Type{T}) where {T <: Phases}

return _default_impedances(phase_type)
"""
function resistance(::Type{MissingEdge}, phase_type::Type{T}) where {T <: Phases}
    _default_impedances(phase_type)
end


"""
    reactance(::Type{MissingEdge}, phase_type::Type{T}) where {T <: Phases}

return _default_impedances(phase_type)
"""
function reactance(::Type{MissingEdge}, phase_type::Type{T}) where {T <: Phases}
    _default_impedances(phase_type)
end


"""
    resistance_per_length(::Type{MissingEdge}, phase_type::Type{T}) where {T <: Phases}

return _default_impedances(phase_type)
"""
function resistance_per_length(::Type{MissingEdge}, phase_type::Type{T}) where {T <: Phases}
    _default_impedances(phase_type)
end


"""
    reactance_per_length(::Type{MissingEdge}, phase_type::Type{T}) where {T <: Phases}

return _default_impedances(phase_type)
"""
function reactance_per_length(::Type{MissingEdge}, phase_type::Type{T}) where {T <: Phases}
    _default_impedances(phase_type)
end


"""
    rij(i::AbstractString, j::AbstractString, net::Network)

    resistance(net[(i,j)])

Resistance of edge i-j
"""
function rij(i::AbstractString, j::AbstractString, net::Network)
    resistance(net[(i,j)], network_phase_type(net))
end


"""
    rij(i::AbstractString, j::AbstractString, net:::Network{SinglePhase})

Scalar resistance of edge i-j
"""
function rij(i::AbstractString, j::AbstractString, net::Network{SinglePhase})
    r = resistance(net[(i,j)], network_phase_type(net))
    if isa(r, AbstractMatrix) 
        if size(r) == (1,1)
            return r[1,1]
        else
            throw(@error "Edge ($i, $j) has a multiphase impedance matrix in a single phase network.")
        end
    end
    return r
end


"""
    rij_per_unit(i::AbstractString, j::AbstractString, net::Network)

    resistance(net[(i,j)]) / net.Zbase

Resistance of edge i-j normalized by `net.Zbase`
"""
function rij_per_unit(i::AbstractString, j::AbstractString, net::Network)
    rij(i, j, net) / net.Zbase
end


"""
    xij(i::AbstractString, j::AbstractString, net::Network)

Reactance of edge i-j
"""
function xij(i::AbstractString, j::AbstractString, net::Network)
    reactance(net[(i,j)], network_phase_type(net))
end


"""
    xij(i::AbstractString, j::AbstractString, net:::Network{SinglePhase})

Scalar reactance of edge i-j
"""
function xij(i::AbstractString, j::AbstractString, net::Network{SinglePhase})
    x = reactance(net[(i,j)], network_phase_type(net))
    if isa(x, AbstractMatrix) 
        if size(x) == (1,1)
            return x[1,1]
        else
            throw(@error "Edge ($i, $j) has a multiphase impedance matrix in a single phase network.")
        end
    end
    return x
end


"""
    xij_per_unit(i::AbstractString, j::AbstractString, net::Network)

Reactance of edge i-j normalized by `net.Zbase`
"""
function xij_per_unit(i::AbstractString, j::AbstractString, net::Network)
    xij(i, j, net) / net.Zbase
end


"""
    zij(i::AbstractString, j::AbstractString, net::Network)

Impedance matrix of edge (i,j)
"""
function zij(i::AbstractString, j::AbstractString, net::Network)
    return resistance(net[(i, j)], network_phase_type(net)) + reactance(net[(i, j)], network_phase_type(net))im
end


"""
zij_per_unit(i::AbstractString, j::AbstractString, net::Network)

Impedance matrix of edge (i,j) in per-unit (normalized with `net.Zbase`)
"""
function zij_per_unit(i::AbstractString, j::AbstractString, net::Network)
    zij(i, j, net) / net.Zbase
end


"""
    resistance_per_length(c::Conductor, phase_type::Type{T}) where {T <: Phases}

    if ismissing(c.phases)  # single phase
        return c.r1
    end
    return c.rmatrix
"""
function resistance_per_length(c::Conductor, phase_type::Type{T}) where {T <: Phases}
    if phase_type == SinglePhase
        return c.r1
    end
    return c.rmatrix
end


"""
    resistance(c::Conductor)

`resistance_per_length(c) * c.length`

The absolute resistance of the conductor (in the units provided by the user)
"""
function resistance(c::Conductor, phase_type::Type{T}) where {T <: Phases}
    resistance_per_length(c, phase_type) * c.length
end
"""
    reactance_per_length(c::Conductor)

    if phase_type == SinglePhase
        return c.x1
    end
    return c.xmatrix
"""
function reactance_per_length(c::Conductor, phase_type::Type{T}) where {T <: Phases}
    if phase_type == SinglePhase
        return c.x1
    end
    return c.xmatrix
end


"""
    reactance(c::Conductor)

`reactance_per_length(c) * c.length`

The absolute reactance of the conductor (in the units provided by the user)
"""
function reactance(c::Conductor, phase_type::Type{T}) where {T <: Phases}
    reactance_per_length(c, phase_type) * c.length
end


"""
    resistance(vr::VoltageRegulator)

    if phase_type == SinglePhase
        return vr.resistance
    end
    return vr.rmatrix
"""
function resistance(vr::VoltageRegulator, phase_type::Type{T}) where {T <: Phases}
    if phase_type == SinglePhase
        return vr.resistance
    end
    return vr.rmatrix
end


"""
    reactance(vr::VoltageRegulator)

    if phase_type == SinglePhase
        return vr.reactance
    end
    return vr.xmatrix
"""
function reactance(vr::VoltageRegulator, phase_type::Type{T}) where {T <: Phases}
    if phase_type == SinglePhase
        return vr.reactance
    end
    return vr.xmatrix
end


"""
    resistance(trfx::Transformer)

    if phase_type == SinglePhase
        return trfx.resistance
    end
    return trfx.rmatrix
"""
function resistance(trfx::Transformer, phase_type::Type{T}) where {T <: Phases}
    if phase_type == SinglePhase
        return trfx.resistance
    end
    return trfx.rmatrix
end


"""
    reactance(trfx::Transformer)

    if phase_type == SinglePhase
        return trfx.reactance
    end
    return trfx.xmatrix
"""
function reactance(trfx::Transformer, phase_type::Type{T}) where {T <: Phases}
    if phase_type == SinglePhase
        return trfx.reactance
    end
    return trfx.xmatrix
end
