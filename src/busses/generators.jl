"""
    struct Generator <: AbstractBus

Required fields:
- `bus::String`

Fields correspond to the columns of the PSS/E RAW v33 generator data
section so that generator specifications from RAW files can be loaded
directly into a [`Network`](@ref).
"""
@with_kw struct Generator <: AbstractBus
    # required values
    bus::String
    # optional values
    is_PV_bus::Bool = false
    kws1::Vector{Real} = [0.0]
    voltage_pu::Vector{Real} = [1.0]
    # RAW file fields
    id::String = "1"
    pg::Real = 0.0          # MW output
    qg::Real = 0.0          # MVAr output
    qmax::Real = 0.0        # MVAr max
    qmin::Real = 0.0        # MVAr min
    vg::Real = 1.0          # voltage setpoint (pu)
    reg_bus::Int = 0        # remote regulated bus number
    mva_base::Real = 100.0
    zr::Real = 0.0
    zx::Real = 0.0
    rt::Real = 0.0
    xt::Real = 0.0
    gtap::Real = 1.0
    status::Int = 1
    rmpct::Real = 100.0
    pmax::Real = 0.0
    pmin::Real = 0.0
end

generator_busses(net::Network{SinglePhase}) = collect(
    b for b in busses(net) if haskey(net[b], :Generator)
)
