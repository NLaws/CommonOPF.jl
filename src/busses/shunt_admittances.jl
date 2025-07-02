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


"""
    yj(j::AbstractString, net::Network{SinglePhase})::ComplexF64

Shunt admittance of bus `j`
"""
function yj(j::AbstractString, net::Network{SinglePhase})::ComplexF64
    if :ShuntAdmittance in keys(net[j])
        return net[j][:ShuntAdmittance].g + im * net[j][:ShuntAdmittance].b
    end
    return 0.0 + im * 0.0
end


"""
    yj_per_unit(j::AbstractString, net::Network{SinglePhase})::ComplexF64

Shunt admittance of bus `j` times net.Zbase
"""
function yj_per_unit(j::AbstractString, net::Network{SinglePhase})::ComplexF64
    if :ShuntAdmittance in keys(net[j])
        return (net[j][:ShuntAdmittance].g + im * net[j][:ShuntAdmittance].b) * net.Zbase
    end
    return 0.0 + im * 0.0
end


"""
    yj(j::AbstractString, net::Network{MultiPhase})::Matrix{ComplexF64}

Shunt admittance of bus `j`
"""
function yj(j::AbstractString, net::Network{MultiPhase})::Matrix{ComplexF64}
    if :ShuntAdmittance in keys(net[j])
        return net[j][:ShuntAdmittance].gmatrix + im * net[j][:ShuntAdmittance].bmatrix
    end
    return zeros(3,3) + im * zeros(3,3)
end
