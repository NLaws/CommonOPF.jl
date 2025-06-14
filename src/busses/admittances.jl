"""
    Yij(
        i::AbstractString, 
        j::AbstractString, 
        net::CommonOPF.Network
    )::Union{ComplexF64, Matrix{ComplexF64}}

Returns either:
- entry of bus admittance matrix at i,j for single phase networks or
- 3x3 sub-matrix of bus admittance matrix for the phases connecting busses i and j
"""
function Yij(
        i::AbstractString, 
        j::AbstractString, 
        net::CommonOPF.Network
    )::Union{ComplexF64, Matrix{ComplexF64}}
    if i != j
        return -1 .* yij(i, j, net)
    end
    # sum up the y_jk where k is connected to j
    g, b = 0, 0
    for k in connected_busses(j, net)
        y = yij(i, k, net)
        g += real(y)
        b += imag(y)
    end
    return g + im * b + yj(j, net)
end
"""
    Yij_per_unit(
        i::AbstractString, 
        j::AbstractString, 
        net::CommonOPF.Network
    )::Union{ComplexF64, Matrix{ComplexF64}}

Returns either:
- entry of bus admittance matrix at i,j for single phase networks or
- 3x3 sub-matrix of bus admittance matrix for the phases connecting busses i and j
(multiplied with `net.Zbase`)
"""
function Yij_per_unit(
        i::AbstractString, 
        j::AbstractString, 
        net::CommonOPF.Network
    )::Union{ComplexF64, Matrix{ComplexF64}}
    if i != j
        return -1 .* yij_per_unit(i, j, net)
    end
    # sum up the y_jk where k is connected to j
    g, b = 0, 0
    for k in connected_busses(j, net)
        y = yij_per_unit(i, k, net)
        g += real(y)
        b += imag(y)
    end
    return g + im * b + yj(j, net)
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

    # TODO preallocate arrays
    # construct, I, J, and V  (rows, cols, vals)

    # TODO don't include row/cols of non-existent phases (currently assume 3 phases throughout)
    bs = busses(net)
    rows, cols = Int64[], Int64[]
    vals = ComplexF64[]
    N = length(bs) * 3
    i, j = 0, 0

    # TODO how to make this faster? Takes ~8 minutes for 8500 node system
    # Y is symmetric so we only create the upper triangular values
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
