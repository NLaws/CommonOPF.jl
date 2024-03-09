@testset "openDSS parsing" begin
    @testset "dss_to_Network" begin
        dssfilepath = joinpath("data", "ieee13", "IEEE13Nodeckt.dss")
        net = CommonOPF.dss_to_Network(dssfilepath)
        # TODO compare to data/yaml_inputs/ieee13_multi_phase.yaml (which was manually constructed)
    end
end
