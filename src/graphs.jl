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
    function fill_edges!(g::MetaGraphsNext.AbstractGraph, vals::AbstractVector{<:AbstractEdge})

For each `edge`` in `vals` store the `edge`` in the graph using the `edge.busses`:
```julia
b1, b2 = edge.busses
graph[b1, b2] = edge
```
"""
function fill_edges!(g::MetaGraphsNext.AbstractGraph, vals::AbstractVector{<:AbstractEdge})
    for edge in vals
        b1, b2 = edge.busses
        try
            g[b1, b2]
        catch e
            if e isa KeyError  # this is what we want, an empty edge to fill
                nothing
            else
                rethrow(e)
            end
        else
            @warn "Replacing existing data in edge $(edge.busses)\n$(g[b1, b2])"
        end
        g[b1, b2] = edge
    end
end



"""
    make_graph(edges::AbstractVector{<:AbstractEdge};  directed::Union{Bool,Missing}=missing)

return MetaGraph made up of the `edges`

Also the graph[:int_bus_map] is created with the dicts for bus => int and int => bus
(because Graphs.jl only works with integer nodes)
```julia
julia> g["13", :bus]
10

julia> g[13, :bus]
"24"

julia> get_prop(g, :int_bus_map)[13]
"24"
```
"""
function make_graph(edges::AbstractVector{<:AbstractEdge}; directed::Union{Bool,Missing}=missing)
    busses = CommonOPF.busses_from_edges([e.busses for e in edges])  # TODO rm this hack
    bus_int_map = Dict(b => i for (i,b) in enumerate(busses))
    int_bus_map = Dict(i => b for (b, i) in bus_int_map)
    dtype = Dict{Symbol, Any}
    if ismissing(directed)  # infer from number of edges and busses
        directed = false
        if length(edges) + 1 == length(busses)  # assume radial, directed graph
            directed = true
        end
    end
    graph_template = Graphs.DiGraph()
    if !directed
        graph_template = Graphs.Graph()
    end

    edge_data_type = Union{subtypes(CommonOPF.AbstractEdge)...}

    g = MetaGraphsNext.MetaGraph(
        graph_template, 
        label_type=String,  # node keys are strings
        vertex_data_type=dtype,
        edge_data_type=edge_data_type,
        graph_data=Dict(:int_bus_map => int_bus_map)
    )

    for b in busses
        setindex!(g, dtype(), b)  # emtpy dict to fill later
    end

    fill_edges!(g, edges)

    return g
end


Graphs.outneighbors(g::MetaGraphsNext.MetaGraph, j::String) = collect(
    MetaGraphsNext.outneighbor_labels(g, j)
)


"""
    all_outneighbors(g::MetaGraphsNext.MetaGraph, j::String, outies::Vector{String})

A recursive function for finding all of the busses below bus `j`. Use like:

    busses_above_j = all_outneighbors(g, j, Vector{String}())
"""
function all_outneighbors(g::MetaGraphsNext.MetaGraph, j::String, outies::Vector{String}, except_busses::Vector{String})
    bs = setdiff(outneighbors(g, j), except_busses)
    for b in bs
        push!(outies, b)
        all_outneighbors(g, b, outies, except_busses)
    end
    return outies
end


function inneighbors(g::MetaGraphsNext.MetaGraph, j::String)
    ks = inneighbors(g, MetaGraphsNext.code_for(g, j))  # ks::Vector{Int64}
    return [MetaGraphsNext.label_for(g, k) for k in ks]
end


"""
    all_inneighbors(g::MetaGraphsNext.MetaGraph, j::String, innies::Vector{String})

A recursive function for finding all of the busses above bus `j`. Use like:

    busses_above_j = all_inneighbors(g, j, Vector{String}())
"""
function all_inneighbors(g::MetaGraphsNext.MetaGraph, j::String, innies::Vector{String})
    bs = inneighbors(g, j)
    for b in bs
        push!(innies, b)
        # have to get any outneighbors of upstream busses as well
        innies = vcat(innies, all_outneighbors(g, b, String[], [j]))
        return all_inneighbors(g, b, innies)
    end
    return innies
end


"""
    function induced_subgraph(g::MetaGraphsNext.MetaGraph, vlist::Vector{String})

returns the sub_busses::Vector{String} and sub_edges::Vector{Tuple{String, String}} that are 
required to make the induced subgraph in `g` from the nodes (or vertices) in `vlist`.
"""
function induced_subgraph(g::MetaGraphsNext.MetaGraph, vlist::Vector{String})
    ivlist = [MetaGraphsNext.code_for(g, b) for b in vlist]
    subg, vmap = induced_subgraph(g, ivlist)
    # vmap is Vector{Int} where vmap[int_in_subg] -> int_in_g
    # but we want the string busses as well as the edge tuples with strings
    sub_busses = [label_for(g, vmap[i]) for i in 1:length(vmap)]
    sub_edges = [
        ( label_for(g, vmap[e.src]), label_for(g, vmap[e.dst]) ) 
        for e in edges(subg)
    ]
    return sub_busses, sub_edges
end



"""
    busses_from_deepest_to_source(g::MetaGraphsNext.MetaGraph, source::String)

return the busses and their integer depths in order from deepest from shallowest
"""
function busses_from_deepest_to_source(g::MetaGraphsNext.MetaGraph, source::String)
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


"""
    vertices_from_deepest_to_source(g::Graphs.AbstractGraph, source::Int64)

returns the integer vertices of `g` and their depths from the leafs to `source`
"""
function vertices_from_deepest_to_source(g::Graphs.AbstractGraph, source::Int64)
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
    busses_with_multiple_inneighbors(g::MetaGraphsNext.MetaGraph)

Find all the busses in `g` with indegree > 1
"""
function busses_with_multiple_inneighbors(g::MetaGraphsNext.MetaGraph)::Vector{String}
    bs = String[]
    for v in MetaGraphsNext.vertices(g)
        if MetaGraphsNext.indegree(g, v) > 1
            push!(bs, MetaGraphsNext.label_for(g, v))
        end
    end
    return bs
end


"""
    next_bus_above_with_outdegree_more_than_one(g::MetaGraphsNext.MetaGraph, b::String)

Find the next bus above `b` with outdegree more than one.
If none are found than `nothing` is returned.
Throws an error if a bus with indegree > 1 is found above `b`.
"""
function next_bus_above_with_outdegree_more_than_one(g::MetaGraphsNext.MetaGraph, b::String)
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


"""
    paths_between(g::MetaGraphsNext.MetaGraph, b1::String, b2::String)::Vector{Vector{String}}

Returns all the paths (as vectors of bus strings) between `b1` and `b2`
"""
function paths_between(g::MetaGraphsNext.MetaGraph, b1::String, b2::String)::Vector{Vector{String}}
    outs = outneighbors(g, b1)
    paths = [[o] for o in outs] # initialize the path vectors with b1's outneighbors
    # convenience method
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
