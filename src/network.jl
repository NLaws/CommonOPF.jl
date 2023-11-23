"""
    struct Network <: AbstractNetwork

Network is used to wrap a MetaGraph.
We leverage the `AbstractNetwork` type to make an intuitive interface for the Network model. 
For example, `edges(network)` returns it iterator of edge tuples with bus name values; 
(but if we used `Graphs.edges(MetaGraph)` we would get an iterator of Graphs.SimpleGraphs.SimpleEdge 
with integer values).
"""
struct Network <: AbstractNetwork
    metagraph::MetaGraphsNext.AbstractGraph
    edges::Union{Base.Generator, AbstractVector}
    busses::Union{Base.Generator, AbstractVector}
    substation_bus::String
    Sbase::Real
    Vbase::Real
end


"""
    function Network(g::MetaGraphsNext.AbstractGraph) 

Given a MetaGraph create a Network by extracting the edges and busses from the MetaGraph
"""
function Network(g::MetaGraphsNext.AbstractGraph, ntwk::Dict) 
    Network(
        g, 
        MetaGraphsNext.edge_labels(g),
        MetaGraphsNext.labels(g),
        ntwk[:substation_bus],
        get(ntwk, :Sbase, 1),
        get(ntwk, :Vbase, 1)
    )
end


"""
    function check_yaml(fp::String)

Check input yaml file has required top-level keys:
- substation_bus
- edges
"""
function check_yaml(fp::String)
    d = YAML.load_file(fp; dicttype=Dict{Symbol, Any})
    missing_keys = []
    required_keys = [
        (:edges, [:busses], true)  # bool for array values
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

Interface for edges in a Network. Fieldnames can be provided via a YAML file or populated
    manually. See `Network` for parsing YAML specifications.
"""
struct Edge <: AbstractEdge
    # required values
    busses::Tuple{String, String}
    # optional values
    name::String
end


function Edge(d::Dict{Symbol, Any})
    busses = Tuple(String.(d[:busses]))
    name = get(d, :name, "")
    return Edge(busses, name)
end



"""
    function Network(fp::String)

Construct a `Network` from a yaml at the file path `fp`.
"""
function Network(fp::String)
    d = check_yaml(fp)
    edges = Edge.(d[:edges])
    g = make_graph(collect(e.busses for e in edges))
    return Network(g, d[:network])
end

