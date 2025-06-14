"""
    function  build_busses(dicts::AbstractVector{Dict{Symbol, Any}}, ConcreteBusType::DataType)

unpack each dict in `dicts` into `ConcreteBusType` constructor and pass the results to
`check_busses!`.

returns `Vector{ConcreteBusType}`
"""
function build_busses(
        dicts::AbstractVector{Dict{Symbol, Any}}, 
        ConcreteBusType::DataType
    )::Vector{ConcreteBusType}
    @assert supertype(ConcreteBusType) == AbstractBus
    # String(int) does not work, have to use string(int) :/
    for d in dicts
        d[:bus] = string(d[:bus])
    end
    busses = ConcreteBusType[ConcreteBusType(;bdict...) for bdict in dicts]
    check_busses!(busses)  # dispatch on AbstractVector{ConcreteBusType}
    return busses
end


"""
    check_busses!(busses::AbstractVector{<:AbstractBus}) = nothing

The default action after build_busses.
"""
check_busses!(busses::AbstractVector{<:AbstractBus}) = nothing


"""
    connected_busses(j::String, net::Network)::Set{String}

Return a vector of all the busses connected to bus `j`.
"""
function connected_busses(j::String, net::Network)::Set{String}
    Set(vcat(i_to_j(j, net), j_to_k(j, net)))
end