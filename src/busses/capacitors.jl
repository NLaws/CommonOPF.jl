"""
    struct Capacitor <: AbstractBus

Required fields:
- `bus::String`
- `q1::Real` reactive power on phase1
- `q2::Real` reactive power on phase2
- `q3::Real` reactive power on phase4

Only modeling fixed capacitors so far. Positive `q` values are injected.
"""
@with_kw struct Capacitor <: AbstractBus
    # required values
    bus::String
    # optional values
    q1::Real = 0.0
    q2::Real = 0.0
    q3::Real = 0.0
    fixed::Bool = true
end

capacitor_busses(net::Network) = collect(
    b for b in busses(net) if haskey(net[b], :Capacitor)
)
