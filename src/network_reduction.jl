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

    new_conductor = CommonOPF.Conductor(;
        name = "line_from_removing_bus_$j",
        busses = (i, k),
        length = ik_len,
        r1 = r_ik / ik_len,
        x1 = x_ik / ik_len,
    )
    try 
        net[(i, k)]
    catch KeyError
        net[(i, k)] = new_conductor
        return true
    else
        @error "Network already has conductor at $((i, k)). Returning new Conductor."
        return new_conductor
    end
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
    new_conductor = CommonOPF.Conductor(;
        name = "line_from_removing_bus_$j",
        busses = (i, k),
        length = ik_len,
        rmatrix = rmatrix_ik / ik_len,
        xmatrix = xmatrix_ik / ik_len,
        phases = c1.phases
    )
    try 
        net[(i, k)]
    catch KeyError
        net[(i, k)] = new_conductor
        return true
    else
        @error "Network already has conductor at $((i, k)). Returning new Conductor."
        return new_conductor
    end
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


"""
    check_paths_for_loads(paths::AbstractVecOrMat, net::Network)

paths is vector of vectors containing bus names for parallel lines.
if any load busses are in the paths then an error is thrown because we are not handling that case yet.
"""
function check_paths_for_loads(paths::AbstractVecOrMat, net::Network)
    for path in paths, bus in path
        if bus in load_busses(net)
            throw("At least one load bus is in the parallel lines: not merging.")
        end
    end
    true
end


"""
    combine_parallel_lines!(net::Network)

Combine any parallel single phase lines without loads on intermediate busses into one multiphase 
line. This method is useful for making a mesh network radial when the mesh components are products of
modeling single phase voltage regulators in load flow software such as OpenDSS.

"""
function combine_parallel_lines!(net::Network{MultiPhase})
    g = net.graph  # TODO graph has to be directed
    end_bs = busses_with_multiple_inneighbors(g)
    # TODO assert that the lines to be combined have all the phases coming in
    for b2 in end_bs
        ins = inneighbors(g, b2)
        start_bs = unique(
            next_bus_above_with_outdegree_more_than_one.(repeat([g], length(ins)), ins)
        )
        if length(start_bs) == 1
            # we have a start bus and end bus to merge lines (if none of the intermediate busses have loads)
            b1 = start_bs[1]
            paths = paths_between(g, b1, b2)
            check_paths_for_loads(paths, net)
            # confirm separate phases on each path
            phase_int = 0
            for path in paths
                phases_path_start = net[(b1, path[1])].phases
                @assert length(phases_path_start) == 1 "Can only combine single phase lines."
                @assert phases_path_start[1] != phase_int "Cannot combine parallel lines of the same phase."
                phase_int = phases_path_start[1]
                previous_b = b1
                for b in path
                    @assert length(net[(previous_b, b)].phases) == 1 "Can only combine single phase lines."
                    @assert net[(previous_b, b)].phases[1] == phase_int "A conductor changes phases at bus $previous_b"
                    previous_b = b
                end
            end
            # remove all the intermdiate busses s.t. we have two // lines from b1 to b2
            # Graphs.jl does not support multi-edges, so we collect the extra edges returned from remove_bus!
            extra_conductors = CommonOPF.Conductor[]
            for path in paths
                for b in path
                    ret_val = remove_bus!(b, net)
                    if isa(ret_val, CommonOPF.Conductor)
                        push!(extra_conductors, ret_val)
                    end
                end
            end
            # now we combine the two // lines into one
            @assert length(extra_conductors) in [1,2] "Found more than three parallel lines between busses $b1 and $b2!"
            if length(extra_conductors) == 1
                c1, c2 = net[(b1, b2)], extra_conductors[1]
                # amps1, amps2 = p.Isquared_up_bounds[linecode1], p.Isquared_up_bounds[linecode2]
                # new values
                new_len = (c1.length + c2.length) / 2
                new_rmatrix = (resistance(c1) + resistance(c2)) ./ new_len
                new_xmatrix = (reactance(c1) + reactance(c2)) ./ new_len
                new_phases = sort([c1.phases[1], c2.phases[1]])
                
                # add the new values
                net[(b1, b2)] = CommonOPF.Conductor(;
                    name = "combined_parallel_lines_from_$(b1)_to_$(b2)",
                    busses = (b1, b2),
                    length = new_len,
                    rmatrix = new_rmatrix,
                    xmatrix = new_xmatrix,
                    phases = new_phases
                )
                # p.Isquared_up_bounds[new_linecode] = (amps1 + amps2) / 2
            else  # 3 lines to combine
                c1, c2, c3 = net[(b1, b2)], extra_conductors[1], extra_conductors[2]
                # amps1, amps2 = p.Isquared_up_bounds[linecode1], p.Isquared_up_bounds[linecode2]
                # new values
                new_len = (c1.length + c2.length + c3.length) / 3
                new_rmatrix = (resistance(c1) + resistance(c2) + resistance(c3)) ./ new_len
                new_xmatrix = (reactance(c1) + reactance(c2) + reactance(c3)) ./ new_len
                
                net[(b1, b2)] = CommonOPF.Conductor(;
                    name = "combined_parallel_lines_from_$(b1)_to_$(b2)",
                    busses = (b1, b2),
                    length = new_len,
                    rmatrix = new_rmatrix,
                    xmatrix = new_xmatrix,
                    phases = [1, 2, 3]
                )
                # p.Isquared_up_bounds[new_linecode] = (amps1 + amps2) / 2
            end
            @info "Made new combined line between busses $b1 and $b2"
        end
    end
end


"""
    trim_above_bus!(g::MetaGraphsNext.MetaGraph, bus::String)

Remove all the busses and edges that are inneighbors (recursively) of `bus`
"""
function trim_above_bus!(g::MetaGraphsNext.MetaGraph, bus::String)
    busses_to_delete = all_inneighbors(g, bus, Vector{String}())
    edges_to_delete = [e for e in MetaGraphsNext.edge_labels(g) if e[1] in busses_to_delete]
    for (i, j) in edges_to_delete
        delete!(g, i, j)
    end
    for i in busses_to_delete
        delete!(g, i)
    end
end
