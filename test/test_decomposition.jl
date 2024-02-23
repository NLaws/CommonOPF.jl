@testset "decomposition" begin

    # split_network
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

    # splitting_busses
    max_bs = 15
    splitting_bs, subgraph_bs = CommonOPF.splitting_busses(net, "0"; max_busses=max_bs)
    @test length(splitting_bs) == 2
    @test splitting_bs[1] == "11"
    @test length(subgraph_bs) == 2
    @test length(subgraph_bs[1]) == 15
    @test isempty(intersect(subgraph_bs[1], subgraph_bs[2]))
    remaining_bs = setdiff(busses(net), union(subgraph_bs...))
    @test all(length(sgbs) <= max_bs for sgbs in [subgraph_bs..., remaining_bs])


    @testset "split_at_busses, split_network" begin
        #=     c -- e                    c | c -- e
              /                         /
        a -- b           ->   a -- b | b
              \                         \
               d -- f                    d | d -- f
        =#
        net_dict = Dict(
            :Network => Dict(
                :substation_bus => "a",
            ),
            :Conductor => [
                Dict(
                    :busses => ("a", "b"),
                    :length => 1,
                    :r1 => 1.0, 
                    :x1 => 1.0,
                    :name => "l1"
                ),
                Dict(
                    :busses => ("b", "c"),
                    :length => 1,
                    :template => "l1"
                ),
                Dict(
                    :busses => ("b", "d"),
                    :length => 1,
                    :template => "l1"
                ),
                Dict(
                    :busses => ("c", "e"),
                    :length => 1,
                    :template => "l1"
                ),
                Dict(
                    :busses => ("d", "f"),
                    :length => 1,
                    :template => "l1"
                ),
            ],
            :Load => [
                Dict(
                    :bus => "e",
                    :kws1 => [1.0],
                    :kvars1 => [0.1]
                ),
                Dict(
                    :bus => "f",
                    :kws1 => [1.0],
                    :kvars1 => [0.1]
                )
            ]
        )
        net = Network(net_dict)

        mg = split_at_busses(net, ["c", "d", "b"])
        @test outneighbors(mg, 1) == [4]
        @test outneighbors(mg, 4) == [2, 3]
        @test outneighbors(mg, 2) == outneighbors(mg, 3) == Int[]

        net_above, net_below = split_network(net, "b", ["b", "c", "e"])
        @test length(busses(net_below)) == 3
        @test "b" in busses(net_below) && "c" in busses(net_below) && "e" in busses(net_below)
        @test length(busses(net_above)) == 4
        @test "b" in busses(net_above) && "a" in busses(net_above) 
        @test "d" in busses(net_above) && "f" in busses(net_above)
        @test length(edges(net_below)) == 2
        @test ("b", "c") in edges(net_below) && ("c", "e") in edges(net_below)
        @test length(edges(net_above)) == 3
        @test ("a", "b") in edges(net_above)
        @test ("b", "d") in edges(net_above)
        @test ("d", "f") in edges(net_above)
    end


end