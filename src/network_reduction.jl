"""
    reduce_tree!(net::Network{SinglePhase})

combine any line sets with intermediate busses that have indegree == outdegree == 1
and is not a load bus into a single line

See `remove_bus!` for how the two lines are combined.
"""
function reduce_tree!(net::Network)
    g = net.graph
    int_bus_map = g[][:int_bus_map]
    reducable_buses = String[]
    ld_busses = load_busses(net)
    for v in MetaGraphsNext.vertices(g)  # we need integer vertex for in/outdegree methods
        if !(MetaGraphsNext.indegree(g, v) == MetaGraphsNext.outdegree(g, v) == 1)
            continue
        end
        bus = int_bus_map[v]
        edge_ij = net[(i_to_j(bus, net)[1], bus)]
        edge_jk = net[(bus, j_to_k(bus, net)[1])]
        phases_ij = ismissing(edge_ij.phases) ? [1] : edge_ij.phases
        phases_jk = ismissing(edge_jk.phases) ? [1] : edge_jk.phases
        if ( # we have two and only two conductors at the bus and phases match
            !(bus in ld_busses) && 
            typeof(edge_ij) == CommonOPF.Conductor == typeof(edge_jk) &&
            phases_ij == phases_jk
        )
            # TODO do not include a bus if it contains any subtype of AbstractBus?
            push!(reducable_buses, bus)
        end
    end
    @debug("Removing the following busses: \n$reducable_buses")
    # replace two lines with one
    for j in reducable_buses
        remove_bus!(j, net)
    end
    @info("Removed $(length(reducable_buses)) busses.")
end
# TODO reduce_tree!(net::Network{MultiPhase})


"""
    remove_bus!(j::String, net::Network{SinglePhase})

Remove bus `j` in the line i->j->k from the model by making an equivalent line from busses i->k
"""
function remove_bus!(j::String, net::Network{SinglePhase})
    # get all the old values
    i, k = i_to_j(j, net)[1], j_to_k(j, net)[1]
    c1, c2 = net[(i, j)], net[(j, k)]
    @assert typeof(c1) == CommonOPF.Conductor == typeof(c2) "remove_bus! can only combine two conductors"
    # make the new values
    r_ik = resistance(c1) + resistance(c2)
    x_ik = reactance(c1)  + reactance(c2)
    ik_len = c1.length + c2.length
    # delete the old values
    delete!(net.graph, i, j)
    delete!(net.graph, j, k)
    delete!(net.graph, j)
    # add the new values

    net[(i, k)] = CommonOPF.Conductor(;
        name = "line_from_removing_bus_$j",
        busses = (i, k),
        length = ik_len,
        r1 = r_ik / ik_len,
        x1 = x_ik / ik_len,
    )
    nothing
    # TODO assign amperage for new line as minimum amperage of the two joined lines
end


"""
    remove_bus!(j::String, net::Network{MultiPhase})

Remove bus `j` in the line i->j->k from the model by making an equivalent line from busses i->k.
We assume the conductors from i->j and j->k have impedance matrices.
"""
function remove_bus!(j::String, net::Network{MultiPhase})
    # get all the old values
    i, k = i_to_j(j, net)[1], j_to_k(j, net)[1]
    c1, c2 = net[(i, j)], net[(j, k)]
    @assert typeof(c1) == CommonOPF.Conductor == typeof(c2) "remove_bus! can only combine two conductors"
    @assert c1.phases == c2.phases "remove_bus! only works with two conductors that have matching phases"
    # make the new values
    rmatrix_ik = resistance(c1) + resistance(c2)
    xmatrix_ik = reactance(c1)  + reactance(c2)
    ik_len = c1.length + c2.length
    # delete the old values
    delete!(net.graph, i, j)
    delete!(net.graph, j, k)
    delete!(net.graph, j)
    # add the new values

    net[(i, k)] = CommonOPF.Conductor(;
        name = "line_from_removing_bus_$j",
        busses = (i, k),
        length = ik_len,
        rmatrix = rmatrix_ik / ik_len,
        xmatrix = xmatrix_ik / ik_len,
        phases = c1.phases
    )
    nothing
    # TODO assign amperage for new line as minimum amperage of the two joined lines
end


"""
    trim_tree_once!(net::Network)

A support function for `trim_tree!`, `trim_tree_once!` removes all the empty leaf busses. When
trimming the tree sometimes new leafs are created. So `trim_tree!` loops over `trim_tree_once!`.
"""
function trim_tree_once!(net::Network)
    trimmable_busses = [
        b for b in leaf_busses(net) if isempty(net[b])
    ]
    if isempty(trimmable_busses) return false end
    trimmable_edges = Tuple[]
    for j in trimmable_busses
        for i in i_to_j(j, net)
            push!(trimmable_edges, (i,j))
        end
    end
    @debug("Deleting the following edges from the net.graph:")
    for edge in trimmable_edges @debug(edge) end
    for (i, j) in trimmable_edges
        delete!(net.graph, i, j)
    end
    for i in trimmable_busses
        delete!(net.graph, i)
    end
    true
end


"""
    trim_tree!(net::Network)

Trim any branches that have empty busses, i.e. remove the branches that have no loads or DER.
"""
function trim_tree!(net::Network)
    n_edges_before = length(collect(edges(net)))
    trimming = trim_tree_once!(net)
    while trimming
        trimming = trim_tree_once!(net)
    end
    n_edges_after = length(collect(edges(net)))
    @info("Removed $(n_edges_before - n_edges_after) edges.")
    true
end