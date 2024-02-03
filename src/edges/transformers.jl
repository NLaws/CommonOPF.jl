"""
    @with_kw mutable struct Transformer <: AbstractEdge

!!! note
    For now the `high_kv` and `low_kv` values are only for reference. Throughout the modules that use
    CommonOPF we model in per-unit voltage. In the future we may add capability for scaling to absolute
    voltage in the future (in Results for example).

When `phases` are not provided the model is assumed to be single phase.

Series impedance defaults to zero.
"""
@with_kw mutable struct Transformer <: AbstractEdge
    # required values
    busses::Tuple{String, String}
    # optional values
    high_kv::Real = 1.0
    low_kv::Real = 1.0
    phases::Union{Vector{Int}, Missing} = missing
    reactance::Real = 0.0
    resistance::Real = 0.0
end
