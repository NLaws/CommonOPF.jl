@testset "network reduction" begin

    @testset "trim_above_bus!" begin
    
        net = Network_IEEE13_SinglePhase()
        busses_before_trim = collect(busses(net))
        edges_before_trim = collect(edges(net))
        trim_above_bus!(net.graph, "670")
        busses_after_trim = collect(busses(net))
        edges_after_trim = collect(edges(net))
        busses_deleted = setdiff(busses_before_trim, busses_after_trim)
        edges_deleted = setdiff(edges_before_trim, edges_after_trim)
        
        @test "632" in busses_deleted
        @test "645" in busses_deleted
        @test "646" in busses_deleted
        @test "633" in busses_deleted
        @test "634" in busses_deleted
        @test "650" in busses_deleted
        @test length(busses_deleted) == 6
    
        @test ("632", "670") in edges_deleted
        @test ("632", "645") in edges_deleted
        @test ("645", "646") in edges_deleted
        @test ("650", "632") in edges_deleted
        @test ("632", "633") in edges_deleted
        @test ("633", "634") in edges_deleted
        @test length(edges_deleted) == 6
    
    end
    
    @testset "reduce_tree! and trim_tree! SinglePhase" begin
        #=           c -- e                     -- e
                    / [1,2]                   /
        a -[1,2,3]- b           ->       a -- b
                    \ [2,3]                   \
                    d -- f                     -- f
        nodes c and d should be removed b/c there is no load at them and the phases are the same
        on both sides
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

        reduce_tree!(net)
        
        @test !("c" in busses(net))
        @test !("d" in busses(net))
        @test !(("b", "c") in edges(net))
        @test !(("b", "d") in edges(net))
        @test !(("c", "e") in edges(net))
        @test !(("d", "f") in edges(net))
        @test ("b", "e") in edges(net)
        @test ("b", "f") in edges(net)

        # remove the load at bus e and test for removal of edges (b, c) and (c, e)
        net = Network(net_dict)
        delete!(net.graph["e"], :Load)
        trim_tree!(net)
        @test !("c" in busses(net))
        @test !("e" in busses(net))
        @test !(("b", "c") in edges(net))
        @test !(("c", "e") in edges(net))
    end

    @testset "merge parallel single phase lines" begin
        #= 
               c -- e                   
              /       \                    
        a -- b         g      ->   a -- b -- cd -- ef -- g
              \       /                     
               d -- f            
               
        Merge parallel lines sets that do not have loads
        =#
        
        edge_tuples = [("a", "b"), ("b", "c"), ("b", "d"), ("c", "e"), ("d", "f"), ("e", "g"), ("f", "g")]
        conductors = [
            CommonOPF.Conductor(;
                busses = et,
                length = 1,
                r1 = 1.0,
                x1 = 1.0
            ) for et in edge_tuples
        ]
        g = make_graph(conductors; directed=true)
    
        end_bs = busses_with_multiple_inneighbors(g)  # ["g"]
    
        # @test_throws "Found more than one" next_bus_above_with_outdegree_more_than_one(g, "g")
        # test_throws does not work with strings in Julia 1.7
        @test next_bus_above_with_outdegree_more_than_one(g, "b") === nothing
        @test next_bus_above_with_outdegree_more_than_one(g, "e") === "b"
        @test next_bus_above_with_outdegree_more_than_one(g, "d") === "b"
    
        @test length(end_bs) == 1
        @test end_bs == ["g"]
    
        b2 = end_bs[1]
        ins = inneighbors(g, b2)
        start_bs = unique(
            next_bus_above_with_outdegree_more_than_one.(repeat([g], length(ins)), ins)
        )
        @test start_bs == ["b"]
    
        paths = paths_between(g, start_bs[1], b2)
        @test ["c", "e"] in paths
        @test ["d", "f"] in paths
    
        # make a Network for check_paths_for_loads
        d = Dict(
            :Network => Dict(
                :substation_bus => "a"
            ),
            :Conductor => [
                Dict(
                    :busses => et,
                    :length => 1,
                    :r1 => 1.0,
                    :x1 => 1.0
                ) for et in edge_tuples
            ],
            :Load => [
                Dict(
                    :bus => "c",
                    :kws1 => [1.0],
                )
            ]
        )
        net = Network(d)
        @test_throws "not merging" check_paths_for_loads(paths, net)
        delete!(net.graph["c"], :Load)
        @test check_paths_for_loads(paths, net)
    end
    
end