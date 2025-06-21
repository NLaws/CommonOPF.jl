@testset "terminal maps" begin
    net = Network_IEEE13()
    bus_terms, edge_terms = terminal_maps(net)

    @test sort(collect(keys(bus_terms))) == sort(busses(net))

    # check bus terminal phases and ordering
    for b in busses(net)
        phases = phases_connected_to_bus(net, b)
        terms = bus_terms[b]
        @test length(terms) == length(phases)
        @test all(t.bus == b for t in terms)
        @test collect(t.phase for t in terms) == phases
    end

    all_terms = reduce(vcat, values(bus_terms))
    @test sort(t.Y_index for t in all_terms) == collect(1:length(all_terms))
    @test length(unique(t.Y_index for t in all_terms)) == length(all_terms)

    for (b1, b2) in edges(net)
        phases = net[(b1, b2)].phases
        et = edge_terms[(b1, b2)]
        @test et.busses == (b1, b2)
        @test et.bus1_terminals == [t for t in bus_terms[b1] if t.phase in phases]
        @test et.bus2_terminals == [t for t in bus_terms[b2] if t.phase in phases]
    end
end

@testset "terminals vector" begin
    net = Network_IEEE13()
    terms_vec = terminals(net)
    expected_total = sum(length(phases_connected_to_bus(net, b)) for b in busses(net))
    @test length(terms_vec) == expected_total

    for (i, t) in enumerate(terms_vec)
        @test t.Y_index == i
    end

    bus_terms, _ = terminal_maps(net)
    flat_terms = reduce(vcat, values(bus_terms))
    for t in flat_terms
        @test terms_vec[t.Y_index] == t
    end
end