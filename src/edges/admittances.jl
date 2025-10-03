"""
    inverse_matrix_with_zeros(M::AbstractMatrix)

Invert a matrix while ignoring rows and columns with all zeros. This method is necessary when
inverting a phase impedance matrix for an edge that has less than three phases (CommonOPF fills
zeros for missing phases to make mathematical model building easier). 
"""
function inverse_matrix_with_zeros(M::AbstractMatrix{T})::AbstractMatrix{T} where {T} 
    zero_rows = findall(row -> all(iszero, row), eachrow(M))
    zero_cols = findall(col -> all(iszero, col), eachcol(M))

    if zero_rows != zero_cols
        throw(@error(join([
            "Inverting a matrix with missing phases requires that zero are on the same column and",
            "row indices. However, matrix $M has zeros $zero_rows rows and $zero_cols columns.",
        ], " ")))
    end

    nonzero_rows = setdiff(1:size(M, 1), zero_rows)
    nonzero_cols = setdiff(1:size(M, 2), zero_cols)

    invM_nonzero = inv(@view M[nonzero_rows, nonzero_cols])

    invM = zeros(T, size(M))
    invM[nonzero_rows, nonzero_cols] .= invM_nonzero
    return invM
end


function make_nan_or_inf_zero(val)
    if isnan(val) || isinf(val)
        return 0.0
    end
    val
end


const DEFAULT_ADMITTANCE_SINGLE_PHASE = 0.0
const DEFAULT_ADMITTANCE_MULTI_PHASE = zeros(3, 3)


function _default_admittances(phase_type::Type{T}) where {T <: Phases}
    if phase_type == SinglePhase
        return DEFAULT_ADMITTANCE_SINGLE_PHASE
    end
    return DEFAULT_ADMITTANCE_MULTI_PHASE
end


"""
    conductance(::Type{MissingEdge}, phase_type::Type{T}) where {T <: Phases} = 0.0

Default conductance for subtypes of `AbstractEdge`
"""
function conductance(::Type{MissingEdge}, phase_type::Type{T}) where {T <: Phases}
    _default_admittances(phase_type)
end


"""
    susceptance(::Type{MissingEdge}, phase_type::Type{T}) where {T <: Phases} = 0.0

Default susceptance for subtypes of `AbstractEdge`
"""
function susceptance(::Type{MissingEdge}, phase_type::Type{T}) where {T <: Phases}
    _default_admittances(phase_type)
end


"""
    conductance_per_length(::Type{MissingEdge}) = 0.0

Default conductance_per_length for subtypes of `AbstractEdge`
"""
function conductance_per_length(::Type{MissingEdge}, phase_type::Type{T}) where {T <: Phases}
    _default_admittances(phase_type)
end


"""
    susceptance_per_length(::Type{MissingEdge}) = 0.0

Default susceptance_per_length for subtypes of `AbstractEdge`
"""
function susceptance_per_length(::Type{MissingEdge}, phase_type::Type{T}) where {T <: Phases}
    _default_admittances(phase_type)
end


"""
    bij(i::AbstractString, j::AbstractString, net::Network)

    susceptance(net[(i,j)])

susceptance of edge i-j
"""
function bij(i::AbstractString, j::AbstractString, net::Network)
    susceptance(net[(i,j)], network_phase_type(net))
end


"""
    bij(i::AbstractString, j::AbstractString, net:::Network{SinglePhase})

Scalar susceptance of edge i-j
"""
function bij(i::AbstractString, j::AbstractString, net::Network{SinglePhase})
    b = susceptance(net[(i,j)], network_phase_type(net))
    if isa(b, AbstractMatrix) 
        if size(b) == (1,1)
            return b[1,1]
        else
            throw(@error "Edge ($i, $j) has a multiphase admittance matrix in a single phase network.")
        end
    end
    return b
end


"""
    bij_per_unit(i::AbstractString, j::AbstractString, net::Network)

    susceptance(net[(i,j)]) * net.Zbase

susceptance of edge i-j normalized by `net.Zbase`
"""
function bij_per_unit(i::AbstractString, j::AbstractString, net::Network)
    bij(i, j, net) * net.Zbase
end


"""
    gij(i::AbstractString, j::AbstractString, net::Network)

conductance of edge i-j
"""
function gij(i::AbstractString, j::AbstractString, net::Network)
    conductance(net[(i,j)], network_phase_type(net))
end


"""
    gij(i::AbstractString, j::AbstractString, net:::Network{SinglePhase})

Scalar conductance of edge i-j
"""
function gij(i::AbstractString, j::AbstractString, net::Network{SinglePhase})
    g = conductance(net[(i,j)], network_phase_type(net))
    if isa(g, AbstractMatrix) 
        if size(g) == (1,1)
            return g[1,1]
        else
            throw(@error "Edge ($i, $j) has a multiphase conductance matrix in a single phase network.")
        end
    end
    return g
end


"""
    gij_per_unit(i::AbstractString, j::AbstractString, net::Network)

conductance of edge i-j normalized by `net.Zbase`
"""
function gij_per_unit(i::AbstractString, j::AbstractString, net::Network)
    gij(i, j, net) * net.Zbase
end


"""
    yij(i::AbstractString, j::AbstractString, net::Network)

admittance matrix of edge (i,j)
"""
function yij(i::AbstractString, j::AbstractString, net::Network)
    return conductance(net[(i, j)], network_phase_type(net)) + 
        susceptance(net[(i, j)], network_phase_type(net))im
end


"""
    yij_per_unit(i::AbstractString, j::AbstractString, net::Network{SinglePhase})

branch admittance of edge (i,j) in per-unit (multiplied with `net.Zbase`)
"""
function yij_per_unit(i::AbstractString, j::AbstractString, net::Network{SinglePhase})
    yij(i, j, net)[1, 1] * net.Zbase
end


"""
    yij(i::AbstractString, j::AbstractString, net::Network{SinglePhase})

branch admittance of edge (i,j)
"""
function yij(i::AbstractString, j::AbstractString, net::Network{SinglePhase})
    return conductance(net[(i, j)], network_phase_type(net))[1,1] + 
        im * susceptance(net[(i, j)], network_phase_type(net))[1,1]
end


"""
    yij_per_unit(i::AbstractString, j::AbstractString, net::Network)

branch admittance matrix of edge (i,j) in per-unit (multiplied with `net.Zbase`)
"""
function yij_per_unit(i::AbstractString, j::AbstractString, net::Network)
    yij(i, j, net) * net.Zbase
end


"""
    conductance_per_length(c::Conductor, phase_type::Type{T}) where {T <: Phases}

If `phase_type` is `SinglePhase` then return scalar conductance per unit length,
else return 3x3 matrix of conductance per unit length.

    if phase_type == SinglePhase
        return c.r1 / (c.length^2 * (c.r1^2 + c.x1^2))
    end
    return real(inverse_matrix_with_zeros(c.rmatrix + im * c.xmatrix)) / c.length^2

"""
function conductance_per_length(c::Conductor, phase_type::Type{T}) where {T <: Phases}
    if phase_type == SinglePhase
        return make_nan_or_inf_zero(c.r1 / (c.length^2 * (c.r1^2 + c.x1^2)))
    end
    return real(inverse_matrix_with_zeros(c.rmatrix + im * c.xmatrix)) / c.length^2
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
        return make_nan_or_inf_zero(-c.x1 / (c.length^2 * (c.r1^2 + c.x1^2)))
    end
    return imag(inverse_matrix_with_zeros(c.rmatrix + im * c.xmatrix)) / c.length^2
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
    _parallel_admittance(pc::ParallelConductor, phase_type::Type{SinglePhase})

Admittance of multiple conductors in parallel for a single phase network.
"""
function _parallel_admittance(pc::ParallelConductor, phase_type::Type{SinglePhase})
    y = zero(ComplexF64)
    for c in pc.conductors
        z = resistance(c, phase_type) + im * reactance(c, phase_type)
        y += 1 / z
    end
    return y
end

"""
    _parallel_admittance(pc::ParallelConductor, phase_type::Type{MultiPhase})

Admittance matrix of parallel conductors for a multiphase network.
"""
function _parallel_admittance(pc::ParallelConductor, phase_type::Type{MultiPhase})
    Y = zeros(ComplexF64, 3, 3)
    for c in pc.conductors
        z = resistance(c, phase_type) + im * reactance(c, phase_type)
        Y .+= inverse_matrix_with_zeros(z)
    end
    return Y
end

function conductance_per_length(pc::ParallelConductor, phase_type::Type{T}) where {T <: Phases}
    y = _parallel_admittance(pc, phase_type)
    g = real(y) / pc.length
    return g
end

function conductance(pc::ParallelConductor, phase_type::Type{T}) where {T <: Phases}
    real(_parallel_admittance(pc, phase_type))
end

function susceptance_per_length(pc::ParallelConductor, phase_type::Type{T}) where {T <: Phases}
    y = _parallel_admittance(pc, phase_type)
    b = imag(y) / pc.length
    return b
end

function susceptance(pc::ParallelConductor, phase_type::Type{T}) where {T <: Phases}
    imag(_parallel_admittance(pc, phase_type))
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
        return make_nan_or_inf_zero(vr.resistance / (vr.resistance.^2 + vr.reactance.^2))
    end
    return real(inverse_matrix_with_zeros(vr.rmatrix + im * vr.xmatrix))
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
        return make_nan_or_inf_zero(-vr.reactance / (vr.resistance.^2 + vr.reactance.^2))
    end
    return imag(inverse_matrix_with_zeros(vr.rmatrix + im * vr.xmatrix))
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
        return make_nan_or_inf_zero(trfx.resistance / (trfx.resistance^2 + trfx.reactance^2))
    end
    return real(inverse_matrix_with_zeros(trfx.rmatrix + im * trfx.xmatrix))
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
        return make_nan_or_inf_zero(-trfx.reactance / (trfx.resistance^2 + trfx.reactance^2))
    end
    return imag(inverse_matrix_with_zeros(trfx.rmatrix + im * trfx.xmatrix))
end
