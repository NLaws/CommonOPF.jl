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


@testset "ShuntAdmittance" begin
    shunt = CommonOPF.ShuntAdmittance(;
        bus="b",
        g=1,
        b=1.1,
    )
end


@testset "connected_busses" begin
    net = Network_IEEE13_SinglePhase()
    expected_busses = ["670", "680", "684", "692"]
    @test sort(connected_busses("671", net)) == sort(expected_busses)
end
