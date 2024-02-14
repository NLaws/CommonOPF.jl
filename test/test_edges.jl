@testset "Required values for edges" begin
    for EType in subtypes(CommonOPF.AbstractEdge)
        @test_throws "Field 'busses' has no default" EType()
        concrete_edge = EType(;busses=("a", "b"))
        @test ismissing(concrete_edge.phases)
        @test ismissing(concrete_edge.rmatrix)
        @test ismissing(concrete_edge.xmatrix)
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
    t1 = CommonOPF.Transformer(;
        busses=("a", "b"),
        reactance=1,
        resistance=0.5
    )
    @test CommonOPF.check_edges!([t1]) == true
    t1.phases = [2,3]
     # fill_impedance_matrices! is called in check_edges! via validate_multiphase_edges!
    @test CommonOPF.check_edges!([t1]) == true
    @test t1.rmatrix == [0 0 0; 0 t1.resistance 0; 0 0 t1.resistance]
    @test t1.xmatrix == [0 0 0; 0 t1.reactance 0; 0 0 t1.reactance]

    # missing values
    t1.phases = missing
    @test CommonOPF.validate_multiphase_edges!([t1]) == false
end


@testset "VoltageRegulator" begin
    # Next
    # fill_impedance_matrices!
end
