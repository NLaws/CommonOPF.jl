

@testset "Conductor single phase construction" begin
    c1 = CommonOPF.Conductor(; busses=("b1", "b2"), name="edge1", template="edge2", length=1.2)
    c2 = CommonOPF.Conductor(;
        Dict(:busses => ("b1", "b2"), :name => "edge1", :r1 => 0.1, :x1 => 0.2, :length => 20)...
    )
    @test c1.name == c2.name
    @test c1.busses == c2.busses
end


@testset "Network single phase" begin
    # TODO make/test JSON
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
    @test net.graph["b1", "b2"] == net[("b1", "b2")]

    # conductors
    @test net.graph["b1", "b2"][:Conductor][:r1] == 0.301
    for edge_data in conductors(net)
        @test haskey(edge_data, :r1) || haskey(edge_data, :template)
    end

    # loads
    @test net["b3"][:Load][:kws1] == [5.6]
    @test net["b2"][:Load][:kvars1] == [1.2]
    @test net["b3", :kws, 1] == [5.6]
    @test net["b3", :kvars, 1] == [1.2]
    @test net["b3", :kws, 2] == [0]
    @test net["b3", :kvars, 2] == [0]
    @test_throws KeyError net["notabus", :kws, 2]
    @test_throws KeyError net["b3", :bad, 2]
    @test_throws KeyError net["b3", :kvar, 4]

    # missing input values for conductors
    fp = joinpath("data", "yaml_inputs", "missing_vals.yaml")
    net = Network(fp)
    @test occursin("For single phase conductors you must provide ", test_logger.logs[end].message)
    @test_throws "No conductor template" zij("b2", "b3", net)
    @test_throws "Missing at least one of r1" zij("b1", "b2", net)
    CommonOPF.check_missing_templates(net)
    @test occursin("Missing templates", test_logger.logs[end].message)
    add_edge!(net, "b2", "b4")  # o.w. get key error for net[("b2", "b4")]
    @test_throws "No conductor found" zij("b2", "b4", net)

    # extra values
    fp = joinpath("data", "yaml_inputs", "extra_conductor_field.yaml")
    @test_throws "got unsupported keyword argument" net = Network(fp)
    fp = joinpath("data", "yaml_inputs", "bus_not_in_conductors.yaml")
    net = Network(fp)
    @test occursin("not in the graph after adding edges", test_logger.logs[end].message)
end


@testset "Network multi-phase" begin
    # TODO make/test JSON
    fp = joinpath("data", "yaml_inputs", "basic_multi_phase.yaml")
    net = Network(fp)

    # test the different ways to define impedance

    # 1. z0 and z1
    conds = conductors_with_attribute_value(net, :name, "cond1-symmetric")
    @test length(conds) == 1
    cond = conds[1]
    # diagonal values
    rself = 1/3 * cond[:r0] + 2/3 * cond[:r1]
    xself = 1/3 * cond[:x0] + 2/3 * cond[:x1]
    for phs in cond[:phases]
        @test cond[:rmatrix][phs, phs] == rself
        @test cond[:xmatrix][phs, phs] == xself
    end
    # off-diagonal values
    rmutual = 1/3 * (cond[:r0] - cond[:r1])
    xmutual = 1/3 * (cond[:x0] - cond[:x1])
    for phs1 in cond[:phases], phs2 in cond[:phases]
        if phs1 != phs2
            @test cond[:rmatrix][phs1, phs2] == rmutual
            @test cond[:xmatrix][phs1, phs2] == xmutual
        end
    end

    # 2. template
    cond_template = cond
    conds = conductors_with_attribute_value(net, :name, "cond2-copy-cond1")
    @test length(conds) == 1
    cond = conds[1]
    @test cond[:rmatrix] == cond_template[:rmatrix]
    @test cond[:xmatrix] == cond_template[:xmatrix]

    # 3. lower diagaonal matrices
    conds = conductors_with_attribute_value(net, :name, "cond3-assymetric")
    @test length(conds) == 1
    cond = conds[1]
    @test cond[:rmatrix][1,2] == cond[:rmatrix][2,1] == 0.15
    @test cond[:rmatrix][3,1] == cond[:rmatrix][1,3] == 0.16
    @test cond[:rmatrix][3,2] == cond[:rmatrix][2,3] == 0.17
    @test cond[:rmatrix][1,1] == 0.31
    @test cond[:rmatrix][2,2] == 0.32
    @test cond[:rmatrix][3,3] == 0.33

    conds = conductors_with_attribute_value(net, :name, "cond4-two-phase-asymmetric")
    @test length(conds) == 1
    cond = conds[1]
    @test cond[:rmatrix][1,2] == cond[:rmatrix][2,1] == 0
    @test cond[:rmatrix][3,1] == cond[:rmatrix][1,3] == 0
    @test cond[:rmatrix][3,2] == cond[:rmatrix][2,3] == 0.15
    @test cond[:rmatrix][1,1] == 0
    @test cond[:rmatrix][2,2] == 0.32
    @test cond[:rmatrix][3,3] == 0.33

    # test load definitions
    lbs = collect(load_busses(net))
    @test "b3" in lbs && "b5" in lbs

    # test warnings for missing, required inputs
    clear_log!(test_logger)
    fp = joinpath("data", "yaml_inputs", "multi_phase_missing_vals.yaml")
    expected_msgs = [
        "Unable to process impedance",
        "Missing templates: [\"cond1-symmetric\"]", 
        "1 conductors do not have", 
        "1 conductors are missing phases"
    ]
    net = Network(fp)
    for log in test_logger.logs
        @test any(( occursin(msg, log.message) for msg in expected_msgs ))
    end

end


@testset "IEEE 13 bus" begin
    fp = joinpath("data", "yaml_inputs", "ieee13.yaml")
    net = Network(fp)
    @test is_connected(net)
    # TODO Bus 634 is not in the graph after adding edges
    @test i_to_j("671", net) == ["670"]
    # TODO 670 can be reduced out to make 632 --> 670
end