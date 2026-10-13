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
    pmax_kw::Real = 0.0
    pmin_kw::Real = 0.0
    charge_efficiency::Real = 0.9
    discharge_efficiency::Real = 0.9
    soc_max_kwh::Real = 1.0
    soc_min_kwh::Real = 0.0
    soc_init_kwh::Real = 0.0
end


battery_busses(net::Network) = collect(
    b for b in busses(net) if haskey(net[b], :Battery)
)
