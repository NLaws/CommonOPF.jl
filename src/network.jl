"""
    struct Network <: AbstractNetwork
        graph::MetaGraphsNext.AbstractGraph
        substation_bus::String
        Sbase::Real
        Vbase::Real
        Zbase::Real
    end

The `Network` model is used to store all the inputs required to create power flow and
optimal power flow models. Underlying the Network model is a `MetaGraphsNext.MetaGraph` that stores
the edge and node data in the network. 

We leverage the `AbstractNetwork` type to make an intuitive interface for the Network model. 
For example, `edges(network)` returns it iterator of edge tuples with bus name values; 
(but if we used `Graphs.edges(MetaGraph)` we would get an iterator of Graphs.SimpleGraphs.SimpleEdge 
with integer values).

A Network can be created directly or via a filepath.
"""
mutable struct Network{T<:Phases} <: AbstractNetwork
    graph::MetaGraphsNext.AbstractGraph
    substation_bus::String
    Sbase::Real
    Vbase::Real
    Zbase::Real
    v0::Union{Real, AbstractVecOrMat{<:Number}}
    Ntimesteps::Int
    v_lolim::Real
end


"""
    function Network(g::MetaGraphsNext.AbstractGraph, ntwk::Dict) 

Given a MetaGraph create a Network by extracting the edges and busses from the MetaGraph
"""
function Network(g::MetaGraphsNext.AbstractGraph, ntwk::Dict, net_type::Type) 
    # TODO MultiPhase based on inputs
    Sbase = get(ntwk, :Sbase, 1)
    Vbase = get(ntwk, :Vbase, 1)
    Zbase = Vbase^2 / Sbase
    v0 = get(ntwk, :v0, 1)
    Ntimesteps = get(ntwk, :Ntimesteps, 1)
    v_lolim = get(ntwk, :v_lolim, 0)
    Network{net_type}(
        g,
        string(ntwk[:substation_bus]),
        Sbase,
        Vbase,
        Zbase,
        v0,
        Ntimesteps,
        v_lolim
    )
end


"""
    function Network(fp::String)

Construct a `Network` from a yaml at the file path `fp`.
"""
function Network(fp::String)
    # parse inputs
    d = load_yaml(fp)
    conductors = build_conductors(d)
    net_type = SinglePhase
    if any((!ismissing(c.phases) for c in conductors))
        net_type = MultiPhase
    end
    loads = build_loads(d)
    # make the graph
    edge_tuples = collect(c.busses for c in conductors)
    g = make_graph(edge_tuples)
    fill_edge_attributes!(g, conductors)
    if length(loads) > 0
        fill_node_attributes!(g, loads)
    end
    return Network(g, d[:network], net_type)
end


# make it so Network[edge_tup] returns the data dict
Base.getindex(net::Network, idx::Tuple{String, String}) = net.graph[idx[1], idx[2]]


# make it so Network[node_string] returns the data dict
Base.getindex(net::Network, idx::String) = net.graph[idx]


"""
    function Base.getindex(net::Network, bus::String, kws_kvars::Symbol, phase::Int)

Load getter for `Network`. Use like:
```julia
net["busname", :kws, 2]

net["busname", :kvars, 3]
```
The second argument must be one of `:kws` or `:kvars`. The third arbument must be one of `[1,2,3]`.
If the `"busname"` exists and has a `:Load` dict, but the load (e.g. `:kvars2`) is not defined then
`zeros(net.Ntimesteps)` is returned.
"""
function Base.getindex(net::Network, bus::String, kws_kvars::Symbol, phase::Int)
    load_key = Symbol(kws_kvars, Symbol(phase))
    if !(load_key in LOAD_KEYS)
        throw(KeyError("To get a Load use :kws or :kvars and a phase in [1,2,3]"))
    end
    try
        return net[bus][:Load][load_key]
    catch e
        # if the key error is from the bus or :Load we throw it
        if typeof(e) == KeyError 
            if e.key == :Load
                throw(KeyError("There is no Load at bus $bus"))
            elseif e.key == bus
                throw(e)
            end
        end
        # else we return zeros
        return zeros(net.Ntimesteps)
    end
end


Graphs.edges(net::AbstractNetwork) = MetaGraphsNext.edge_labels(net.graph)


Graphs.inneighbors(net::Network, bus::String) = MetaGraphsNext.inneighbor_labels(net.graph, bus)
Graphs.outneighbors(net::Network, bus::String) = MetaGraphsNext.outneighbor_labels(net.graph, bus)


i_to_j(j::String, net::Network) = collect(inneighbors(net::Network, j::String))
j_to_k(j::String, net::Network) = collect(outneighbors(net::Network, j::String))


function MetaGraphsNext.add_edge!(net::CommonOPF.AbstractNetwork, b1::String, b2::String; data=Dict())
    MetaGraphsNext.add_vertex!(net.graph, b1, Dict())
    MetaGraphsNext.add_vertex!(net.graph, b2, Dict())
    @assert MetaGraphsNext.add_edge!(net.graph, b1, b2, data) == true
end


busses(net::AbstractNetwork) = MetaGraphsNext.labels(net.graph)


load_busses(net::AbstractNetwork) = (b for b in busses(net) if haskey(net[b], :Load))


real_load_busses(net::Network{SinglePhase}) = (b for b in load_busses(net) if !(ismissing(net[b][:Load][:kws1])))


reactive_load_busses(net::Network{SinglePhase}) = (b for b in load_busses(net) if !(ismissing(net[b][:Load][:kvars1])))


edges_with_data(net::AbstractNetwork) = ( (edge_tup, net[edge_tup]) for edge_tup in edges(net))


conductors(net::AbstractNetwork) = ( edge_data[:Conductor] for (_, edge_data) in edges_with_data(net) if haskey(edge_data, :Conductor))


function conductors_with_attribute_value(net::AbstractNetwork, attr::Symbol, val::Any)::AbstractVector{Dict}
    collect(
        filter(c -> haskey(c, attr) && c[attr] == val, collect(conductors(net)))
    )
end


"""
    function fill_edge_attributes!(g::MetaGraphsNext.AbstractGraph, vals::AbstractVector{<:AbstractEdge})

For each edge in `vals` fill in the graph `g` edge attributes for all fieldnames in the edge (except
busses). The outer edge key is set to the edge type, for example after this process is run Conductor
attributes that are not missing can be accessed via:
```julia
graph["b1", "b2"][:Conductor][:r0]
```
"""
function fill_edge_attributes!(g::MetaGraphsNext.AbstractGraph, vals::AbstractVector{<:AbstractEdge})
    edge_fieldnames = fieldnames(typeof(vals[1]))
    type = split(string(typeof(vals[1])), ".")[end]  # e.g. "CommonOPF.Conductor" -> "Conductor"
    for edge in vals
        b1, b2 = edge.busses
        if !isempty(g[b1, b2])
            @warn "Filling in edge $(edge.busses) with existing attributes $(g[b1, b2])"
        end
        g[b1, b2][Symbol(type)] = Dict(
            fn => getfield(edge, fn) for fn in edge_fieldnames if !ismissing(getfield(edge, fn))
        )
    end
end


function fill_node_attributes!(g::MetaGraphsNext.AbstractGraph, vals::AbstractVector{<:AbstractBus})
    node_fieldnames = fieldnames(typeof(vals[1]))
    type = split(string(typeof(vals[1])), ".")[end]  # e.g. "CommonOPF.Load" -> "Load"
    for node in vals
        if !(node.bus in labels(g))
            @warn "Bus $(node.bus) is not in the graph after adding edges but has attributes:\n"*
                "$node\n"*
                "You will have to manually add bus $(node.bus) if you want it in the graph."
            continue
        end
        if !isempty(g[node.bus])
            @warn "Filling in node $(node.bus) with existing attributes $(g[node.bus])"
        end
        g[node.bus][Symbol(type)] = Dict(
            fn => getfield(node, fn) for fn in node_fieldnames if !ismissing(getfield(node, fn))
        )
    end
end


function check_missing_templates(net::Network) 
    conds = collect(conductors(net))
    missing_templates = String[]
    for c in conds
        template = get(c, :template, missing)
        if !ismissing(template)
            results = filter(c -> haskey(c, :name) && c[:name] == template, conds)
            if length(results) == 0
                push!(missing_templates, template)
            end
        end
    end
    if length(missing_templates) > 0
        @warn "Missing templates: $missing_templates"
        return false
    end
    return true
end


function is_connected(net::Network)::Bool
    length(Graphs.weakly_connected_components(net.graph)) == 1
    # TODO undirected graphs, strongly_connected_components
end