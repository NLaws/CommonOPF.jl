@testset "model construction utilities" begin

    # matrix_phases_to_vec used to build multiphase KVL
    M = [1 2 3; 4 5 6; 7 8 9]

    phases = [2, 3]
    v = matrix_phases_to_vec(M, phases)
    @test v == [5, 6, 8, 9]

    phases = [1]
    v = matrix_phases_to_vec(M, phases)
    @test v == [1]

    phases = [1, 2, 3]
    v = matrix_phases_to_vec(M, phases)
    @test v == [1, 2, 3, 4, 5, 6, 7, 8, 9]

    # phi_ij
    fp = joinpath(@__DIR__, "data", "yaml_inputs", "ieee13_multi_phase.yaml")
    net = Network(fp)
    # bus 684 has only phases [1, 3]
    m = phi_ij("684", net, M)
    @test m[1,1] == M[1,1]
    @test m[2,2] == 0  # diagonal values real
    @test m[1,2] == 0im  # off-diagonal values complex

    v = [1im, 2, 3]
    v = phi_ij("684", net, v)
    @test v[1] == 1im
    @test v[2] == 0im

    # substation_voltage
    net.v0 = 1.0
    v = substation_voltage(net)
    # real scalar v0 turned into complex vector with 120 deg phase shifts
    @test all(v .== [1.0 + 0im, -0.5 - im * sqrt(3) / 2, -0.5 + im * sqrt(3) / 2])
    # similar for real vector
    net.v0 = convert(Vector{Float64}, [1.01, 1.02, 1.03])
    v = substation_voltage(net)
    @test all(v .== [
        net.v0[1] + 0im, 
        net.v0[2]*(-0.5 - im * sqrt(3) / 2), 
        net.v0[3]*(-0.5 + im * sqrt(3) / 2)
    ])
    # a complex vector is unmodified
    net.v0 = [1im, 2im, 3im]
    v = substation_voltage(net)
    @test all(v .== net.v0)
end
