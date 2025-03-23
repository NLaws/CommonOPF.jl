"""
    struct Capacitor <: AbstractBus

Required fields:
- `bus::String`
- `kvar1::Real` reactive power in kVaR on phase1
- `kvar2::Real` reactive power in kVaR on phase2
- `kvar3::Real` reactive power in kVaR on phase4

Only modeling fixed capacitors so far. Positive kvar values are injected.
"""
@with_kw struct Capacitor <: AbstractBus
    # required values
    bus::String
    # optional values
    kvar1::Real = 0.0
    kvar2::Real = 0.0
    kvar3::Real = 0.0
end

capacitor_busses(net::Network) = collect(
    b for b in busses(net) if haskey(net[b], :Capacitor)
)
