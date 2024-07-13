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
    g::Real = 0.0
    b::Real = 0.0
    gmatrix::AbstractArray = zeros(3,3)
    bmatrix::AbstractArray = zeros(3,3)
end
