"""
    struct Generator <: AbstractBus

Required fields:
- `bus::String`
"""
@with_kw struct Generator <: AbstractBus
    # required values
    bus::String
    # optional values
    is_PV_bus::Bool = false
    kws1::Vector{Real} = [0.0]
    voltage_pu::Vector{Real} = [1.0]
end

generator_busses(net::Network{SinglePhase}) = collect(
    b for b in busses(net) if haskey(net[b], :Generator)
)
