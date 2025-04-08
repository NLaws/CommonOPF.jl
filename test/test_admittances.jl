@testset "test admittance getters" begin
    net = Network_IEEE8500()

    # non-existent edge gives zero admittance
    @test Yij("_hvmv_sub_lsb", "m1108508", net) == zeros(3,3) * im

end