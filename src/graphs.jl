"""
    busses_from_edges(edges::AbstractVector)
    
collect and return all the unique values in the edge tuples of 2 strings
"""
function busses_from_edges(edges::AbstractVector)
    busses = String[]
    for t in edges
        push!(busses, t[1])
        push!(busses, t[2])
    end
    return unique(busses)
end


"""
    make_graph(edges::AbstractVector)

return SimpleDiGraph by inferring busses from `edges`
with the dicts for bus => int and int => bus
(because Graphs.jl only works with integer nodes)
```julia
julia> g["13", :bus]
10

julia> get_prop(g, :bus_int_map)["13"]
10

julia> g[13, :bus]
"24"

julia> get_prop(g, :int_bus_map)[13]
"24"
```
"""
function make_graph(edges::AbstractVector)
    busses = busses_from_edges(edges)
    bus_int_map = Dict(b => i for (i,b) in enumerate(busses))
    int_bus_map = Dict(i => b for (b, i) in bus_int_map)
    g = MetaDiGraph(length(busses))
    for e in edges
        add_edge!(g, Edge(bus_int_map[e[1]], bus_int_map[e[2]]))
    end
    g = MetaDiGraph(g)
    set_prop!(g, :bus_int_map, bus_int_map)
    set_prop!(g, :int_bus_map, int_bus_map)
    for (bus, i) in bus_int_map
        set_indexing_prop!(g, i, :bus, bus)
        # this allows g[:bus][bus_string] -> bus_int
        # and g[bus_int, :bus] -> bus_string
        # and g[bus_string, :bus] -> bus_int
        # to reverse use get_prop(g, i, :bus)
    end
    return g
end


"""
    make_graph(busses::AbstractVector{String}, edges::AbstractVector)

return SimpleDiGraph
with the dicts for bus => int and int => bus
(because Graphs.jl only works with integer nodes)
```julia
julia> g["13", :bus]
10

julia> get_prop(g, :bus_int_map)["13"]
10

julia> g[13, :bus]
"24"

julia> get_prop(g, :int_bus_map)[13]
"24"
```
"""
function make_graph(busses::AbstractVector{String}, edges::AbstractVector)
    bus_int_map = Dict(b => i for (i,b) in enumerate(busses))
    int_bus_map = Dict(i => b for (b, i) in bus_int_map)
    g = MetaDiGraph(length(busses))
    for e in edges
        add_edge!(g, Edge(bus_int_map[e[1]], bus_int_map[e[2]]))
    end
    g = MetaDiGraph(g)
    set_prop!(g, :bus_int_map, bus_int_map)
    set_prop!(g, :int_bus_map, int_bus_map)
    for (bus, i) in bus_int_map
        set_indexing_prop!(g, i, :bus, bus)
        # this allows g[:bus][bus_string] -> bus_int
        # and g[bus_int, :bus] -> bus_string
        # and g[bus_string, :bus] -> bus_int
        # to reverse use get_prop(g, i, :bus)
    end
    return g
end


function outneighbors(g::MetaGraphs.MetaDiGraph, j::String)
    ks = outneighbors(g, g[:bus][j])  # ks::Vector{Int64}
    return [g[k, :bus] for k in ks]
end


function all_outneighbors(g::MetaGraphs.MetaDiGraph, j::String, outies::Vector{String}, except_busses::Vector{String})
    bs = setdiff(outneighbors(g, j), except_busses)
    for b in bs
        push!(outies, b)
        all_outneighbors(g, b, outies, except_busses)
    end
    return outies
end


function inneighbors(g::MetaGraphs.MetaDiGraph, j::String)
    ks = inneighbors(g, g[:bus][j])  # ks::Vector{Int64}
    return [g[k, :bus] for k in ks]
end


function all_inneighbors(g::MetaGraphs.MetaDiGraph, j::String, innies::Vector{String})
    bs = inneighbors(g, j)
    for b in bs
        push!(innies, b)
        # have to get any outneighbors of upstream busses as well
        innies = vcat(innies, all_outneighbors(g, b, String[], [j]))
        return all_inneighbors(g, b, innies)
    end
    return innies
end


function induced_subgraph(g::MetaGraphs.MetaDiGraph, vlist::Vector{String})
    ivlist = [collect(filter_vertices(g, :bus, b))[1] for b in vlist]
    subg, vmap = induced_subgraph(g, ivlist)
    # vmap is Vector{Int} where vmap[int_in_subg] -> int_in_g
    # but we want the string busses as well as the edge tuples with strings
    sub_busses = [g[vmap[i], :bus] for i in 1:length(vmap)]
    sub_edges = [
        ( g[vmap[e.src], :bus], g[vmap[e.dst], :bus] ) 
        for e in edges(subg)
    ]
    return sub_busses, sub_edges
end



"""
    busses_from_deepest_to_source(g::MetaDiGraph, source::String)

return the busses and their integer depths in order from deepest from shallowest
"""
function busses_from_deepest_to_source(g::MetaDiGraph, source::String)
    depths = Int64[0]  # 1:1 with nms
    nms = String[source]
    depth = 0
    # first level
    ons = outneighbors(g, source)
    depths = vcat(depths, repeat([depth+1], length(ons)))  # [0, -1, -1] when length(ons) is 2
    nms = vcat(nms, ons)
    depth += 1
    
    function recur_outneighbors(ons::Vector{String}, depth)
        next_ons = String[]
        for o in ons
            nxtons = outneighbors(g, o)
            for nxt in nxtons
                push!(depths, depth + 1)
                push!(nms, nxt)
                push!(next_ons, nxt)
            end
        end
        depth += 1
        
        if !isempty(next_ons)
            recur_outneighbors(next_ons, depth)
        end
    end

    recur_outneighbors(ons, depth)
    return reverse(nms), reverse(depths)
end


function vertices_from_deepest_to_source(g::MetaDiGraph, source::Int64)
    depths = Int64[0]  # 1:1 with vs
    vs = Int64[source]
    depth = 0
    # first level
    ons = outneighbors(g, source)
    depths = vcat(depths, repeat([depth+1], length(ons)))  # [0, -1, -1] when length(ons) is 2
    vs = vcat(vs, ons)
    depth += 1
    
    function recur_outneighbors(ons::Vector{Int64}, depth)
        next_ons = Int64[]
        for o in ons
            nxtons = outneighbors(g, o)
            for nxt in nxtons
                push!(depths, depth + 1)
                push!(vs, nxt)
                push!(next_ons, nxt)
            end
        end
        depth += 1
        
        if !isempty(next_ons)
            recur_outneighbors(next_ons, depth)
        end
    end

    recur_outneighbors(ons, depth)
    return reverse(vs), reverse(depths)
end


"""
    busses_with_multiple_inneighbors(g::MetaDiGraph)

Find all the busses in `g` with indegree > 1
"""
function busses_with_multiple_inneighbors(g::MetaDiGraph)
    bs = String[]
    for v in vertices(g)
        if indegree(g, v) > 1
            push!(bs, get_prop(g, v, :bus))
        end
    end
    return bs
end


"""
    next_bus_above_with_outdegree_more_than_one(g::MetaDiGraph, b::String)

Find the next bus above `b` with outdegree more than one.
If none are found than `nothing` is returned.
Throws an error if a bus with indegree > 1 is found above `b`.
"""
function next_bus_above_with_outdegree_more_than_one(g::MetaDiGraph, b::String)
    ins = inneighbors(g, b)
    check_ins(ins) = length(ins) > 1 ? error("Found more than one in neighbor for vertex $b") : nothing
    check_ins(ins)
    if length(ins) == 0
        return nothing
    end
    while length(outneighbors(g, ins[1])) == 1
        ins = inneighbors(g, ins[1])
        check_ins(ins)
        if length(ins) == 0
            return nothing
        end
    end
    return ins[1]
end


function paths_between(g::MetaDiGraph, b1, b2)
    outs = outneighbors(g, b1)
    paths = [[o] for o in outs]
    check_nxtbs(bs) = length(bs) == 1 ? true : error("The paths between $b1 and $b2 diverge.")
    for (i,o) in enumerate(outs)
        nxtbs = outneighbors(g, o)
        while nxtbs[1] != b2
            check_nxtbs(nxtbs)
            push!(paths[i], nxtbs[1])
            nxtbs = outneighbors(g, nxtbs[1])
        end
    end
    return paths
end
