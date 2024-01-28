"""
    struct Network <: AbstractNetwork
        graph::MetaGraphsNext.AbstractGraph
        substation_bus::String
        Sbase::Real
        Vbase::Real
        Zbase::Real
        v0::Union{Real, AbstractVecOrMat{<:Number}}
        Ntimesteps::Int
        v_lolim::Real
        v_uplim::Real
        var_name_map::Dict{String, Any}
    end

The `Network` model is used to store all the inputs required to create power flow and optimal power
flow models. Underlying the Network model is a `MetaGraphsNext.MetaGraph` that stores the edge and
node data in the network. 

We leverage the `AbstractNetwork` type to make an intuitive interface for the Network model. For
example, `edges(network)` returns an iterator of edge tuples with bus name values; (but if we used
`Graphs.edges(MetaGraph)` we would get an iterator of Graphs.SimpleGraphs.SimpleEdge with integer
values).

A Network can be created directly, via a `Dict`, or a filepath. The minimum inputs must have a
vector of [Conductor](@ref) specifications and a `Network` key containing at least the
`substation_bus`. See [Input Formats](@ref) for more details.
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
    v_uplim::Real
    var_name_map::Dict{String, Any}
end


"""
    function Network(g::MetaGraphsNext.AbstractGraph, ntwk::Dict) 

Given a MetaGraph create a Network by extracting the edges and busses from the MetaGraph
"""
function Network(g::MetaGraphsNext.AbstractGraph, ntwk::Dict, net_type::Type) 
    # TODO MultiPhase based on inputs
    Sbase = get(ntwk, :Sbase, 1)
    Vbase = get(ntwk, :Vbase, 1)
    Zbase = get(ntwk, :Zbase, Vbase^2 / Sbase)
    v0 = get(ntwk, :v0, 1)
    Ntimesteps = get(ntwk, :Ntimesteps, 1)
    v_lolim = get(ntwk, :v_lolim, 0)
    v_uplim = get(ntwk, :v_uplim, 2)
    Network{net_type}(
        g,
        string(ntwk[:substation_bus]),
        Sbase,
        Vbase,
        Zbase,
        v0,
        Ntimesteps,
        v_lolim,
        v_uplim,
        Dict{String, Any}()
    )
end


REQUIRED_EDGES = [Conductor]


"""
    function Network(d::Dict)

Construct a `Network` from a dictionary that has at least keys for:
1. `:Conductor`, a vector of dicts with [Conductor](@ref) specs
2. `:Network`, a dict with at least `:substation_bus`
"""
function Network(d::Dict)
    edges = AbstractEdge[]
    for EdgeType in subtypes(AbstractEdge)
        dkey = Symbol(split(string(EdgeType), ".")[end])  # left-strip CommonOPF.
        if dkey in keys(d)
            edges = vcat(edges, build_edges(d[dkey], EdgeType))
        elseif EdgeType in REQUIRED_EDGES
            throw(error("Missing required input $(string(dkey))"))
        end
    end
    # Single vs. MultiPhase is determined by edge.phases
    net_type = SinglePhase
    if any((!ismissing(e.phases) for e in edges))
        net_type = MultiPhase
    end
    busses = AbstractBus[]
    for BusType in subtypes(AbstractBus)
        dkey = Symbol(split(string(BusType), ".")[end])   # left-strip CommonOPF.
        if dkey in keys(d)
            busses = vcat(busses, build_busses(d[dkey], BusType))
        end
    end
    # NEXT all tests, examples need new keys to match type names

    # make the graph
    edge_tuples = collect(e.busses for e in edges)
    g = make_graph(edge_tuples)
    fill_edge_attributes!(g, edges)
    if length(busses) > 0
        fill_node_attributes!(g, busses)
    end
    return Network(g, d[:Network], net_type)
end


"""
    function Network(fp::String)

Construct a `Network` from a yaml at the file path `fp`.
"""
function Network(fp::String)
    # parse inputs
    if endswith(lowercase(fp), "yaml") ||  endswith(lowercase(fp), "yml")
        d = load_yaml(fp)
    else
        # TODO json
        throw(error("Only parsing yaml (or yml) files so far."))
    end
    Network(d)
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


voltage_regulator_busses(net::AbstractNetwork) = (b for b in busses(net) if haskey(net[b], :VoltageRegulator))


real_load_busses(net::Network{SinglePhase}) = (b for b in load_busses(net) if haskey(net[b][:Load], :kws1))


reactive_load_busses(net::Network{SinglePhase}) = (b for b in load_busses(net) if haskey(net[b][:Load], :kvars1))


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
    for edge in vals
        # TODO memoize next two lines or make more efficient some other way
        edge_fieldnames = fieldnames(typeof(edge))
        type = split(string(typeof(edge)), ".")[end]  # e.g. "CommonOPF.Conductor" -> "Conductor"
        b1, b2 = edge.busses
        if !isempty( get(g[b1, b2], Symbol(type), []) )
            @warn "Replacing existing attributes $(g[b1, b2][Symbol(type)]) in edge $(edge.busses)"
        end
        g[b1, b2][Symbol(type)] = Dict(
            fn => getfield(edge, fn) for fn in edge_fieldnames if !ismissing(getfield(edge, fn))
        )
    end
end


function fill_node_attributes!(g::MetaGraphsNext.AbstractGraph, vals::AbstractVector{<:AbstractBus})
    for node in vals
        if !(node.bus in labels(g))
            @warn "Bus $(node.bus) is not in the graph after adding edges but has attributes:\n"*
                "$node\n"*
                "You will have to manually add bus $(node.bus) if you want it in the graph."
            continue
        end
        node_fieldnames = fieldnames(typeof(node))
        type = split(string(typeof(node)), ".")[end]  # e.g. "CommonOPF.Load" -> "Load"
        if !isempty( get(g[node.bus], Symbol(type), []) )
            @warn "Replacing existing attributes $(g[node.bus][Symbol(type)]) in node $(node.bus)"
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


##############################################################################
##############################################################################
##############################################################################
# some test networks for use in BranchFlowModel.jl, etc.

function Network_IEEE13_SinglePhase()
    fp = joinpath(dirname(@__FILE__), 
        "..", "test", "data", "yaml_inputs", "ieee13_single_phase.yaml"
    )
    return Network(fp)
end


function Network_Papavasiliou_2018()
    fp = joinpath(dirname(@__FILE__), 
        "..", "test", "data", "yaml_inputs", "Papavasiliou_2018_with_shunts.yaml"
    )
    return Network(fp)
end