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

@testset "default overhead impedance by kv_class, SinglePhase" begin
    # one conductor with a kv_class
    b1 = "1"
    b2 = "2"
    Zbase = 3.1
    kv_class = 115
    net = Network(Dict(
        :Network => Dict(
            :substation_bus => b1,
            :Zbase => Zbase
        ),
        :Conductor => [
            Dict{Symbol, Any}(
                :busses => (b1, b2),
                :kv_class => kv_class,
                :length => 1
            ),
        ]
    ))

    expected_r = CommonOPF.OVERHEAD_LINE_IMPEDANCES_BY_KV[kv_class][:R_ohm_per_km]
    expected_x = CommonOPF.OVERHEAD_LINE_IMPEDANCES_BY_KV[kv_class][:X_ohm_per_km]

    @test CommonOPF.resistance(net[(b1, b2)], SinglePhase) == expected_r
    @test CommonOPF.reactance(net[(b1, b2)], SinglePhase) == expected_x

    z = expected_r + im * expected_x
    @test rij(b1, b2, net) ≈ expected_r
    @test xij(b1, b2, net) ≈ expected_x
    @test zij(b1, b2, net) ≈ z

    @test rij_per_unit(b1, b2, net) ≈ expected_r / net.Zbase
    @test xij_per_unit(b1, b2, net) ≈ expected_x / net.Zbase
    @test zij_per_unit(b1, b2, net) ≈ z / net.Zbase

    # an invalid kv_class values
    bad_kv_class = 123

    clear_log!(test_logger)
    net = Network(Dict(
        :Network => Dict(
            :substation_bus => b1,
            :Zbase => Zbase
        ),
        :Conductor => [
            Dict{Symbol, Any}(
                :busses => (b1, b2),
                :kv_class => bad_kv_class,
                :length => 1
            ),
        ]
    ))

    @test occursin(
        "kv_class $bad_kv_class not available", 
        test_logger.logs[end].message
    )
    @test ismissing(rij(b1, b2, net))
    @test ismissing(xij(b1, b2, net))
    @test ismissing(rij_per_unit(b1, b2, net))
    @test ismissing(xij_per_unit(b1, b2, net))
    
end
