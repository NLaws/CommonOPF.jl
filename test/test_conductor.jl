@testset "Conductor single phase" begin
    c1 = CommonOPF.Conductor(; busses=("b1", "b2"), name="edge1", template="edge2", length=1.2)
    c2 = CommonOPF.Conductor(;
        Dict(:busses => ("b2", "b3"), :name => "edge2", :r1 => 0.1, :x1 => 0.2, :length => 20)...
    )
    CommonOPF.warn_singlephase_conductors_and_copy_templates([c1, c2])
    @test resistance_per_length(c1) == resistance_per_length(c2) == 0.1
    @test resistance(c1) == 0.1 * 1.2
    @test resistance(c2) == 0.1 * 20
    @test reactance_per_length(c1) == reactance_per_length(c2) == 0.2
    @test reactance(c1) == 0.2 * 1.2
    @test reactance(c2) == 0.2 * 20
end
