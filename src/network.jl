"""
    struct Network <: AbstractNetwork

Network is used to wrap a MetaGraph.
We leverage the `AbstractNetwork` type to make an intuitive interface for the Network model. 
For example, `edges(network)` returns it iterator of edge tuples with bus name values; 
(but if we used `Graphs.edges(MetaGraph)` we would get an iterator of Graphs.SimpleGraphs.SimpleEdge 
with integer values).
"""
struct Network{T<:Phases} <: AbstractNetwork
    graph::MetaGraphsNext.AbstractGraph
    substation_bus::String
    Sbase::Real
    Vbase::Real
    Zbase::Real
end


"""
    function Network(g::MetaGraphsNext.AbstractGraph) 

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


"""
    struct Conductor <: AbstractEdge

Interface for conductors in a Network. Fieldnames can be provided via a YAML file, JSON file, or
    populated manually. Conductors are specified via two busses, the **impedance in ohms per-unit
    length**, and a length value. 

# Single phase models
The minimum inputs for a single phase conductor look like:
```yaml
conductors:
  - busses: 
      - b1
      - b2
    r1: 0.1
    x1: 0.1
    length: 100
```
Note that the order of the items in the YAML file does not matter.

A conductor can also leverage a `template`, i.e. another conductor with a `name` that matches the
`template` value so that we can re-use the impedance values:
```yaml
conductors:
  - name: cond1
    busses: 
      - b1
      - b2
    r1: 0.1
    x1: 0.1
    length: 100
  - busses:
      - b2
      - b3
    template: cond1
    length: 200
```
The second conductor in the `conductors` above will use the `r0` and `x0` values from `cond1`,
scaled by the `length` of 200 and normalized by `Zbase`.

!!! note 
    The `name` field is optional unless a `conductor.name` is also the `template` of another
    conductor.
    

# Multi-phase models

Multi-phase conductors can be modeled as symmetrical or asymmetrical components. Similar to OpenDSS,
line impedances can be specified via the zero and positive sequence impedances, `(r0, x0)` and `(r1,
x1)` respectively; or via the lower-diagaonal portion of the phase-impedance matrix. In the prior
case we determine the phase-impedance matrix via the math in [Symmetrical Mutliphase Conductors](@ref)

Using the Multi-phase models require specifing `phases` (as integers) and  the zero and positive
sequence impedances like:
```yaml
conductors:
  - busses: 
      - b1
      - b2
    phases:
      - 2
      - 3
    r0: 0.766
    x0: 1.944
    r1: 0.301
    x1: 0.627
    length: 100
```
or by specifying the `rmatrix` and `zmatrix` like:
```yaml
conductors:
  - busses: 
      - b1
      - b2
    phases:
      - 2
      - 3
    rmatrix: 
      - [0.31]
      - [0.15, 0.32]
      - [0.15, 0.15, 0.33]
    xmatrix:
      - [1.01]
      - [0.5, 1.05]
      - [0.4, 0.3, 1.03]
    length: 100
```

"""
@with_kw struct Conductor <: AbstractEdge
    # required values
    busses::Tuple{String, String}
    # optional values
    phases::Union{Set{Int}, Missing} = missing
    name::Union{String, Missing} = missing
    template::Union{String, Missing} = missing
    r0::Union{Real, Missing} = missing
    x0::Union{Real, Missing} = missing
    r1::Union{Real, Missing} = missing
    x1::Union{Real, Missing} = missing
    length::Union{Real, Missing} = missing
    amps_limit::Union{Real, Missing} = missing
    @assert !(
        all(ismissing.([template, length])) &&
        all(ismissing.([x1, r1, length]))
     ) "Got insufficent values to define conductor impedance"
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
    edge_fieldnames = filter(fn -> fn != :busses, fieldnames(typeof(vals[1])))
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


"""
    function Network(fp::String)

Construct a `Network` from a yaml at the file path `fp`.
"""
function Network(fp::String)
    d = check_yaml(fp)
    conductors = Conductor[Conductor(;cd...) for cd in d[:conductors]]
    edge_tuples = collect(c.busses for c in conductors)
    g = make_graph(edge_tuples)
    fill_edge_attributes!(g, conductors)
    return Network(g, d[:network])
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