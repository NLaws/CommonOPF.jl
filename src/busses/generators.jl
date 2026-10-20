"""
    struct Generator <: AbstractBus

Required fields:
- `bus::String`

Work in progress. Adding fields as needed for BIM and BFM tests.
"""
@with_kw struct Generator <: AbstractBus
    # required values
    bus::String
    # optional values
    is_PV_bus::Bool = false
    p1::Vector{Real} = [0.0]
    voltage_series_pu::Vector{Real} = [1.0]
    name::Union{String, Missing} = missing
    voltage_pu::Real = 1.0          # voltage setpoint (pu)
    mva_base::Real = 100.0
    status::Int = 1
    pmax::Real = 0.0
    pmin::Real = 0.0
    price_points::AbstractVector{Real} = Real[]
    mw_points::AbstractVector{Real} = Real[]
end


generator_busses(net::Network) = collect(
    b for b in busses(net) if haskey(net[b], :Generator)
)

# extensions to allow `for gen in net[bus][:Generator]` regardless of number of generators in a bus.
# first iteration over Generator: return the element and an arbitrary state
Base.iterate(g::CommonOPF.Generator) = (g, true)
# On the next iteration, stop.
Base.iterate(::CommonOPF.Generator, ::Bool) = nothing
# nice for APIs using the iteration interface
Base.length(::CommonOPF.Generator) = 1
Base.eltype(::Type{CommonOPF.Generator}) = CommonOPF.Generator
