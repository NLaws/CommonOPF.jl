# @testset "busses" begin 
# CANNOT HAVE struct DEFINED INSIDE AN INNER @testset ¯¯\_(“/)_/¯¯ 
    bus_dicts = [
        Dict{Symbol,Any}(
            :bus => s
        ) for s in ["a", "b", "c"]
    ]
    #= option shift A =#
    struct NotSubTypeOfBus <: CommonOPF.AbstractEdge end

    @test_throws AssertionError CommonOPF.build_busses(bus_dicts, NotSubTypeOfBus)


    @with_kw struct TestBusType <: CommonOPF.AbstractBus
        bus::String
    end
# end