@testset "basic yaml inputs" begin
    fp = joinpath("data", "yaml_inputs", "basic.yaml")
    net = Network(fp)
    @test ("b1", "b2") in net.edges
    @test "b1" in net.busses && "b2" in net.busses && "b3" in net.busses
end