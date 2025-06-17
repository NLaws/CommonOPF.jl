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

@testset "all_inneighbors and all_outneighbors" begin
    # construct a small directed graph
    #   a -> b -> c -> d
    #        |    |
    #        v    v
    #        e    f
    edge_tuples = [
        ("a", "b"),
        ("b", "c"),
        ("c", "d"),
        ("b", "e"),
        ("c", "f"),
    ]

    conductors = [
        CommonOPF.Conductor(; busses = et)
        for et in edge_tuples
    ]
    g = make_graph(conductors; directed = true)

    # `all_inneighbors` should find every upstream bus of "d" as well as
    # any branches encountered along the way: {"a", "b", "c", "e", "f"}
    innies = all_inneighbors(g, "d", String[])
    @test sort(innies) == sort(["a", "b", "c", "e", "f"])

    # `all_outneighbors` should return all busses reachable downstream
    # from "b": {"c", "d", "e", "f"}
    outs = all_outneighbors(g, "b", String[], String[])
    @test sort(outs) == sort(["c", "d", "e", "f"])
end
