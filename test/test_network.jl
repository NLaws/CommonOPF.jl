

@testset "Edge construction" begin
    e1 = CommonOPF.Edge(("b1", "b2"), "edge1")
    e2 = CommonOPF.Edge(Dict(:busses => ("b1", "b2"), :name => "edge1"))
    @test e1.name == e2.name
    @test e1.busses == e2.busses
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
end