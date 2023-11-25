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
struct Network{T<:Phases} <: AbstractNetwork
    graph::MetaGraphsNext.AbstractGraph
    substation_bus::String
    Sbase::Real
    Vbase::Real
    Zbase::Real
end


"""
    function Network(g::MetaGraphsNext.AbstractGraph, ntwk::Dict) 

Given a MetaGraph create a Network by extracting the edges and busses from the MetaGraph
"""
function Network(g::MetaGraphsNext.AbstractGraph, ntwk::Dict) 
    # TODO MultiPhase based on inputs
    Sbase = get(ntwk, :Sbase, 1)
    Vbase = get(ntwk, :Vbase, 1)
    Zbase = Vbase^2 / Sbase
    Network{SinglePhase}(
        g,
        ntwk[:substation_bus],
        Sbase,
        Vbase,
        Zbase
    )
end


"""
    function Network(fp::String)

Construct a `Network` from a yaml at the file path `fp`.
"""
function Network(fp::String)
    d = load_yaml(fp)
    conductors = Conductor[Conductor(;cd...) for cd in d[:conductors]]
    # check multiphase conductors
    if any((!ismissing(c.phases) for c in conductors))
        validate_multiphase_conductors!(conductors)
    else
        warn_singlephase_conductors(conductors)
    end
    # make the graph
    edge_tuples = collect(c.busses for c in conductors)
    g = make_graph(edge_tuples)
    fill_edge_attributes!(g, conductors)
    # fill_node_attributes!(g, loads)
    return Network(g, d[:network])
end


# make it so Network[edge_tup] returns the data dict
Base.getindex(net::Network, idx::Tuple{String, String}) = net.graph[idx[1], idx[2]]


# make it so Network[node_string] returns the data dict
Base.getindex(net::Network, idx::String) = net.graph[idx]


Graphs.edges(net::AbstractNetwork) = MetaGraphsNext.edge_labels(net.graph)


function MetaGraphsNext.add_edge!(net::CommonOPF.AbstractNetwork, b1::String, b2::String; data=Dict())
    MetaGraphsNext.add_vertex!(net.graph, b1, Dict())
    MetaGraphsNext.add_vertex!(net.graph, b2, Dict())
    @assert MetaGraphsNext.add_edge!(net.graph, b1, b2, data) == true
end


busses(net::AbstractNetwork) = MetaGraphsNext.labels(net.graph)


edges_with_data(net::AbstractNetwork) = ( (edge_tup, net[edge_tup]) for edge_tup in edges(net))


conductors(net::AbstractNetwork) = ( edge_data[:Conductor] for (_, edge_data) in edges_with_data(net) if haskey(edge_data, :Conductor))

function conductors_with_attribute_value(net::AbstractNetwork, attr::Symbol, val::Any)::AbstractVector{Dict}
    collect(
        filter(c -> haskey(c, attr) && c[attr] == val, collect(conductors(net)))
    )
end


"""
    struct Load <: AbstractBus

A Load input specifier, mapped from YAML, JSON, or manually populated.

The minimum required inputs include several options. All require a `bus` to place the load. For
single phase models provide one of the following sets of values:
- `bus`, `kws1`, `kvars1`
- `bus`, `kws1`, `powerfactor`
- `bus`, `csv` 
where `csv` is a path to a two column CSV file with a single line header like "kws1,kvars1".

For multiphase models any of the single phase options above can be used and the load will be split
evenly across the phases (the `Network.graph` nodes will get attributes for `kws2`, `kvars2`, etc.
as appropriate). Note that bus phases are inferred from the conductors.

For unbalanced multiphase models one must provide one of:
- `bus`, [`kws1`, `kvars1`], [`kws2`, `kvars2`], [`kws3`, `kvars3`] <-- brackets imply optional
  pairs, depending on the phases at the load bus
- `bus`, `csv`
where the `csv` has 2, 4, or 6 columns with a single line header like
"kws1,kvars1,kws2,kvars2,kws3,kvars3" or "kws2,kvars2,kws3,kvars3".


!!! note 
    The `kws` and `kvars` inputs are plural because we always put the loads in vectors, even with
    one timestep. We do this so that the modeling packages that build on CommonOPF do not have to
    account for both scalar values and vector values.

bus, phase, time
"""
@with_kw struct Load <: AbstractBus
    # required values
    bus::String
    # optional values
    kws1::Union{AbstractVector{<:Real}, Missing} = missing
    kvars1::Union{AbstractVector{<:Real}, Missing} = missing
    kws2::Union{AbstractVector{<:Real}, Missing} = missing
    kvars2::Union{AbstractVector{<:Real}, Missing} = missing
    kws3::Union{AbstractVector{<:Real}, Missing} = missing
    kvars3::Union{AbstractVector{<:Real}, Missing} = missing
    powerfactor::Union{Real, Missing} = missing
    csv::Union{String, Missing} = missing
    @assert !(
        all(ismissing.([kws1, kvars1])) &&
        all(ismissing.([kws1, powerfactor])) &&
        all(ismissing.([csv]))
     ) "Got insufficent values to define Load"
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
