@testset "network reduction" begin

    @testset "trim_above_bus!" begin
    
        net = Network_IEEE13_SinglePhase()
        busses_before_trim = busses(net)
        edges_before_trim = edges(net)
        trim_above_bus!(net.graph, "670")
        busses_after_trim = busses(net)
        edges_after_trim = edges(net)
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
        @test net[("b", "e")].length == 2
        @test resistance(net[("b", "e")]) == 2
        @test reactance(net[("b", "e")]) == 2

        # remove the load at bus e and test for removal of edges (b, c) and (c, e)
        net = Network(net_dict)
        delete!(net.graph["e"], :Load)
        trim_tree!(net)
        @test !("c" in busses(net))
        @test !("e" in busses(net))
        @test !(("b", "c") in edges(net))
        @test !(("c", "e") in edges(net))

        # now multiphase
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
                    :r0 => 0.0, 
                    :x0 => 0.0,
                    :phases => [1, 2, 3]
                ),
                Dict(
                    :busses => ("b", "c"),
                    :length => 1,
                    :r1 => 1.0, 
                    :x1 => 1.0,
                    :r0 => 0.0, 
                    :x0 => 0.0,
                    :name => "l1",
                    :phases => [1, 2]
                ),
                Dict(
                    :busses => ("c", "e"),
                    :length => 1,
                    :template => "l1",
                    :phases => [1, 2]
                ),
                Dict(
                    :busses => ("b", "d"),
                    :length => 1,
                    :r1 => 1.0, 
                    :x1 => 1.0,
                    :r0 => 0.0, 
                    :x0 => 0.0,
                    :name => "l2",
                    :phases => [2, 3]
                ),
                Dict(
                    :busses => ("d", "f"),
                    :length => 1,
                    :template => "l2",
                    :phases => [2, 3]
                ),
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
        @test net[("b", "e")].length == 2
        @test resistance(net[("b", "e")]) ≈ [4/3 -2/3 0; -2/3 4/3 0; 0 0 0]
        @test reactance(net[("b", "e")]) ≈ [4/3 -2/3 0; -2/3 4/3 0; 0 0 0]

        # repeat multiphase with phase mismatch on b-c-e branch
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
                    :r0 => 0.0, 
                    :x0 => 0.0,
                    :phases => [1, 2, 3]
                ),
                Dict(
                    :busses => ("b", "c"),
                    :length => 1,
                    :r1 => 1.0, 
                    :x1 => 1.0,
                    :r0 => 0.0, 
                    :x0 => 0.0,
                    :phases => [1, 2]
                ),
                Dict(
                    :busses => ("c", "e"),
                    :length => 1,
                    :r1 => 1.0, 
                    :x1 => 1.0,
                    :r0 => 0.0, 
                    :x0 => 0.0,
                    :phases => [1]
                ),
                Dict(
                    :busses => ("b", "d"),
                    :length => 1,
                    :r1 => 1.0, 
                    :x1 => 1.0,
                    :r0 => 0.0, 
                    :x0 => 0.0,
                    :name => "l2",
                    :phases => [2, 3]
                ),
                Dict(
                    :busses => ("d", "f"),
                    :length => 1,
                    :template => "l2",
                    :phases => [2, 3]
                ),
            ]
        )
        net = Network(net_dict)

        reduce_tree!(net)
        
        @test ("c" in busses(net))
        @test !("d" in busses(net))
        @test (("b", "c") in edges(net))
        @test !(("b", "d") in edges(net))
        @test (("c", "e") in edges(net))
        @test !(("d", "f") in edges(net))
        @test !(("b", "e") in edges(net))
        @test ("b", "f") in edges(net)

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


        #=       3
               c -- e                   
             2/      1\                6.5  
        a -- b         g    ->   a -- b -- g
           2.5\      2/                     
               d -- f            
                 3.5
        Merge parallel lines sets that do not have loads
        =#

        net_dict = Dict(
            :Network => Dict(
                :substation_bus => "a",
            ),
            :Conductor => [
                Dict(
                    :busses => ("a", "b"),
                    :length => 1,
                    :rmatrix => [[1.0, 0.5], [0.5, 1.0]], 
                    :xmatrix => [[1.0, 0.5], [0.5, 1.0]],
                    :phases => [1,2],
                    :name => "l1"
                ),
                Dict(
                    :busses => ("b", "c"),
                    :length => 2,
                    :phases => [1],
                    :rmatrix => [2], 
                    :xmatrix => [2],
                    :name => "two"
                ),
                Dict(
                    :busses => ("b", "d"),
                    :length => 2.5,
                    :phases => [2],
                    :rmatrix => [3], 
                    :xmatrix => [3],
                    :name => "three"
                ),
                Dict(
                    :busses => ("c", "e"),
                    :length => 3,
                    :phases => [1],
                    :template => "two"
                ),
                Dict(
                    :busses => ("d", "f"),
                    :length => 3.5,
                    :phases => [2],
                    :template => "three"
                ),
                Dict(
                    :busses => ("e", "g"),
                    :length => 1,
                    :phases => [1],
                    :template => "two"
                ),
                Dict(
                    :busses => ("f", "g"),
                    :length => 1,
                    :phases => [2],
                    :template => "three"
                ),
            ]
        )
        net = Network(net_dict; directed=true)

        combine_parallel_lines!(net)
        @test busses(net) == ["a", "b", "g"]
        @test net[("b", "g")].length == 6.5  # avg of 6 and 7
        @test rij("b", "g", net)[1,1] == 12  # 2*2 + 2*3 + 2*1
        @test rij("b", "g", net)[2,2] == 21  # 3*2.5 + 3*3.5 + 3*1
        @test xij("b", "g", net)[1,1] == 12
        @test xij("b", "g", net)[2,2] == 21
        # TODO test_throws combine_parallel_lines!
    end
    
end
