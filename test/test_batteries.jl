@testset "Battery" begin
    @testset "defaults" begin
        battery = CommonOPF.Battery(; bus="B")
        @test battery.bus == "B"
        @test ismissing(battery.name)
        @test battery.pmax_kw == 0.0
        @test battery.pmin_kw == 0.0
        @test battery.charge_efficiency == 0.9
        @test battery.discharge_efficiency == 0.9
        @test battery.soc_max_kwh == 1.0
        @test battery.soc_min_kwh == 0.0
    end

    battery = CommonOPF.Battery(;
        bus="B",
        name="Battery B",
        pmax_kw=10.0,
        pmin_kw=1.0,
        charge_efficiency=0.9,
        discharge_efficiency=0.85,
        soc_max_kwh=20.0,
        soc_min_kwh=2.0,
    )
    @test battery isa CommonOPF.Battery
    @test battery.bus == "B"
    @test battery.name == "Battery B"
    @test battery.pmax_kw == 10.0
    @test battery.pmin_kw == 1.0
    @test battery.charge_efficiency == 0.9
    @test battery.discharge_efficiency == 0.85
    @test battery.soc_max_kwh == 20.0
    @test battery.soc_min_kwh == 2.0

    net = Network_IEEE5()

    @test battery_busses(net) == []

    net["B"][:Battery] = battery
    @test battery_busses(net) == ["B"]
end
