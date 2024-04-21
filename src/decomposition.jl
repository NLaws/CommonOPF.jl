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
    # we want to keep bus in both Networks

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


"""
    init_split_networks!(nets::Vector{Network{SinglePhase}}; init_vs::Dict = Dict())

Set the load on the upstream leaf noades equal to the sum of all the loads in the
downstream inputs. It is important that the order of `nets` is from leaf branches to trunk branches
so that the sums of loads take into account all downstream sub-trees.

if `init_vs` is provided, the `net.v0` is set for the `Input` with its `net.substation_bus` equal 
    to the key in `init_vs`
```julia
init_vs = Dict(
    "sub_bus_1" => 0.98
)

for net in nets
    if net.substation_bus in keys(init_vs)
        net.v0 = init_vs[net.substation_bus]
    end
end
```
"""
function init_split_networks!(nets::Vector{Network{SinglePhase}}; init_vs::Dict = Dict())
    for net in nets
        if net.substation_bus in keys(init_vs)
            net.v0 = init_vs[net.substation_bus]
        end
        leafs = CommonOPF.leaf_busses(net)
        for other_net in nets
            if other_net.substation_bus in leafs
                if isempty(load_busses(other_net))
                    @warn "The sub network with head bus $(other_net.substation_bus) has no load busses.\
                    \nThis indicates that there are probably lines with no loads on the ends in the larger network.\
                    \nTry using CommonOPF.trim_tree! to eliminate the deadend branches."
                else
                    if other_net.substation_bus in load_busses(net)
                        net[other_net.substation_bus][:Load].kws1 += total_load_kw(other_net)
                        net[other_net.substation_bus][:Load].kvars1 += total_load_kvar(other_net)
                    else
                        net[other_net.substation_bus][:Load] = CommonOPF.Load(;
                            bus=other_net.substation_bus,
                            kws1=total_load_kw(other_net),
                            kvars1=total_load_kvar(other_net),
                        )
                    end
                end
            end
        end
    end
    true
end


"""
    init_split_networks!(mg::MetaGraphsNext.MetaGraph; init_vs::Dict = Dict())

Use the `:load_sum_order` in `mg` to `init_split_networks!` in the correct order, i.e. set the loads
at the leaf - substation connections as sums of all the loads (and the voltages at substations)
"""
function init_split_networks!(mg::MetaGraphsNext.MetaGraph; init_vs::Dict = Dict())
    lso = mg.graph_data[:load_sum_order]
    nets = [mg[v] for v in lso]
    init_split_networks!(nets; init_vs = init_vs)
end


"""
    connect_subgraphs_at_busses(net::Network{SinglePhase}, at_busses::Vector{String}, subgraphs::Vector{Vector})

The splitting_busses algorithm does not include over laps in subgraphs.
But, we want overlaps at the splitting busses for solving the decomposed branch flow model.
So here we add the overlapping splitting busses to each sub graph.
"""
function connect_subgraphs_at_busses(net::Network{SinglePhase}, at_busses::Vector{String}, subgraphs::Vector{Vector})
    g = net.graph
    new_subgs = deepcopy(subgraphs)
    for (i, subgraph) in enumerate(subgraphs)
        for b in subgraph
            bs_to_add = intersect(outneighbors(g, b), at_busses)
            if !isempty(bs_to_add)
                for ba in bs_to_add
                    if !(ba in new_subgs[i])
                        push!(new_subgs[i], ba)
                    end
                end
            end
        end
    end
    return new_subgs
end


"""
    splitting_busses(net::Network, source::String; threshold::Int64=10)

Determine the busses to split a tree graph on by searching upward from the deepest leafs first
and gathering the nearest busses until threshold is met for each subgraph.

Returns a `Vector{String}` for the bus names to split on and `Vector{Vector{String}}` for the 
corresponding busses within each sub-graph.

!!! note
    It is not enough to have only the splitting busses to obey the `max_busses` limit because
    one must also know which sub branches to take from each splitting bus. In other words, we also
    need all the busses within each subgraph to split properly. For example, if a splitting
    bus has two sub branches then obeying the max_busses limit can require only including one
    sub branch out of the splitting bus. To know which branch to take we can use the other busses
    in the sub graph (which is why this method also returns the bussed in each subgraph).
"""
function splitting_busses(net::Network, source::String; max_busses::Int64=10)
    g = net.graph
    @assert Graphs.is_directed(net.graph)  "net.graph must be directed"
    bs, depths = busses_from_deepest_to_source(g, source)
    splitting_bs = String[]  # head nodes of all the subgraphs
    subgraph_bs = Vector[]
    # iterate until bs is empty, taking out busses as they are added to subgraphs
    subg_bs = String[]
    bs_parsed = String[]
    while !isempty(bs)
        b = popfirst!(bs)
        push!(subg_bs, b)
        ins = [b] # first check for any out neighbors of b
        while length(ins) == 1  # moving up tree from b in this loop
            inb = ins[1]
            # outns includes every bus below inb, 
            # excluding any branches that start with a bus in bs_parsed
            outns = all_outneighbors(g, inb, String[], bs_parsed)
            setdiff!(outns, bs_parsed)  # just in case
            new_subg_bs = unique(vcat([inb], outns, subg_bs))

            if length(new_subg_bs) > max_busses || isempty(bs)
                # addition of busses would increase busses in subgraph beyond max_busses
                # so we split at b and start a new subgraph
                push!(splitting_bs, b)
                push!(bs_parsed, subg_bs...)
                push!(subgraph_bs, subg_bs)
                bs = setdiff(bs, subg_bs)
                subg_bs = String[]
                break  # inner loop
            end
            # else continue going up tree
            subg_bs = new_subg_bs
            bs = setdiff(bs, subg_bs)
            ins = inneighbors(g, inb)  # go up another level
            b = inb
        end
    end
    if source in splitting_bs
        # the last bus in splitting_bs is the source, which is not really a splitting bus
        return setdiff(splitting_bs, [source]), subgraph_bs[1:end-1]
    end
    return splitting_bs, subgraph_bs
end


"""
    split_at_busses(net::Network, at_busses::Vector{String})

Split `net.graph` using the `at_busses`

returns directed `MetaGraph` with vertices containing `Network` for the sub-graphs using integer 
vertex labels. For example `mg[2]` is the `Network` at the second vertex of the graph created by 
splitting the network via the `at_busses`.
"""
function split_at_busses(net::Network, at_busses::Vector{String})::MetaGraphsNext.MetaGraph
    unique!(at_busses)
    mg = MetaGraphsNext.MetaGraph(
        Graphs.DiGraph(), 
        label_type=Integer,
        vertex_data_type=Network,
        graph_data=Dict{Symbol, Any}()
    )
    # initial split
    net_above, net_below = split_network(net, at_busses[1]);
    MetaGraphsNext.add_vertex!(mg, 1, net_above)
    MetaGraphsNext.add_vertex!(mg, 2, net_below)
    MetaGraphsNext.add_edge!(mg, 1, 2)

    for (i, splitting_bus) in enumerate(at_busses[2:end])
        # find the vertex in mg to split
        vertex = 0
        for v in MetaGraphsNext.vertices(mg)
            if splitting_bus in busses(mg[v])
                vertex = v
                break
            end
        end
        net_above, net_below = split_network(mg[vertex], splitting_bus);
        mg[vertex] = net_above  # replace the already set net, which preserves inneighbors
        MetaGraphsNext.add_vertex!(mg, i+2, net_below)  # vertex i+2
        if !isempty(MetaGraphsNext.outdegree(mg, vertex))
            # already have edge(s) for vertex -> outneighbors(mg, vertex)
            # but now i+2 could be the parent for some of the outneighbors(mg, vertex)
            outns = copy(MetaGraphsNext.outneighbors(mg, vertex))
            for neighb in outns
                if !( mg[neighb].substation_bus in busses(mg[vertex]) )
                    # mv the edge to the new intermediate node
                    MetaGraphsNext.rem_edge!(mg, vertex, neighb)
                    MetaGraphsNext.add_edge!(mg, i+2, neighb)
                end
            end
        end
        MetaGraphsNext.add_edge!(mg, vertex, i+2)  # net_above -> net_below
    end
    # create the load_sum_order, a breadth first search from the leafs
    vs, depths = vertices_from_deepest_to_source(mg, 1)
    mg.graph_data[:load_sum_order] = vs
    init_split_networks!(mg)
    if Graphs.ne(mg) != length(mg.vertex_properties) - 1
        @warn "The MetaDiGraph created is not a tree."
    end

    return mg
end


# """
#     split_at_busses(net::Network, at_busses::Vector{String}, with_busses::Vector{Vector{String}})

# Split up `p` using the `at_busses` as each new `substation_bus` and containing the corresponding `with_busses`.
# The `at_busses` and `with_busses` can be determined using `splitting_busses`.

# NOTE: this variation of splt_at_busses allows for more than two splits at the same bus; whereas the other
# implementation of split_at_busses only splits the network into two parts for everything above and
# everything below a splitting bus.
# """
# function split_at_busses(net::Network, at_busses::Vector{String}, with_busses::Vector{Vector}; add_connections=true)
#     unique!(at_busses)
#     mg = MetaDiGraph()
#     if add_connections
#         with_busses = connect_subgraphs_at_busses(p, at_busses, with_busses)
#     end
#     # initial split
#     p_above, p_below = BranchFlowModel.split_inputs(p, at_busses[1], with_busses[1]);
#     add_vertex!(mg, :p, p_above)
#     add_vertex!(mg, :p, p_below)
#     add_edge!(mg, 1, 2)
#     set_indexing_prop!(mg, :p)

#     for (i, (b, sub_bs)) in enumerate(zip(at_busses[2:end], with_busses[2:end]))
#         # find the vertex to split
#         vertex = 0
#         for v in vertices(mg)
#             if b in mg[v, :p].busses
#                 vertex = v
#                 break
#             end
#         end
#         p_above, p_below = BranchFlowModel.split_inputs(mg[vertex, :p], b, sub_bs);
#         set_prop!(mg, vertex, :p, p_above)  # replace the already set :p, which preserves inneighbors
#         add_vertex!(mg, :p, p_below)  # vertex i+2
#         if !isempty(outdegree(mg, vertex))
#             # already have edge(s) for vertex -> outneighbors(mg, vertex)
#             # but now i+2 could be the parent for some of the outneighbors(mg, vertex)
#             outns = copy(outneighbors(mg, vertex))
#             for neighb in outns
#                 if !( mg[neighb, :p].substation_bus in mg[vertex, :p].busses )
#                     # mv the edge to the new intermediate node
#                     rem_edge!(mg, vertex, neighb)
#                     add_edge!(mg, i+2, neighb)
#                 end
#             end
#         end
#         add_edge!(mg, vertex, i+2)  # p_above -> p_below
#     end
#     # create the load_sum_order, a breadth first search from the leafs
#     vs, depths = vertices_from_deepest_to_source(mg, 1)
#     set_prop!(mg, :load_sum_order, vs)
#     init_split_networks!(mg)
#     if mg.graph.ne != length(mg.vprops) - 1
#         @warn "The MetaDiGraph created is not a tree."
#     end

#     return mg
# end


# """
#     build_metagraph(net::Network{SinglePhase}, source::String; max_busses::Int64=10)

# return MetaDiGraph by splitting the `Network` via `splitting_busses`
# """
# function build_metagraph(net::Network{SinglePhase}, source::String; max_busses::Int64=10)
#     splitting_bs, subgraphs = splitting_busses(net, source; max_busses=max_busses)  
#     split_at_busses(net, splitting_bs, subgraphs)
# end
