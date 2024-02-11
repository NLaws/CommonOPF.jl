# @testset "build_busses" begin 
    bus_dicts = [
        Dict{Symbol,Any}(
            :bus => s
        ) for s in ["a", "b", "c"]
    ]

    # CANNOT HAVE struct DEFINED OR INSTANTIATED INSIDE AN INNER @testset ¯¯\_(“/)_/¯¯ 
    struct NotSubTypeOfBus <: CommonOPF.AbstractEdge end
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
end


@testset "ShuntAdmittance" begin
    shunt = CommonOPF.ShuntAdmittance(;
        bus="b",
        g=1,
        b=1.1,
    )
end