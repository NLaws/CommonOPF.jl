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
    fp = joinpath("data", "yaml_inputs", "ieee13_multi_phase.yaml")
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
end
