@testset "Required values for edges" begin
    for EType in subtypes(CommonOPF.AbstractEdge)
        @test_throws "Field 'busses' has no default" EType()
    end
end

# @testset "build_edges" begin 
    edge_dicts = [
        Dict{Symbol,Any}(
            :busses => (a, b)
        ) for (a, b) in [("1", "2"), ("2", "3")]
    ]

    NotSubTypeOfEdge = CommonOPF.Load

    @test_throws AssertionError CommonOPF.build_edges(edge_dicts, NotSubTypeOfEdge)

    @with_kw struct TestEdgeType <: CommonOPF.AbstractEdge
        busses::Tuple{String, String}
    end
    concrete_test_edges = CommonOPF.build_edges(edge_dicts, TestEdgeType)
    @test all(typeof(ctb) == TestEdgeType for ctb in concrete_test_edges)
    @test length(concrete_test_edges) == length(edge_dicts)
    delete
# end


@testset "Transformer" begin
    # test single and multiphase, where resistance gets put in diagonal matrix
end


@testset "VoltageRegulator" begin
    # Next
end
