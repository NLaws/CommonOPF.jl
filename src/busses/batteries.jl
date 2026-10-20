"""
    struct Battery <: AbstractBus

Required fields:
- `bus::String`

Optional fields:
- `name::Union{String, Missing}` name of the battery
- `pmax::Real` maximum active power output of the battery
- `pmin::Real` minimum active power output of the battery
- `charge_efficiency::Real` efficiency of charging the battery (0.0-1.0)
- `discharge_efficiency::Real` efficiency of discharging the battery (0.0-1.0)
- `soc_max::Real` maximum state of charge of the battery
- `soc_min::Real` minimum state of charge of the battery
- `soc_init::Real` initial state of charge of the battery

Work in progress. Adding fields as needed for BIM and BFM tests.
"""
@with_kw struct Battery <: AbstractBus
    # required values
    bus::String
    # optional values
    name::Union{String, Missing} = missing
    pmax::Real = 0.0
    pmin::Real = 0.0
    charge_efficiency::Real = 0.9
    discharge_efficiency::Real = 0.9
    soc_max::Real = 1.0
    soc_min::Real = 0.0
    soc_init::Real = 0.0
end


battery_busses(net::Network) = collect(
    b for b in busses(net) if haskey(net[b], :Battery)
)

# extensions to allow `for batt in net[bus][:Battery]` regardless of number of batteries in a bus.
# first iteration over Battery: return the element and an arbitrary state
Base.iterate(b::CommonOPF.Battery) = (b, true)
# On the next iteration, stop.
Base.iterate(::CommonOPF.Battery, ::Bool) = nothing
# nice for APIs using the iteration interface
Base.length(::CommonOPF.Battery) = 1
Base.eltype(::Type{CommonOPF.Battery}) = CommonOPF.Battery
