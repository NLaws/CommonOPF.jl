@testset "Required values for subtypes of AbstractBus" begin
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
    expected_busses = Set(["670", "680", "684", "692"])
    @test connected_busses("671", net) == expected_busses
end


@testset "BUS_TYPES_DUPLICATES_ALLOWED" begin
    # there are two generators at bus A in IEEE 5, we put them in a vector
    net = Network_IEEE5()
    @test length(net["A"][:Generator]) == 2
    @test sort(generator_busses(net)) == ["A", "C", "D", "E"]

    # test iteration
    for gbus in generator_busses(net)
        for gen in net[gbus][:Generator]
            @test gen isa CommonOPF.Generator
        end
    end
end
