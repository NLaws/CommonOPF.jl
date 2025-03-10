@testset "Load struct" begin
    bad_load = CommonOPF.Load(; bus="bname")  # no load defined
    # a warning should be logged about removing bad_load
    loads = CommonOPF.Load[bad_load]
    clear_log!(test_logger)
    CommonOPF.check_busses!(loads)
    @test occursin("has been removed", test_logger.logs[end].message)
    @test isempty(loads)

    # test fill_load
    load = CommonOPF.Load(;
        bus="bname",
        q_to_p=0.1,
        kws1=[10],
        kws2=[20],
        kws3=[30],
    )
    CommonOPF.fill_load!(load)
    @test load.kvars1 == [1]
    @test load.kvars2 == [2]
    @test load.kvars3 == [3]
end


@testset "power getters" begin
    # SinglePhase
    net = Network_IEEE13_SinglePhase()
    net.Ntimesteps = 1
    net.Sbase = 1e6
    bus = "634"
    expected_p = -133.33
    expected_q = -im*96.67
    @test sj(bus, net) ≈ [expected_p + expected_q]
    @test sj_per_unit(bus, net) ≈ [expected_p + expected_q] / 1e3

    # MultiPhase
    dssfilepath = joinpath(@__DIR__, "data", "ieee13", "IEEE13Nodeckt.dss")
    net = Network(dssfilepath)
    net.Ntimesteps = 1
    net.Sbase = 1e3
    Pj, Qj = sj_per_unit(bus, net)
    @test Pj == [[-160.0], [-120.0], [-120.0]]
    @test Qj == [[-110.0], [-90.0], [-90.0]]
end