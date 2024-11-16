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


@testset "sj power getters" begin
    net = Network_IEEE13_SinglePhase()
    net.Sbase = 1e6
    @test sj("634", net) ≈ [-133.33 + -im*96.67]
    @test sj_per_unit("634", net) ≈ [-133.33 + -im*96.67] / 1e3
end