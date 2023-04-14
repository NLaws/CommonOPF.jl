using CommonOPF
using Test
import Logging: SimpleLogger, Error, with_logger

# # hack for local testing
# using Pkg
# Pkg.activate("..")
# using CommonOPF
# Pkg.activate(".")


@testset "CommonOPF.jl" begin

@testset "extract_one_phase!" begin
    dssfilepath = joinpath("data", "ieee13", "IEEE13Nodeckt.dss")
    d = dss_files_to_dict(dssfilepath)

    with_logger(SimpleLogger(Error)) do  # silence warnings
    edges, linecodes, linelengths, linecodes_dict, phases, Isquared_up_bounds, regulators = 
        dss_dict_to_arrays(d, CommonOPF.SBASE_DEFAULT, CommonOPF.VBASE_DEFAULT);
    @test length(edges) == 13

    #=
    lines with less than three phases:
    Bus1=632.2.3      Bus2=645.2.3
    Bus1=645.2.3      Bus2=646.2.3
    Bus1=671.1.3      Bus2=684.1.3 
    Bus1=684.3        Bus2=611.3
    Bus1=684.1        Bus2=652.1
    =#
    CommonOPF.extract_one_phase!(1, edges, linecodes, linelengths, phases, linecodes_dict)
    @test length(edges) == 13 - 3
    @test !( ("632", "645") in edges )
    @test !( ("684", "611") in edges )
    @test !( ("632", "645") in edges )

    edges, linecodes, linelengths, linecodes_dict, phases, Isquared_up_bounds, regulators = 
        dss_dict_to_arrays(d, CommonOPF.SBASE_DEFAULT, CommonOPF.VBASE_DEFAULT);
    @test length(edges) == 13
    CommonOPF.extract_one_phase!(2, edges, linecodes, linelengths, phases, linecodes_dict)
    @test length(edges) == 13 - 3
    @test !( ("671", "684") in edges )
    @test !( ("684", "611") in edges )
    @test !( ("684", "652") in edges )

    edges, linecodes, linelengths, linecodes_dict, phases, Isquared_up_bounds, regulators = 
        dss_dict_to_arrays(d, CommonOPF.SBASE_DEFAULT, CommonOPF.VBASE_DEFAULT);
    @test length(edges) == 13
    CommonOPF.extract_one_phase!(3, edges, linecodes, linelengths, phases, linecodes_dict)
    @test length(edges) == 13 - 1
    @test !( ("684", "652") in edges )
    end
end

end
