@testset "Battery" begin
    battery = CommonOPF.Battery(;
        bus="B",
        pmax=10.0,
        pmin=1.0,
        charge_efficiency=0.9,
        discharge_efficiency=0.85,
    )
    @test battery isa CommonOPF.Battery

    net = Network_IEEE5()

    @test battery_busses(net) == []

    net["B"][:Battery] = battery
    @test battery_busses(net) == ["B"]
end