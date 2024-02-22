"""
    function make_sub_network(
        net::Network, 
        edges_to_delete::Vector, 
        busses_to_delete::Vector{String}
    )

Support method for `split_network`. Copy `net` and delete edges and busses.
"""
function make_sub_network(
    net::Network, 
    edges_to_delete::Vector, 
    busses_to_delete::Vector{String}
    )
    net_copy = deepcopy(net)
    for e in edges_to_delete
        MetaGraphsNext.delete!(net_copy.graph, e[1], e[2])
    end
    for b in busses_to_delete
        MetaGraphsNext.delete!(net_copy.graph, b)
    end
    return net_copy
end


"""
    split_network(net::Network, bus::String)::Tuple{Network, Network}

Split `net` into one `Network` for everything above `bus` and one `Network` for everything
    below `bus`.
"""
function split_network(net::Network, bus::String)::Tuple{Network, Network}
    g = net.graph
    in_buses = collect(all_inneighbors(g, bus, String[]))
    out_busses = collect(all_outneighbors(g, bus, String[], String[]))
    # in/out_busses do not have bus, but sub_busses does have bus
    # we want to keep bus in both Inputs

    sub_busses, sub_edges = induced_subgraph(g, vcat(out_busses, bus))
    net_above = make_sub_network(net, sub_edges, out_busses)

    sub_busses, sub_edges = induced_subgraph(g, vcat(in_buses, bus))
    net_below = make_sub_network(net, sub_edges, in_buses)
    net_below.substation_bus = bus

    return net_above, net_below
end


"""
    split_inputs(net::Network, bus::String, out_busses::Vector{String})::Tuple{Network, Network}

Split `net` into `net_above` and `net_below` where `net_below` has only `out_busses` and `net_above` 
has `union( [bus], setdiff(busses(net), out_busses) )`.

Note that `out_busses` must contain `bus`
"""
function split_network(net::Network, bus::String, out_busses::Vector{String})::Tuple{Network, Network}
    if !(bus in out_busses)
        throw(@error "Cannot split network: bus is not in out_busses.")
    end
    g = net.graph
    in_buses = setdiff(busses(net), out_busses)
    # in_buses does not have bus, but sub_busses does have bus
    # we want to keep bus in both net_above and net_below

    sub_busses, edges_to_remove = induced_subgraph(g, out_busses)
    # NOTE edges_to_remove does not include edges going out of out_busses
    net_above = make_sub_network(net, edges_to_remove, setdiff(out_busses, [bus]))

    sub_busses, edges_to_remove = induced_subgraph(g, vcat(in_buses, bus))
    net_below = make_sub_network(net, edges_to_remove, in_buses)
    net_below.substation_bus = bus

    return net_above, net_below
end


# NEXT split_at_busses (moving decomposition support to CommonOPF from BFM)