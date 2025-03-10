@testset "shunt inputs and methods" begin

    @testset "single phase" begin
        net = Network_Papavasiliou_2018()
        @test real(yj("1", net)) ≈ 0.0
        @test imag(yj("1", net)) ≈ 0.0011

    end

    @testset "multi phase" begin
        fp = joinpath(@__DIR__, "data", "case3_unbalanced.dss")
        net = Network(fp)
        f = 2π*60 * 1e-9  # nanofarads to siemens
        @test all(imag(yj("primary", net)) .≈ f * [25.0 0 0; 0 25 0; 0 0 25])
        @test all(imag(yj("loadbus", net)) .≈ f * [20.0 0 0; 0 20 0; 0 0 20])
    end

end
