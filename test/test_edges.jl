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
    e1 = concrete_test_edges[1]
    @test CommonOPF.resistance(e1, CommonOPF.SinglePhase) == 0
    @test CommonOPF.reactance(e1, CommonOPF.SinglePhase) == 0
    @test CommonOPF.resistance_per_length(e1, CommonOPF.SinglePhase) == 0
    @test CommonOPF.reactance_per_length(e1, CommonOPF.SinglePhase) == 0
# end


@testset "Transformer" begin
    # test single and multiphase, where resistance gets put in diagonal matrix
    t1 = CommonOPF.Transformer(;
        busses=("a", "b"),
        reactance=1,
        resistance=0.5
    )
    @test CommonOPF.check_edges!([t1]) == true
    @test CommonOPF.resistance(t1, CommonOPF.SinglePhase) == t1.resistance
    @test CommonOPF.reactance(t1, CommonOPF.SinglePhase) == t1.reactance
    # multiphase
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
    # single phase
    vr = CommonOPF.VoltageRegulator(;
        busses=("a", "b"),
        reactance=1,
        resistance=0.5,
        turn_ratio=1.02
    )
    @test CommonOPF.check_edges!([vr]) == true
    vr.turn_ratio = missing
    vr.vreg_pu = 1.04
    @test CommonOPF.check_edges!([vr]) == true
    @test CommonOPF.resistance(vr, CommonOPF.SinglePhase) == vr.resistance
    @test CommonOPF.reactance(vr, CommonOPF.SinglePhase) == vr.reactance

    # multiphase
    vr.phases = [2,3]
     # fill_impedance_matrices! is called in check_edges! via validate_multiphase_edges!
    @test CommonOPF.check_edges!([vr]) == true
    @test vr.rmatrix == [0 0 0; 0 vr.resistance 0; 0 0 vr.resistance]
    @test vr.xmatrix == [0 0 0; 0 vr.reactance 0; 0 0 vr.reactance]

    # missing values
    vr.phases = missing
    @test CommonOPF.validate_multiphase_edges!([vr]) == false
    vr.vreg_pu = missing
    @test CommonOPF.check_edges!([vr]) == false
end
