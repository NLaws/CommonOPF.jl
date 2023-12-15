"""
    struct ShuntImpedance <: AbstractBus

Required fields:
- `bus::String`
- `r::Real`  resistance in Ω
- `x::Real`  reactance in Ω
"""
@with_kw struct ShuntImpedance <: AbstractBus
    # required values
    bus::String
    r::Real
    x::Real
    # TODO matrices for MultiPhase models ?
end


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
