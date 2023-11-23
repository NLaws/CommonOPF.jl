

@testset "Edge construction" begin
    e1 = CommonOPF.Edge(("b1", "b2"), "edge1")
    e2 = CommonOPF.Edge(Dict(:busses => ("b1", "b2"), :name => "edge1"))
    @test e1.name == e2.name
    @test e1.busses == e2.busses
end

@testset "basic yaml inputs" begin
    fp = joinpath("data", "yaml_inputs", "bad.yaml")
    @test_throws KeyError Network(fp)

    fp = joinpath("data", "yaml_inputs", "basic.yaml")
    net = Network(fp)
    @test ("b1", "b2") in net.edges && ("b2", "b3") in net.edges
    @test "b1" in net.busses && "b2" in net.busses && "b3" in net.busses
    @test net.substation_bus == "b1"
end