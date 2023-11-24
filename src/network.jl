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
Base.getindex(n::Network, idx::Tuple{String, String}) = n.graph[idx[1], idx[2]]

# make it so Network[node_string] returns the data dict
Base.getindex(n::Network, idx::String) = n.graph[idx]

Graphs.edges(n::AbstractNetwork) = MetaGraphsNext.edge_labels(n.graph)

function MetaGraphsNext.add_edge!(net::CommonOPF.AbstractNetwork, b1::String, b2::String; data=Dict())
    MetaGraphsNext.add_vertex!(net.graph, b1, Dict())
    MetaGraphsNext.add_vertex!(net.graph, b2, Dict())
    @assert MetaGraphsNext.add_edge!(net.graph, b1, b2, data) == true
end

busses(n::AbstractNetwork) = MetaGraphsNext.labels(n.graph)

edges_with_data(n::AbstractNetwork) = ( (edge_tup, n[edge_tup]) for edge_tup in edges(n))

conductors(n::AbstractNetwork) = ( edge_data[:Conductor] for (_, edge_data) in edges_with_data(n) if haskey(edge_data, :Conductor))



"""
    function check_yaml(fp::String)

Check input yaml file has required top-level keys:
- network
- conductors

Convert busses to Tuple (comes in as Vector)
"""
function check_yaml(fp::String)
    d = YAML.load_file(fp; dicttype=Dict{Symbol, Any})
    check_input_dict(d)
end


"""
    function check_input_dict(d::Dict)::Dict

Check dict has required top-level keys:
- network
- conductors

Convert busses to Tuple
"""
function check_input_dict(d::Dict)::Dict
    missing_keys = []
    required_keys = [
        (:conductors, [:busses], true)  # bool for array values
        (:network, [:substation_bus], false)
    ]
    for (rkey, subkeys, is_array) in required_keys
        if !(rkey in keys(d))
            push!(missing_keys, rkey)
        else
            if is_array
                for sub_dict in d[rkey]
                    for skey in subkeys
                        if !(skey in keys(sub_dict))
                            push!(missing_keys, skey)
                        elseif skey == :busses
                            # convert Vector{String} to Tuple{String, String}
                            sub_dict[:busses] = Tuple(String.(sub_dict[:busses]))
                        end
                    end
                end
            else
                for skey in subkeys
                    if !(skey in keys(d[rkey]))
                        push!(missing_keys, skey)
                    end
                end
            end
        end
    end
    if length(missing_keys) > 0
        throw(ErrorException("Network yaml specification missing requried keys: $(missing_keys)"))
    end
    return d
end


"""
    struct Conductor <: AbstractEdge

Interface for conductors in a Network. Fieldnames can be provided via a YAML file or populated
    manually. See `Network` for parsing YAML specifications.
"""
@with_kw struct Conductor <: AbstractEdge
    # required values
    busses::Tuple{String, String}
    # optional values
    name::Union{String, Missing} = missing
    template::Union{String, Missing} = missing
    r0::Union{Real, Missing} = missing
    x0::Union{Real, Missing} = missing
    length::Union{Real, Missing} = missing
    @assert !(
        all(ismissing.([template, length])) &&
        all(ismissing.([x0, r0, length]))
     ) "Got insufficent values to define conductor impedance"
end


"""
    function fill_edge_attributes!(g::MetaGraphsNext.AbstractGraph, vals::AbstractVector{<:AbstractEdge})

For each edge in `vals` fill in the graph `g` edge attributes for all fieldnames in the edge (except busses).
The outer edge key is set to the edge type, for example after this process is run Conductor attributes
that are not missing can be accessed via:
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