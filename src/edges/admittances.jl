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


function _default_admittances(phase_type::Type{T}) where {T <: Phases}
    if phase_type == SinglePhase
        return 0.0
    end
    return zeros(3, 3)
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

admittance of edge (i,j) in per-unit (multiplied with `net.Zbase`)
"""
function yij_per_unit(i::AbstractString, j::AbstractString, net::Network{SinglePhase})
    yij(i, j, net)[1, 1] * net.Zbase
end


"""
    yij(i::AbstractString, j::AbstractString, net::Network{SinglePhase})

admittance of edge (i,j)
"""
function yij(i::AbstractString, j::AbstractString, net::Network{SinglePhase})
    return conductance(net[(i, j)], network_phase_type(net))[1,1] + 
        im * susceptance(net[(i, j)], network_phase_type(net))[1,1]
end


"""
    yij_per_unit(i::AbstractString, j::AbstractString, net::Network)

admittance matrix of edge (i,j) in per-unit (multiplied with `net.Zbase`)
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


"""
    Yij(i::AbstractString, j::AbstractString, net::CommonOPF.Network)::Union{ComplexF64, Matrix{ComplexF64}}

Returns either:
- entry of bus admittance matrix at i,j for single phase networks or
- 3x3 sub-matrix of bus admittance matrix for the phases connecting busses i and j
"""
function Yij(i::AbstractString, j::AbstractString, net::CommonOPF.Network)::Union{ComplexF64, Matrix{ComplexF64}}
    if i != j
        return -1 .* yij(i, j, net)
    end
    # TODO shunt impedance
    # sum up the y_jk where k is connected to j
    g, b = 0, 0
    for k in connected_busses(j, net)
        y = yij(i, k, net)
        g += real(y)
        b += imag(y)
    end
    return g + im * b
end


"""
    Yij_per_unit(i::AbstractString, j::AbstractString, net::CommonOPF.Network)::Union{ComplexF64, Matrix{ComplexF64}}

Returns either:
- entry of bus admittance matrix at i,j for single phase networks or
- 3x3 sub-matrix of bus admittance matrix for the phases connecting busses i and j
(multiplied with `net.Zbase`)
"""
function Yij_per_unit(i::AbstractString, j::AbstractString, net::CommonOPF.Network)::Union{ComplexF64, Matrix{ComplexF64}}
    if i != j
        return -1 .* yij_per_unit(i, j, net)
    end
    # TODO shunt impedance
    # sum up the y_jk where k is connected to j
    g, b = 0, 0
    for k in connected_busses(j, net)
        y = yij_per_unit(i, k, net)
        g += real(y)
        b += imag(y)
    end
    return g + im * b
end


"""
    function Ysparse(net::CommonOPF.Network)::SparseArrays.SparseMatrixCSC

Returns a Symmetric view of sparse upper triangular matrix
"""
function Ysparse(net::CommonOPF.Network{MultiPhase})::Tuple{Symmetric, Vector{String}}
    # docstring for sparse:
    # sparse(I, J, V,[ m, n, combine])

    # Create a sparse matrix S of dimensions m x n such that S[I[k], J[k]] = V[k]. The combine
    # function is used to combine duplicates. If m and n are not specified, they are set to
    # maximum(I) and maximum(J) respectively. If the combine function is not supplied, combine
    # defaults to + unless the elements of V are Booleans in which case combine defaults to |. All
    # elements of I must satisfy 1 <= I[k] <= m, and all elements of J must satisfy 1 <= J[k] <= n.
    # Numerical zeros in (I, J, V) are retained as structural nonzeros; to drop numerical zeros, use
    # dropzeros!.

    # construct, I, J, and V  (rows, cols, vals)
    bs = busses(net)
    rows, cols = Int64[], Int64[]
    vals = ComplexF64[]
    N = length(bs) * 3
    i, j = 0, 0

    # TODO how to make this faster? Takes ~8 minutes for 8500 node system
    # Y is symmetric
    for (b1_index, bus1) in enumerate(bs)
        for bus2 in bs[b1_index:end]

            if net[(bus1, bus2)] == MissingEdge
                j += 3  # for three phases
                continue
            end

            y = Yij(bus1, bus2, net)
            for ii in 1:3, jj in 1:3  # for three phases
                if isapprox(y[ii, jj], 0.0)
                    continue
                end
                push!(vals, y[ii, jj])
                push!(rows, i + ii)
                push!(cols, j + jj)
            end
            j += 3  # for three phases
        end
        # column tracker, would reset to zero if doing a full matrix
        j = b1_index * 3
        i += 3
    end
    nodes = vec([
        bus * phs for phs in [".1", ".2", ".3"], bus in busses(net)
    ])

    return Symmetric(sparse(rows, cols, vals, N, N)), nodes
end
