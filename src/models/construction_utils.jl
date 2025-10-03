"""
    substation_voltage(net::Network{MultiPhase})::Vector{ComplexF64}

Parse `net.v0` into a Vector{ComplexF64}, allowing for `net.v0` to be a `Real`,
`AbstractVector{<:Real}`, or `AbstractVector{<:Complex}`.
"""
function substation_voltage(net::Network{MultiPhase})::Vector{ComplexF64}

    if typeof(net.v0) <: Real
        return [
            net.v0 + 0im; 
            -0.5*net.v0 - im*sqrt(3)/2 * net.v0; 
            -0.5*net.v0 + im*sqrt(3)/2 * net.v0
        ]

    elseif typeof(net.v0) <: AbstractVector{<:Real}
        return [
            net.v0[1] + 0im; 
            -0.5 * net.v0[2] - im*sqrt(3)/2 * net.v0[2]; 
            -0.5 * net.v0[3] + im*sqrt(3)/2 * net.v0[3]
        ]

    elseif typeof(net.v0) <: AbstractVector{<:Complex}
        return net.v0
    end

    throw(@error "unsupported type for Network.v0 $(typeof(net.v0))")
end


"""
    substation_voltage(net::Network{SinglePhase})::Vector{ComplexF64}

Parse `net.v0` into a Vector{ComplexF64}, allowing for `net.v0` to be a `Real` or `ComplexF64`. We
put `net.v0` into a vector to make the voltage compatible with model builders that work for both
SinglePhase and MultiPhase networks. This SinglePhase version has one entry in the vector for one phase.
"""
function substation_voltage(net::Network{SinglePhase})::Vector{ComplexF64}

    if typeof(net.v0) <: Real
        return [net.v0 + 0im]

    elseif typeof(net.v0) <: Complex
        return [net.v0]
    end
    
    throw(@error "unsupported type for Network.v0 $(typeof(net.v0))")
end


"""
    phi_ij(j::String, net::Network, M::AbstractMatrix)

Down-select the matrix M by the phase from i -> j, storing `0im` in the missing off-diagonal phase
indices and `0` in the diagonal missing indices.
"""
function phi_ij(j::String, net::Network, M::AbstractMatrix)
    N = convert(Matrix{GenericAffExpr{ComplexF64, VariableRef}}, [0 0im 0im; 0im 0. 0im; 0im 0im 0])
    for x in phases_into_bus(net, j), y in phases_into_bus(net, j)
        N[x,y] = M[x,y]
    end
    return N
end


"""
    phi_ij(j::String, net::Network, v::AbstractVector)

Down-select the vector v by the phase from i -> j, storing `0im` in the missing phase indices.
"""
function phi_ij(j::String, net::Network, v::AbstractVector)
    n = convert(Vector{GenericAffExpr{ComplexF64, VariableRef}}, [0im; 0im; 0im])
    for x in phases_into_bus(net, j)
        n[x] = v[x]
    end
    return n
end


"""
    cj(A)

short cut for conj(transpose(A))
"""
function cj(A)
    conj(transpose(A))
end


"""
    matrix_phases_to_vec(M::AbstractMatrix{T}, phases::AbstractVector{Int}) where T

Used in defining the KVL constraints, this method returns the entries of `M` at the indices in 
`phases` in a vector.
"""
function matrix_phases_to_vec(M::AbstractMatrix{T}, phases::AbstractVector{Int}) where T
    v = T[]
    for i in phases, j in phases 
        push!(v, M[i,j])
    end
    return v
end