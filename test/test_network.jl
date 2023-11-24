

@testset "Conductor single phase construction" begin
    @test_throws "Got insufficent values to define single phase conductor impedance" CommonOPF.Conductor(; busses=("b1", "b2"), name="edge1")
    c1 = CommonOPF.Conductor(; busses=("b1", "b2"), name="edge1", template="edge2", length=1.2)
    c2 = CommonOPF.Conductor(;
        Dict(:busses => ("b1", "b2"), :name => "edge1", :r0 => 0.1, :x0 => 0.2, :length => 20)...
    )
    @test c1.name == c2.name
    @test c1.busses == c2.busses
end

@testset "Network single phase" begin
    fp = joinpath("data", "yaml_inputs", "no_conductors.yaml")
    @test_throws "missing requried keys" Network(fp)

    fp = joinpath("data", "yaml_inputs", "basic_single_phase.yaml")
    net = Network(fp)
    es = edges(net)
    @test ("b1", "b2") in es && ("b2", "b3") in es
    bs = busses(net)
    @test "b1" in bs && "b2" in bs && "b3" in bs
    @test net.substation_bus == "b1"
    @test net.Sbase == 1e6
    @test net.Vbase == 1

    @test net.graph["b1", "b2"][:Conductor][:r1] == 0.301
    for edge_data in conductors(net)
        @test haskey(edge_data, :r1) || haskey(edge_data, :template)
    end

    @test net.graph["b1", "b2"] == net[("b1", "b2")]

    # missing input values for conductors
    fp = joinpath("data", "yaml_inputs", "missing_vals.yaml")
    net = Network(fp)
    @test_throws "No conductor template" zij("b2", "b3", net)
    @test_throws "Missing at least one of r0" zij("b1", "b2", net)
    @test_warn "Missing templates" CommonOPF.check_missing_templates(net)
    add_edge!(net, "b2", "b4")  # o.w. get key error for net[("b2", "b4")]
    @test_throws "No conductor found" zij("b2", "b4", net)

end

@testset "Network multi-phase" begin
    fp = joinpath("data", "yaml_inputs", "basic_multi_phase.yaml")
    net = Network(fp)

    # test the different ways to define impedance
    # 1. z0 and z1
    cdict = net[("b1", "b2")][:Conductor]
    # 2. template (TODO in validate_multiphase_conductors!)

    # 3. lower diagaonal matrices

    # test warnings for missing, required inputs

end