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
    check_edges!(edges::AbstractVector{<:AbstractEdge})::Bool = true

The default action after build_edges.
"""
check_edges!(edges::AbstractVector{<:AbstractEdge})::Bool = true


"""
    function unpack_input_matrices!(edge::AbstractEdge)

Convert lower diagonal impedance matrices loaded in from YAML or JSON to 3x3 matrices.
The "matrices" come in as Vector{Vector} and look like:
```
julia> d[:conductors][3][:rmatrix]
3-element Vector{Vector{Float64}}:
 [0.31]
 [0.15, 0.32]
 [0.15, 0.15, 0.33]
```
"""
function unpack_input_matrices!(edge::AbstractEdge)
    rmatrix = zeros(3,3)
    xmatrix = zeros(3,3)
    for (i, phs1) in enumerate(edge.phases), (j, phs2) in enumerate(edge.phases)
        try
            if i >= j # in lower triangle
                rmatrix[phs1, phs2] = edge.rmatrix[i][j]
                xmatrix[phs1, phs2] = edge.xmatrix[i][j]
            else  # flip i,j to mirror in to upper triangle
                rmatrix[phs1, phs2] = edge.rmatrix[j][i]
                xmatrix[phs1, phs2] = edge.xmatrix[j][i]
            end
        catch BoundsError
            @warn "Unable to process impedance matrices for edge:\n"*
                "$edge\n"*
                "Probably because the phases do not align with one or both of the rmatrix and xmatrix."
            return
        end
    end
    edge.rmatrix = rmatrix
    edge.xmatrix = xmatrix
    nothing
end


"""
    function fill_impedance_matrices!(edge::AbstractEdge)

Put the resistance and reactance values on the diagonal of the rmatrix and xmatrix respectively
"""
function fill_impedance_matrices!(edge::AbstractEdge)
    # fill the matrices
    rmatrix = zeros(3,3)
    xmatrix = zeros(3,3)
    for phs in edge.phases
        rmatrix[phs, phs] = edge.resistance
        xmatrix[phs, phs] = edge.reactance
    end
    edge.rmatrix = rmatrix
    edge.xmatrix = xmatrix
    nothing
end


"""
    validate_multiphase_edges!(edges::AbstractVector{<:AbstractEdge})

The default method for checking for missing phases and filling `rmatrix` and `xmatrix` values for
    subtypes of `AbstractEdge`. We assume that the subtype has `resistance` and `reactance`
    properties and warn if any `phases` are missing as well as if we cannot infer impedance values.
"""
function validate_multiphase_edges!(edges::AbstractVector{<:AbstractEdge})::Bool
    n_no_phases = 0
    n_no_impedance = 0

    for edge in edges
        if ismissing(edge.phases)
            n_no_phases += 1
        elseif (
            any(ismissing.([edge.resistance, edge.reactance])) &&
            any(ismissing.([edge.rmatrix, edge.xmatrix]))
        ) # if all of these are true then we cannot define impedance
            n_no_impedance += 1
        else  # we have everything we need to define rmatrix, xmatrix
            if !ismissing(edge.rmatrix) 
                if typeof(edge.rmatrix) <: Vector
                    # unpack the Vector{Vector} (lower diagaonal portion of matrix)
                    unpack_input_matrices!(edge)
                # elseif typeof(edge.rmatrix) <: Matrix  # do nothing, we're good
                    # NOTE assuming R and X provided in the same format
                end
            else  # use resistance and reactance to build matrices
                fill_impedance_matrices!(edge)
            end
        end
    end

    good = true

    if n_no_phases > 0
        @warn "$(n_no_phases) edges of type $(typeof(edges[1])) are missing phases."
        good = false
    end

    if n_no_impedance > 0
        @warn "$(n_no_impedance) edges of type $(typeof(edges[1])) do not have sufficient\n"* 
            "parameters to define the impedance.\n"
        good = false
    end
    return good
end


phases_union(edges::AbstractVector{<:AbstractEdge}) = union([e.phases for e in edges if !ismissing(e.phases)]...)
