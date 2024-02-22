@testset "graph methods" begin
    net = Network_IEEE13_SinglePhase()
    g = net.graph

    bs, depths = busses_from_deepest_to_source(g, "650")
    @test depths[end] == 0 && bs[end] == "650"
    @test depths[end-1] == 1 && bs[end-1] == "632"
    # three equally deep leaf nodes
    @test "675" in bs[1:3] && depths[1] == 5
    @test "652" in bs[1:3] && depths[2] == 5
    @test "611" in bs[1:3] && depths[3] == 5
end