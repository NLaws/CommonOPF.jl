using CommonOPF
using Test


@testset "CommonOPF.jl" begin
    dssfilepath = joinpath("data", "ieee13", "IEEE13Nodeckt.dss")
    d = dss_files_to_dict(dssfilepath)
    edges, linecodes, linelengths, linecodes_dict, phases, Isquared_up_bounds, regulators = 
        dss_dict_to_arrays(d, CommonOPF.SBASE_DEFAULT, CommonOPF.VBASE_DEFAULT)
end
