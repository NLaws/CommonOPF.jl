# all the things that move power from one point to another


"""
    function build_edges(dicts::AbstractVector{Dict}, Edge::DataType)

unpack each dict in `dicts` into `Edge` and pass the results to `check_edges!`.
returns `Vector{Edge}`
"""
function build_edges(dicts::T where T <: AbstractVector{Dict{Symbol, Any}}, Edge::DataType)
    @assert supertype(Edge) == AbstractEdge
    edges = Edge[Edge(;edict...) for edict in dicts]
    check_edges!(edges)  # dispatch on Vector{Edge}
    return edges
end


"""
    check_edges!(edges::AbstractVector{<:AbstractEdge}) = nothing

The default action after build_edges.
"""
check_edges!(edges::AbstractVector{<:AbstractEdge}) = nothing
