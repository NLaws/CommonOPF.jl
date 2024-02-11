"""
    struct ShuntAdmittance <: AbstractBus

Required fields:
- `bus::String`
- `g::Real` conductance in siemens
- `b::Real` susceptance in siemens
"""
@with_kw struct ShuntAdmittance <: AbstractBus
    # required values
    bus::String
    g::Real
    b::Real
    # TODO matrices for MultiPhase models ?
end
