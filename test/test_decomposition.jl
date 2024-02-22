@testset "decomposition" begin
    net = dss_to_Network(joinpath("data", "singlephase38lines", "master.dss"))
    # these tests were in BFM using singlephase38lines, which is as simple as dss files get
    # so it is a good network to test the OpenDSS to Network stuff first
    net_above, net_below = split_network(net, "12");
    @test intersect(busses(net_above), busses(net_below)) == ["12"]
    @test length(busses(net)) == length(busses(net_below)) + length(busses(net_above)) - 1
    @test isempty(intersect(edges(net_above), edges(net_below)))
    @test length(edges(net)) == length(edges(net_below)) + length(edges(net_above))
    # splitting at 12 should put 12-25 in net_below (except for the removed busses)
    for b in string.(12:25)
        @test b in busses(net_below)
    end
end