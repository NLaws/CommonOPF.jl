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
end


"""
    function Network(g::MetaGraphsNext.AbstractGraph) 

Given a MetaGraph create a Network by extracting the edges and busses from the MetaGraph
"""
function Network(g::MetaGraphsNext.AbstractGraph, ntwk::Dict) 
    # TODO MultiPhase based on inputs
    Network{SinglePhase}(
        g,
        ntwk[:substation_bus],
        get(ntwk, :Sbase, 1),
        get(ntwk, :Vbase, 1)
    )
end


edges(n::AbstractNetwork) = MetaGraphsNext.edge_labels(n.graph)

busses(n::AbstractNetwork) = MetaGraphsNext.labels(n.graph)


"""
    function check_yaml(fp::String)

Check input yaml file has required top-level keys:
- network
- conductors

Convert busses to Tuple (comes in as Vector)
"""
function check_yaml(fp::String)
    d = YAML.load_file(fp; dicttype=Dict{Symbol, Any})
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
        ismissing(template) &&
        all(ismissing(val) for val in [x0, r0, length])
     ) "Got insufficent values to define a conductor"
end


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

