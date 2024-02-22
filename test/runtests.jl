using CommonOPF
using Test
using JuMP
import Logging: with_logger
# @with_kw is used to define concrete types of AbstractBus and AbstractEdge in CommonOPF
import Parameters: @with_kw
import InteractiveUtils: subtypes

test_logger = TestLogger()

# # hack for local testing
# using Pkg
# Pkg.activate("..")
# using CommonOPF
# Pkg.activate(".")

function clear_log!(logger)
    deleteat!(logger.logs, 1:length(logger.logs))
end

@warn "Logging messages from CommonOPF are silenced."

# wrapping all tests with the test_logger means that we cannot use @test_warn,
# (but can still use @test_throws). all @warn messages go into test_logger.logs,
# which is a vector of [LogRecord](https://docs.julialang.org/en/v1/stdlib/Test/#Test.LogRecord)
# so we use `occursin` to test for strings in the LogRecord.message

with_logger(test_logger) do

@testset "CommonOPF.jl" begin

    include("test_busses.jl")

    include("test_conductor.jl")

    include("test_decomposition.jl")

    include("test_edges.jl")

    include("test_network_reduction.jl")

    include("test_network.jl")

    include("test_opendss.jl")

    include("test_results.jl")

end # outer-most testset
end # with_logger



# Maybe do this later
# @testset "extract_one_phase!" begin
#     dssfilepath = joinpath("data", "ieee13", "IEEE13Nodeckt.dss")
#     d = dss_files_to_dict(dssfilepath)

#     edges, linecodes, linelengths, linecodes_dict, phases, Isquared_up_bounds, regulators = 
#         dss_dict_to_arrays(d, CommonOPF.SBASE_DEFAULT, CommonOPF.VBASE_DEFAULT, "rg60");
#     @test length(edges) == 13

#     #=
#     lines with less than three phases:
#     Bus1=632.2.3      Bus2=645.2.3
#     Bus1=645.2.3      Bus2=646.2.3
#     Bus1=671.1.3      Bus2=684.1.3 
#     Bus1=684.3        Bus2=611.3
#     Bus1=684.1        Bus2=652.1
#     =#
#     phases, regs = CommonOPF.extract_one_phase!(1, edges, linecodes, linelengths, phases, linecodes_dict, regulators)
#     @test length(edges) == 13 - 3
#     @test !( ("632", "645") in edges )
#     @test !( ("684", "611") in edges )
#     @test !( ("632", "645") in edges )
#     @test length(phases) == 13 - 3
#     for phs in phases
#         @test phs == [1]
#     end

#     edges, linecodes, linelengths, linecodes_dict, phases, Isquared_up_bounds, regulators = 
#         dss_dict_to_arrays(d, CommonOPF.SBASE_DEFAULT, CommonOPF.VBASE_DEFAULT, "rg60");
#     @test length(edges) == 13
#     phases, regs = CommonOPF.extract_one_phase!(2, edges, linecodes, linelengths, phases, linecodes_dict, regulators)
#     @test length(edges) == 13 - 3
#     @test !( ("671", "684") in edges )
#     @test !( ("684", "611") in edges )
#     @test !( ("684", "652") in edges )

#     edges, linecodes, linelengths, linecodes_dict, phases, Isquared_up_bounds, regulators = 
#         dss_dict_to_arrays(d, CommonOPF.SBASE_DEFAULT, CommonOPF.VBASE_DEFAULT, "rg60");
#     @test length(edges) == 13
#     phases, regs = CommonOPF.extract_one_phase!(3, edges, linecodes, linelengths, phases, linecodes_dict, regulators)
#     @test length(edges) == 13 - 1
#     @test !( ("684", "652") in edges )
# end

