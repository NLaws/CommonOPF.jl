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
end
