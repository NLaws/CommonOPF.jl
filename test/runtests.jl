using CommonOPF
using Test
import Logging: with_logger

test_logger = TestLogger()

# # hack for local testing
# using Pkg
# Pkg.activate("..")
# using CommonOPF
# Pkg.activate(".")


with_logger(test_logger) do
@testset "CommonOPF.jl" begin

include("test_network.jl")

@testset "merge parallel single phase lines" begin
    #= 
           c -- e                   
          /       \                    
    a -- b         g      ->   a -- b -- cd -- ef -- g
          \       /                     
           d -- f            
           
    Merge parallel lines sets that do not have loads
    =#
    
    edges = [("a", "b"), ("b", "c"), ("b", "d"), ("c", "e"), ("d", "f"), ("e", "g"), ("f", "g")]
    linecodes = repeat(["l1"], length(edges))
    linelengths = repeat([1.0], length(edges))
    phases = [[1,2], [1], [2], [1], [2], [1], [2]]
    substation_bus = "a"
    Pload = Dict()
    Qload = Dict()
    Zdict = Dict("l1" => Dict("rmatrix"=> [1.0], "xmatrix"=> [1.0], "nphases"=> 1))
    v0 = 1.0

    busses = String[]
    for t in edges
        push!(busses, t[1])
        push!(busses, t[2])
    end
    busses = unique(busses)
    g = make_graph(busses, edges)
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

    p = Inputs(
        edges, 
        linecodes, 
        linelengths, 
        phases,
        substation_bus;
        Pload=Pload, 
        Qload=Qload, 
        Sbase=1, 
        Vbase=1, 
        Zdict=Zdict, 
        v0=v0, 
        Isquared_up_bounds=Dict{String, Float64}()
    )
    p.Pload = Dict("c" =>[1.0])
    try
        check_paths(paths, p)
    catch e
        @test "not merging" in e
    end
    p.Pload = Dict()
    @test check_paths(paths, p)
end


@testset "extract_one_phase!" begin
    dssfilepath = joinpath("data", "ieee13", "IEEE13Nodeckt.dss")
    d = dss_files_to_dict(dssfilepath)

    edges, linecodes, linelengths, linecodes_dict, phases, Isquared_up_bounds, regulators = 
        dss_dict_to_arrays(d, CommonOPF.SBASE_DEFAULT, CommonOPF.VBASE_DEFAULT, "rg60");
    @test length(edges) == 13

    #=
    lines with less than three phases:
    Bus1=632.2.3      Bus2=645.2.3
    Bus1=645.2.3      Bus2=646.2.3
    Bus1=671.1.3      Bus2=684.1.3 
    Bus1=684.3        Bus2=611.3
    Bus1=684.1        Bus2=652.1
    =#
    phases, regs = CommonOPF.extract_one_phase!(1, edges, linecodes, linelengths, phases, linecodes_dict, regulators)
    @test length(edges) == 13 - 3
    @test !( ("632", "645") in edges )
    @test !( ("684", "611") in edges )
    @test !( ("632", "645") in edges )
    @test length(phases) == 13 - 3
    for phs in phases
        @test phs == [1]
    end

    edges, linecodes, linelengths, linecodes_dict, phases, Isquared_up_bounds, regulators = 
        dss_dict_to_arrays(d, CommonOPF.SBASE_DEFAULT, CommonOPF.VBASE_DEFAULT, "rg60");
    @test length(edges) == 13
    phases, regs = CommonOPF.extract_one_phase!(2, edges, linecodes, linelengths, phases, linecodes_dict, regulators)
    @test length(edges) == 13 - 3
    @test !( ("671", "684") in edges )
    @test !( ("684", "611") in edges )
    @test !( ("684", "652") in edges )

    edges, linecodes, linelengths, linecodes_dict, phases, Isquared_up_bounds, regulators = 
        dss_dict_to_arrays(d, CommonOPF.SBASE_DEFAULT, CommonOPF.VBASE_DEFAULT, "rg60");
    @test length(edges) == 13
    phases, regs = CommonOPF.extract_one_phase!(3, edges, linecodes, linelengths, phases, linecodes_dict, regulators)
    @test length(edges) == 13 - 1
    @test !( ("684", "652") in edges )
end


@testset "Inputs" begin
    dssfilepath = joinpath("data", "ieee13", "IEEE13Nodeckt.dss")

    p = Inputs(dssfilepath, "rg60");
    p2 = Inputs(dssfilepath, "rg60", extract_phase=2);

    for phs in p2.phases
        @test phs == [2]
    end


end


@testset "trim_above_substation_bus" begin
    sub = "670"
    dssfilepath = joinpath("data", "ieee13", "IEEE13Nodeckt.dss")
    d = dss_files_to_dict(dssfilepath)
    edges, linecodes, linelengths, linecodes_dict, phases, Isquared_up_bounds, regulators = 
        dss_dict_to_arrays(d, CommonOPF.SBASE_DEFAULT, CommonOPF.VBASE_DEFAULT, sub);
    g = make_graph(edges)
    busses_to_delete = all_inneighbors(g, sub, Vector{String}())
    @test "632" in busses_to_delete
    @test "645" in busses_to_delete
    @test "646" in busses_to_delete
    @test "633" in busses_to_delete
    @test "634" in busses_to_delete
    @test "rg60" in busses_to_delete
    @test length(busses_to_delete) == 6
    edges_to_delete = [e for e in edges if e[1] in busses_to_delete]
    @test ("632", "670") in edges_to_delete
    @test ("632", "645") in edges_to_delete
    @test ("645", "646") in edges_to_delete
    @test ("rg60", "632") in edges_to_delete
    @test ("632", "633") in edges_to_delete
    @test ("633", "634") in edges_to_delete
    @test length(edges_to_delete) == 6
    # TODO put in method for use and testing
end


@testset "reduce_tree! SinglePhase" begin
    #=           c -- e                     -- e
                / [1,2]                   /
    a -[1,2,3]- b           ->       a -- b
                \ [2,3]                   \
                 d -- f                     -- f
    nodes c and d should be removed b/c there is no load at them and the phases are the same
    on both sides
    =#
    edges = [("a", "b"), ("b", "c"), ("b", "d"), ("c", "e"), ("d", "f")]
    linecodes = repeat(["l1"], length(edges))
    linelengths = repeat([1.0], length(edges))
    phases = repeat([[1]], length(edges))
    substation_bus = "a"
    Pload = Dict("e" => [1.0], "f" => [1.0])
    Qload = Dict("e" => [0.1], "f" => [0.1])
    Zdict = Dict("l1" => Dict("rmatrix"=> [1.0], "xmatrix"=> [1.0], "nphases"=> 1))
    v0 = 1.0

    p = Inputs(
        edges, 
        linecodes, 
        linelengths, 
        phases,
        substation_bus;
        Pload=Pload, 
        Qload=Qload, 
        Sbase=1, 
        Vbase=1, 
        Zdict=Zdict, 
        v0=v0, 
        v_lolim=0.95, 
        v_uplim=1.05,
        Ntimesteps=1, 
        P_up_bound=1e4,
        Q_up_bound=1e4,
        P_lo_bound=-1e4,
        Q_lo_bound=-1e4,
        Isquared_up_bounds=Dict{String, Float64}(),
        relaxed=true
    )

    reduce_tree!(p)

    @test !("c" in p.busses)
    @test !("d" in p.busses)
    @test !(("b", "c") in p.edges)
    @test !(("b", "d") in p.edges)
    @test !(("c", "e") in p.edges)
    @test !(("d", "f") in p.edges)
    @test ("b", "e") in p.edges
    @test ("b", "f") in p.edges

end

end
end # with_logger