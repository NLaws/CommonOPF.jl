"""
    struct Capacitor <: AbstractBus

Required fields:
- `bus::String`
- `var::Real` reactive power in VAR
"""
@with_kw struct Capacitor <: AbstractBus
    # required values
    bus::String
    var::Real
    # TODO matrices for MultiPhase models
end
