@testset "Battery" begin
    @testset "defaults" begin
        battery = CommonOPF.Battery(; bus="B")
        @test battery.bus == "B"
        @test ismissing(battery.name)
        @test battery.pmax == 0.0
        @test battery.pmin == 0.0
        @test battery.charge_efficiency == 0.9
        @test battery.discharge_efficiency == 0.9
        @test battery.soc_max == 1.0
        @test battery.soc_min == 0.0
        @test battery.soc_init == 0.0
    end

    battery = CommonOPF.Battery(;
        bus="B",
        name="Battery B",
        pmax=10.0,
        pmin=1.0,
        charge_efficiency=0.9,
        discharge_efficiency=0.85,
        soc_max=20.0,
        soc_min=2.0,
        soc_init=10.0
    )
    @test battery isa CommonOPF.Battery
    @test battery.bus == "B"
    @test battery.name == "Battery B"
    @test battery.pmax == 10.0
    @test battery.pmin == 1.0
    @test battery.charge_efficiency == 0.9
    @test battery.discharge_efficiency == 0.85
    @test battery.soc_max == 20.0
    @test battery.soc_min == 2.0
    @test battery.soc_init == 10.0

    net = Network_IEEE5()

    @test battery_busses(net) == []

    net["B"][:Battery] = battery
    @test battery_busses(net) == ["B"]
end
