"""
    struct ShuntImpedance <: AbstractBus
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
"""
@with_kw struct ShuntAdmittance <: AbstractBus
    # required values
    bus::String
    g::Real
    b::Real
    # TODO matrices for MultiPhase models ?
end
