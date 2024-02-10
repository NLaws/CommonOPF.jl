"""
    reduce_tree!(net::Network{SinglePhase})

combine any line sets with intermediate busses that have indegree == outdegree == 1
and is not a load bus into a single line

See `remove_bus!` for how the two lines are combined.
"""
function reduce_tree!(net::Network{SinglePhase})
    # TODO MultiPhase
    g = net.graph
    int_bus_map = g[][:int_bus_map]
    reducable_buses = String[]
    ld_busses = load_busses(net)
    for v in MetaGraphsNext.vertices(g)  # we need integer vertex for in/outdegree methods
        bus = int_bus_map[v]
        if ( # we have two and only two conductors at the bus
            !(bus in ld_busses) && 
            MetaGraphsNext.indegree(g, v) == MetaGraphsNext.outdegree(g, v) == 1 &&
            typeof(net[(i_to_j(bus, net)[1], bus)]) == CommonOPF.Conductor == typeof(net[(bus, j_to_k(bus, net)[1])])
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
    MetaGraphsNext.delete!(net.graph, i, j)
    MetaGraphsNext.delete!(net.graph, j, k)
    MetaGraphsNext.delete!(net.graph, j)
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
