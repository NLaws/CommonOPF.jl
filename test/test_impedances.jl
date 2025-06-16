@testset "default branch impedance, SinglePhase rij, xij, zij" begin
    r1 = 0.1
    x1 = 0.2
    b1 = "1"
    b2 = "2"
    Zbase = 3.1
    net = Network(Dict(
        :Network => Dict(
            :substation_bus => b1,
            :Zbase => Zbase
        ),
        :Conductor => [
            Dict{Symbol, Any}(
                :busses => (b1, b2),
                :r1 => r1,
                :x1 => x1,
                :length => 1
            ),
        ]
    ))

    missing_edge = net[("1", "3")]

    @test CommonOPF.resistance(missing_edge, SinglePhase) == CommonOPF.DEFAULT_IMPEDANCE_SINGLE_PHASE
    @test CommonOPF.resistance(missing_edge, MultiPhase) == CommonOPF.DEFAULT_IMPEDANCE_MULTI_PHASE

    @test CommonOPF.reactance(missing_edge, SinglePhase) == CommonOPF.DEFAULT_IMPEDANCE_SINGLE_PHASE
    @test CommonOPF.reactance(missing_edge, MultiPhase) == CommonOPF.DEFAULT_IMPEDANCE_MULTI_PHASE

    z = r1 + im * x1

    @test rij(b1, b2, net) ≈ real(z)
    @test xij(b1, b2, net) ≈ imag(z)
    @test zij(b1, b2, net) ≈ z

    @test rij_per_unit(b1, b2, net) ≈ real(z) / net.Zbase
    @test xij_per_unit(b1, b2, net) ≈ imag(z) / net.Zbase
    @test zij_per_unit(b1, b2, net) ≈ z / net.Zbase

end