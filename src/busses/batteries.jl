"""
    struct Battery <: AbstractBus

Required fields:
- `bus::String`

Work in progress. Adding fields as needed for BIM and BFM tests.
"""
@with_kw struct Battery <: AbstractBus
    # required values
    bus::String
    # optional values
    name::Union{String, Missing} = missing
    pmax::Real = 0.0
    pmin::Real = 0.0
    charge_efficiency::Real = 1.0
    discharge_efficiency::Real = 1.0
end


battery_busses(net::Network) = collect(
    b for b in busses(net) if haskey(net[b], :Battery)
)
