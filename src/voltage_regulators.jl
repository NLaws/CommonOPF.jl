# use these in LoadFlow first to confirm test results
# then in BFM to continue the transition to Network from Inputs
"""
    struct VoltageRegulator <: AbstractBus
"""
@with_kw struct VoltageRegulator <: AbstractBus
    # required values
    bus::String
    vreg_pu::Real
    # optional values
    phases::Union{Vector{Int}, Missing} = missing
end
