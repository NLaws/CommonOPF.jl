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
    kws1::Vector{Real} = [0.0]
    voltage_series_pu::Vector{Real} = [1.0]
    # RAW file fields
    name::Union{String, Missing} = missing
    pg::Real = 0.0          # MW output
    qg::Real = 0.0          # MVAr output
    q_max_kvar::Real = 0.0
    q_min_kvar::Real = 0.0
    voltage_pu::Real = 1.0          # voltage setpoint (pu)
    reg_bus::Union{String, Missing} = missing  # remote regulated bus
    mva_base::Real = 100.0
    z_transformers::ComplexF64 = im*0.0
    gtap::Real = 1.0
    status::Int = 1
    rmpct::Real = 100.0
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
