"""
    struct Network

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

function Network(g::MetaGraphsNext.AbstractGraph) 
    Network(
        g, 
        MetaGraphsNext.edge_labels(g),
        MetaGraphsNext.labels(g)
    )
end


struct Edge <: AbstractEdge
    # required values
    busses::Tuple{String, String}
    # TODO make bus name Symbol

    function Edge(d::Dict{Symbol, Any})
        busses = Tuple(String.(d[:busses]))
        return new(busses)
    end
end


"""
    function make_graph(fp::String)

Construct a `Network` from a yaml at the file path `fp`.
"""
function Network(fp::String)
    d = YAML.load_file(fp; dicttype=Dict{Symbol, Any})
    edges = Edge.(d[:edges])
    g = make_graph(collect(e.busses for e in edges))
    return Network(g)
end

