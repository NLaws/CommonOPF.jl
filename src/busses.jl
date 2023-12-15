# all the things that move power from one point to another


"""
    function  build_busses(dicts::AbstractVector{Dict{Symbol, Any}}, Bus::DataType)

unpack each dict in `dicts` into `Bus` and pass the results to `check_edges!`.
returns `Vector{T}`
"""
function build_busses(dicts::AbstractVector{Dict{Symbol, Any}}, Bus::DataType)
    @assert supertype(Bus) == AbstractBus
    # String(int) does not work, have to use string(int) :/
    for d in dicts
        d[:bus] = string(d[:bus])
    end
    busses = Bus[Bus(;bdict...) for bdict in dicts]
    check_busses!(busses)  # dispatch on Vector{T}
    return busses
end


"""
    check_busses!(busses::AbstractVector{<:AbstractBus}) = nothing

The default action after build_busses.
"""
check_busses!(busses::AbstractVector{<:AbstractBus}) = nothing
