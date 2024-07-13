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
    yj(j::AbstractString, net::Network{MultiPhase})::Matrix{ComplexF64}

Shunt admittance of bus `j`
"""
function yj(j::AbstractString, net::Network{MultiPhase})::Matrix{ComplexF64}
    if :ShuntAdmittance in keys(net[j])
        return net[j][:ShuntAdmittance].gmatrix + im * net[j][:ShuntAdmittance].bmatrix
    end
    return zeros(3,3) + im * zeros(3,3)
end
