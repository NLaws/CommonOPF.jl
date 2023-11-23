

@testset "Conductor construction" begin
    @test_throws "Got insufficent values to define a conductor" CommonOPF.Conductor(; busses=("b1", "b2"), name="edge1")
    c1 = CommonOPF.Conductor(; busses=("b1", "b2"), name="edge1", template="edge2")
    c2 = CommonOPF.Conductor(;
        Dict(:busses => ("b1", "b2"), :name => "edge1", :r0 => 0.1, :x0 => 0.2, :length => 20)...
    )
    @test c1.name == c2.name
    @test c1.busses == c2.busses
end

@testset "basic yaml inputs" begin
    fp = joinpath("data", "yaml_inputs", "bad.yaml")
    @test_throws "missing requried keys" Network(fp)

    fp = joinpath("data", "yaml_inputs", "basic.yaml")
    net = Network(fp)
    es = edges(net)
    @test ("b1", "b2") in es && ("b2", "b3") in es
    bs = busses(net)
    @test "b1" in bs && "b2" in bs && "b3" in bs
    @test net.substation_bus == "b1"
    @test net.Sbase == 1e6
    @test net.Vbase == 1

    @test net.graph["b1", "b2"][:Conductor][:r0] == 0.1    
end