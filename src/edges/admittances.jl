"""
    conductance(e::AbstractEdge, phase_type::Type{T}) where {T <: Phases} = 0.0

Default conductance for subtypes of `AbstractEdge`
"""
conductance(e::AbstractEdge, phase_type::Type{T}) where {T <: Phases} = 0.0


"""
    susceptance(e::AbstractEdge, phase_type::Type{T}) where {T <: Phases} = 0.0

Default susceptance for subtypes of `AbstractEdge`
"""
susceptance(e::AbstractEdge, phase_type::Type{T}) where {T <: Phases} = 0.0


"""
    conductance_per_length(e::AbstractEdge) = 0.0

Default conductance_per_length for subtypes of `AbstractEdge`
"""
conductance_per_length(e::AbstractEdge, phase_type::Type{T}) where {T <: Phases} = 0.0


"""
    susceptance_per_length(e::AbstractEdge) = 0.0

Default susceptance_per_length for subtypes of `AbstractEdge`
"""
susceptance_per_length(e::AbstractEdge, phase_type::Type{T}) where {T <: Phases} = 0.0


"""
    bij(i::AbstractString, j::AbstractString, net::Network)

    conductance(net[(i,j)])

conductance of edge i-j
"""
function bij(i::AbstractString, j::AbstractString, net::Network)
    conductance(net[(i,j)], network_phase_type(net))
end


"""
    bij(i::AbstractString, j::AbstractString, net:::Network{SinglePhase})

Scalar conductance of edge i-j
"""
function bij(i::AbstractString, j::AbstractString, net::Network{SinglePhase})
    r = conductance(net[(i,j)], network_phase_type(net))
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
    bij_per_unit(i::AbstractString, j::AbstractString, net::Network)

    conductance(net[(i,j)]) * net.Zbase

conductance of edge i-j normalized by `net.Zbase`
"""
function bij_per_unit(i::AbstractString, j::AbstractString, net::Network)
    bij(i, j, net) * net.Zbase
end


"""
    gij(i::AbstractString, j::AbstractString, net::Network)

susceptance of edge i-j
"""
function gij(i::AbstractString, j::AbstractString, net::Network)
    susceptance(net[(i,j)], network_phase_type(net))
end


"""
    gij(i::AbstractString, j::AbstractString, net:::Network{SinglePhase})

Scalar susceptance of edge i-j
"""
function gij(i::AbstractString, j::AbstractString, net::Network{SinglePhase})
    g = susceptance(net[(i,j)], network_phase_type(net))
    if isa(g, AbstractMatrix) 
        if size(g) == (1,1)
            return g[1,1]
        else
            throw(@error "Edge ($i, $j) has a multiphase susceptance matrix in a single phase network.")
        end
    end
    return x
end


"""
    gij_per_unit(i::AbstractString, j::AbstractString, net::Network)

susceptance of edge i-j normalized by `net.Zbase`
"""
function gij_per_unit(i::AbstractString, j::AbstractString, net::Network)
    gij(i, j, net) * net.Zbase
end


"""
    yij(i::AbstractString, j::AbstractString, net::Network)::Matrix{ComplexF64}

Impedance matrix of edge (i,j)
"""
function yij(i::AbstractString, j::AbstractString, net::Network)::Matrix{ComplexF64}
    return conductance(net[(i, j)], network_phase_type(net)) + susceptance(net[(i, j)], network_phase_type(net))im
end


"""
yij_per_unit(i::AbstractString, j::AbstractString, net::Network)::Matrix{ComplexF64}

Impedance matrix of edge (i,j) in per-unit (normalized with `net.Zbase`)
"""
function yij_per_unit(i::AbstractString, j::AbstractString, net::Network)
    yij(i, j, net) * net.Zbase
end


"""
    conductance_per_length(c::Conductor, phase_type::Type{T}) where {T <: Phases}

    if ismissing(c.phases)  # single phase
        return c.r1
    end
    return c.rmatrix
"""
function conductance_per_length(c::Conductor, phase_type::Type{T}) where {T <: Phases}
    if phase_type == SinglePhase
        return c.r1 / (c.length^2 * (c.r1^2 + c.x1^2))
    end
    return c.rmatrix ./ (c.length^2 * (c.rmatrix.^2 + c.xmatrix.^2))
end


"""
    conductance(c::Conductor)

`conductance_per_length(c) * c.length`

The absolute conductance of the conductor (in the units provided by the user)
"""
function conductance(c::Conductor, phase_type::Type{T}) where {T <: Phases}
    conductance_per_length(c, phase_type) * c.length
end


"""
    susceptance_per_length(c::Conductor)

    if phase_type == SinglePhase
        return c.x1
    end
    return c.xmatrix
"""
function susceptance_per_length(c::Conductor, phase_type::Type{T}) where {T <: Phases}
    if phase_type == SinglePhase
        return -c.x1 / (c.length^2 * (c.r1^2 + c.x1^2))
    end
    return -c.xmatrix ./ (c.length^2 * (c.rmatrix.^2 + c.xmatrix.^2))
end


"""
    susceptance(c::Conductor)

`susceptance_per_length(c) * c.length`

The absolute susceptance of the conductor (in the units provided by the user)
"""
function susceptance(c::Conductor, phase_type::Type{T}) where {T <: Phases}
    susceptance_per_length(c, phase_type) * c.length
end


"""
    conductance(vr::VoltageRegulator)

    if phase_type == SinglePhase
        return vr.conductance
    end
    return vr.rmatrix
"""
function conductance(vr::VoltageRegulator, phase_type::Type{T}) where {T <: Phases}
    if phase_type == SinglePhase
        return vr.resistance / (vr.resistance.^2 + vr.reactance.^2)
    end
    return vr.rmatrix ./ (vr.rmatrix^2 + vr.xmatrix^2)
end


"""
    susceptance(vr::VoltageRegulator)

    if phase_type == SinglePhase
        return vr.susceptance
    end
    return vr.xmatrix
"""
function susceptance(vr::VoltageRegulator, phase_type::Type{T}) where {T <: Phases}
    if phase_type == SinglePhase
        return -vr.reactance / (vr.resistance.^2 + vr.reactance.^2)
    end
    return -vr.xmatrix  ./ (vr.rmatrix.^2 + vr.xmatrix^.2)
end


"""
    conductance(trfx::Transformer)

    if phase_type == SinglePhase
        return trfx.conductance
    end
    return trfx.rmatrix
"""
function conductance(trfx::Transformer, phase_type::Type{T}) where {T <: Phases}
    if phase_type == SinglePhase
        return trfx.resistance / (trfx.resistance^2 + trfx.reactance^2)
    end
    return trfx.rmatrix ./ (trfx.rmatrix.^2 + trfx.xmatrix^.2)
end


"""
    susceptance(trfx::Transformer)

    if phase_type == SinglePhase
        return trfx.susceptance
    end
    return trfx.xmatrix
"""
function susceptance(trfx::Transformer, phase_type::Type{T}) where {T <: Phases}
    if phase_type == SinglePhase
        return -trfx.reactance / (trfx.resistance^2 + trfx.reactance^2)
    end
    return -trfx.xmatrix ./ (trfx.rmatrix.^2 + trfx.xmatrix^.2)
end
