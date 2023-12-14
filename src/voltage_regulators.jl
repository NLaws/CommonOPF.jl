# use these in LoadFlow first to confirm test results
# then in BFM to continue the transition to Network from Inputs
"""
    struct VoltageRegulator <: AbstractBus
"""
@with_kw struct VoltageRegulator <: AbstractEdge
    # required values
    busses::Tuple{String, String}
    vreg_pu::Real
    # optional values
    phases::Union{Vector{Int}, Missing} = missing
end
