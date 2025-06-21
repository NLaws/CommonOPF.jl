"""
    struct BusTerminal
        bus::String
        phase::Int
        Y_index::Int
    end

For handling bus admittance indices.
"""
struct BusTerminal
    bus::String
    phase::Int
    Y_index::Int
end


struct EdgeTerminals
    busses::Tuple{String, String}
    bus1_terminals::Vector{BusTerminal}
    bus2_terminals::Vector{BusTerminal}
end


"""
    terminals(net::Network{MultiPhase})

Collect the maps of bus -> Vector{BusTerminal} and edge -> EdgeTerminals for building the bus
admittance matrix.

The `values(bus_terminals)` are in phase order.

!!! danger
    The `Y_index` of any terminal can change if the `Network` is modified.
"""
function terminal_maps(net::Network{MultiPhase})
    bus_terminals = Dict{String, Vector{BusTerminal}}()
    edge_terminals = Dict{Tuple{String, String}, EdgeTerminals}()

    n = 0
    for b in busses(net)
        terms = BusTerminal[]
        for phs in phases_connected_to_bus(net, b)
            n += 1
            push!(terms, BusTerminal(b, phs, n))
        end
        bus_terminals[b] = terms
    end

    for (b1, b2) in edges(net)
        phases = net[(b1, b2)].phases
        terminals_1 = [
            term for term in bus_terminals[b1] if term.phase in phases
        ]
        terminals_2 = [
            term for term in bus_terminals[b2] if term.phase in phases
        ]
        edge_terminals[(b1, b2)] = EdgeTerminals((b1, b2), terminals_1, terminals_2)
    end

    return bus_terminals, edge_terminals
end


"""
    terminals(net::Network{MultiPhase})::Vector{BusTerminal}

For all the busses, for all the ordered phases at each bus, create a BusTerminal and return them in
a vector.
"""
function terminals(net::Network{MultiPhase})::Vector{BusTerminal}
    bs = busses(net)
    # preallocate assuming 3 phases at every bus
    trmnls = Vector{BusTerminal}(undef, length(bs) * 3)
    n = 0
    for b in bs
        for phs in phases_connected_to_bus(net, b)  # sorted
            n += 1
            trmnls[n] = BusTerminal(b, phs, n)
        end
    end
    return resize!(trmnls, n)
end


"""
    terminals_sj_per_unit(
        net::Network{MultiPhase}, trmnls::Vector{CommonOPF.BusTerminal}
    )::Vector{Vector{ComplexF64}}

Create the complex power injection vector for the `trmnls`.
"""
function terminals_sj_per_unit(
    net::Network{MultiPhase}, trmnls::Vector{CommonOPF.BusTerminal}
    )::Vector{Vector{ComplexF64}}

    terminals_sj = [Vector{ComplexF64}(undef, length(net.Ntimesteps)) for _ in trmnls]

    n = 0
    for j in busses(net)
        sj = sj_per_unit(j, net)
        for phs in phases_connected_to_bus(net, j)  # sorted
            n += 1
            terminals_sj[n] = sj[phs]
        end
    end
    return terminals_sj
end
