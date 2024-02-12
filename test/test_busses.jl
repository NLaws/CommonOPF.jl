@testset "Required values for busses" begin
    for EType in subtypes(CommonOPF.AbstractBus)
        @test_throws "Field 'bus' has no default" EType()
    end
end

# @testset "build_busses" begin 
# CANNOT HAVE struct DEFINED OR INSTANTIATED INSIDE AN INNER @testset ¯¯\_(“/)_/¯¯ 
    bus_dicts = [
        Dict{Symbol,Any}(
            :bus => s
        ) for s in ["a", "b", "c"]
    ]

    NotSubTypeOfBus = CommonOPF.Conductor
    #= fun fact: option shift A gives you block comments =#
    @test_throws AssertionError CommonOPF.build_busses(bus_dicts, NotSubTypeOfBus)

    @with_kw struct TestBusType <: CommonOPF.AbstractBus
        bus::String
    end
    concrete_test_busses = CommonOPF.build_busses(bus_dicts, TestBusType)
    @test all(typeof(ctb) == TestBusType for ctb in concrete_test_busses)
    @test length(concrete_test_busses) == length(bus_dicts)
# end

@testset "Load" begin
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


@testset "ShuntAdmittance" begin
    shunt = CommonOPF.ShuntAdmittance(;
        bus="b",
        g=1,
        b=1.1,
    )
end