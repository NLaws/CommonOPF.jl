# @testset "build_edges" begin 
    edge_dicts = [
        Dict{Symbol,Any}(
            :busses => (a, b)
        ) for (a, b) in [("1", "2"), ("2", "3")]
    ]

    # CANNOT HAVE struct DEFINED OR INSTANTIATED INSIDE AN INNER @testset ¯¯\_(“/)_/¯¯ 
    struct NotSubTypeOfEdge <: CommonOPF.AbstractBus end

    @test_throws AssertionError CommonOPF.build_edges(edge_dicts, NotSubTypeOfEdge)

    @with_kw struct TestEdgeType <: CommonOPF.AbstractEdge
        busses::Tuple{String, String}
    end
    concrete_test_edges = CommonOPF.build_busses(bus_dicts, TestEdgeType)
    @test all(typeof(ctb) == TestEdgeType for ctb in concrete_test_edges)
    @test length(concrete_test_edges) == length(edge_dicts)
    
# end


@testset "Transformer" begin
    
end


@testset "VoltageRegulator" begin
    # shunt = CommonOPF.ShuntAdmittance(;
    #     bus="b",
    #     g=1,
    #     b=1.1,
    # )
end