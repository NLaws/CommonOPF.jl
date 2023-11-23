"""
    struct Network <: AbstractNetwork

Network is used to wrap a MetaGraph.
We leverage the `AbstractNetwork` type to make an intuitive interface for the Network model. 
For example, `edges(network)` returns it iterator of edge tuples with bus name values; 
(but if we used `Graphs.edges(MetaGraph)` we would get an iterator of Graphs.SimpleGraphs.SimpleEdge 
with integer values).
"""
struct Network{T<:Phases} <: AbstractNetwork
    metagraph::MetaGraphsNext.AbstractGraph
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


edges(n::AbstractNetwork) = MetaGraphsNext.edge_labels(n.metagraph)

busses(n::AbstractNetwork) = MetaGraphsNext.labels(n.metagraph)


"""
    function check_yaml(fp::String)

Check input yaml file has required top-level keys:
- substation_bus
- conductors
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
    struct Edge <: AbstractEdge

Interface for conductors in a Network. Fieldnames can be provided via a YAML file or populated
    manually. See `Network` for parsing YAML specifications.
"""
struct Conductor <: AbstractEdge
    # required values
    busses::Tuple{String, String}
    # optional values
    name::String
    template::String
end


function Conductor(d::Dict{Symbol, Any})
    busses = Tuple(String.(d[:busses]))
    name = get(d, :name, "")
    template = get(d, :template, "")
    return Conductor(busses, name, template)
end



"""
    function Network(fp::String)

Construct a `Network` from a yaml at the file path `fp`.
"""
function Network(fp::String)
    d = check_yaml(fp)
    conductors = Conductor.(d[:conductors])
    g = make_graph(collect(c.busses for c in conductors))
    return Network(g, d[:network])
end

