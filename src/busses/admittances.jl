"""
    Yij(
        i::AbstractString, 
        j::AbstractString, 
        net::CommonOPF.Network{SinglePhase}
    )::ComplexF64

Returns entry of bus admittance matrix at i,j for single phase networks 
"""
function Yij(
        i::AbstractString, 
        j::AbstractString, 
        net::CommonOPF.Network{SinglePhase}
    )::ComplexF64
    if i != j
        return -1 .* yij(i, j, net)
    end
    # sum up the y_ik where k is connected to i (which equals j)
   y_total = 0im
    for k in connected_busses(i, net)
        y_total += yij(i, k, net)
    end
    return y_total + yj_per_unit(i, net)
end


"""
    Yij_per_unit(
        i::AbstractString, 
        j::AbstractString, 
        net::CommonOPF.Network{SinglePhase}
    )::ComplexF64

Returns entry of bus admittance matrix at i,j in per-unit (multiplied with `net.Zbase`)
"""
function Yij_per_unit(
        i::AbstractString, 
        j::AbstractString, 
        net::CommonOPF.Network{SinglePhase}
    )::ComplexF64
    if i != j
        return -1 .* yij_per_unit(i, j, net)
    end
    # sum up the y_ik where k is connected to i (which equals j)
    y_total = 0im
    for k in connected_busses(i, net)
        y_total += yij_per_unit(i, k, net)
    end
    return y_total + yj(j, net)
end


"""
    Yij(
        i::AbstractString, 
        j::AbstractString, 
        net::CommonOPF.Network{MultiPhase}
    )::Matrix{ComplexF64}

Returns N_phase x N_phase sub-matrix of bus admittance matrix for the phases connecting busses i and
j

!!! warning The branch admittance methods like `yij` always return 3x3 matrices regardless of the
    phases in `net[(i, j)].phases`. This is because it is easier to build the OPF models if we have
    consistently sized vectors and matrices. However, for the BIM that use the bus admittance
    matrix, it is simpler to exclude the non-existent phases and define variables with the same size
    and indices as the bus admittance matrix.
"""
function Yij(
        i::AbstractString, 
        j::AbstractString, 
        net::CommonOPF.Network{MultiPhase}
    )::Matrix{ComplexF64}
    if i != j
        edge_phases = net[(i,j)].phases
        return -1 .* yij(i, j, net)[edge_phases, edge_phases]
    end
    # sum up the y_jk where k is connected to i (which equals j)
    phases = phases_connected_to_bus(net, i)
    n_phases = length(phases_connected_to_bus(net, i))
    y_total = zeros(Complex, (n_phases, n_phases))
    for k in connected_busses(i, net)
        # yij is always 3x3; we slice down to the connected phases
        # TODO test this
        y_total += yij(i, k, net)[phases, phases]
    end
    # add the shunt admittance
    return y_total + yj(i, net)[phases, phases]
end
# TODO Yij_per_unit for Network{MultiPhase} (maybe use it in Ysparse)


"""
    function Ysparse(net::CommonOPF.Network)::SparseArrays.SparseMatrixCSC

Returns a Symmetric view of sparse upper triangular matrix.
"""
function Ysparse(net::CommonOPF.Network)::Tuple{Symmetric, Vector{BusTerminal}}
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
    bus_terminals, edge_terminals = terminal_maps(net)
    # number of non-zero Y entries
    n_vals = sum([length(terms)^2 for terms in values(bus_terminals)]) + 
        sum([length(terms.bus1_terminals)^2 for terms in values(edge_terminals)])

    rows, cols = Vector{Int64}(undef, n_vals), Vector{Int64}(undef, n_vals)
    vals = Vector{ComplexF64}(undef, n_vals)

    # unpack the diagonal matrices into the sparse format
    # TODO only need the upper triangle values in the following loops
    # TODO check test coverage
    i = 1
    for (b, terms) in bus_terminals
        y = Yij(b, b, net)
        # The y values are in phase order, as well as the terms
        for (i1, term1) in enumerate(terms), (i2, term2) in enumerate(terms)
            rows[i] = term1.Y_index
            cols[i] = term2.Y_index
            vals[i] = y[i1, i2]  # indexing a number at [1,1] gives the number (SinglePhase case)
            i += 1
        end
    end

    # unpack the off-diagonal matrices into the sparse format
    for edge_terminal in values(edge_terminals)
        (b1, b2) = edge_terminal.busses
        y = Yij(b1, b2, net)
        for (i1, term1) in enumerate(edge_terminal.bus1_terminals), 
            (i2, term2) in enumerate(edge_terminal.bus2_terminals)
            
            # make sure that we only fill in upper triangle values
            if term1.Y_index < term2.Y_index
                rows[i] = term1.Y_index
                cols[i] = term2.Y_index
            else
                rows[i] = term2.Y_index
                cols[i] = term1.Y_index
            end
            vals[i] =  y[i1, i2]
            i += 1
        end
    end

    # size of Y
    N = sum([length(terms) for terms in values(bus_terminals)])

    return Symmetric(sparse(rows, cols, vals, N, N)), terminals(net)
end
