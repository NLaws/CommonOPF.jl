using CommonOPF
using Test
using JuMP
using LinearAlgebra
import Logging: with_logger
# @with_kw is used to define concrete types of AbstractBus and AbstractEdge in CommonOPF
import Parameters: @with_kw
import InteractiveUtils: subtypes

const OpenDSS = CommonOPF.OpenDSS

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

    include("test_admittances.jl")

    include("test_busses.jl")

    include("test_conductor.jl")

    include("test_decomposition.jl")

    include("test_edges.jl")

    include("test_graphs.jl")

    include("test_opendss.jl")

    include("test_psse.jl")

    include("test_loads.jl")

    include("test_model_construction_utils.jl")

    include("test_network_reduction.jl")

    include("test_network.jl")

    include("test_results.jl")

    include("test_shunts.jl")

    include("test_variables.jl")

end # outer-most testset
end # with_logger
