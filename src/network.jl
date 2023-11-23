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
end


"""
    function Network(g::MetaGraphsNext.AbstractGraph) 

Given a MetaGraph create a Network by extracting the edges and busses from the MetaGraph
"""
function Network(g::MetaGraphsNext.AbstractGraph) 
    Network(
        g, 
        MetaGraphsNext.edge_labels(g),
        MetaGraphsNext.labels(g)
    )
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
    return Network(g)
end

