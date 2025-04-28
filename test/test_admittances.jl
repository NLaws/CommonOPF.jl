# using CommonOPF, Test, LinearAlgebra
# import OpenDSSDirect as OpenDSS
# cd("test/")


@testset "test admittance getters" begin
    # net = Network_IEEE8500();

    # # non-existent edge gives zero admittance
    # @test Yij("_hvmv_sub_lsb", "m1108508", net) == zeros(3,3) * im

    dssfilepath = joinpath("data", "ieee13", "IEEE13Nodeckt.dss")
    net = CommonOPF.dss_to_Network(dssfilepath)

    # Ycpf, y_order_cpf = Ysparse(net)
    # TODO bottleneck in Ysparse? Takes ~7 minutes for 8500 node system
    Ycpf, y_order_cpf = Ysparse(net);
    # @time gives: 434.330585 seconds (21.25 M allocations: 560.288 MiB, 0.01% gc time)

    Ydss = OpenDSS.YMatrix.getYsparse();
    y_order_dss = [lowercase(nd) for nd in OpenDSS.Circuit.YNodeOrder()];

    for (dss_i, dss_row_nd) in enumerate(y_order_dss)
        cpf_i = findfirst(isequal(dss_row_nd), y_order_cpf)
        for (dss_j, dss_col_nd) in enumerate(y_order_dss)
            cpf_j = findfirst(isequal(dss_col_nd), y_order_cpf)
            @test y_order_cpf[cpf_i] == dss_row_nd
            @test y_order_cpf[cpf_j] == dss_col_nd
            # CPF does not include shunt admittance from OpenDSS
            # CPF does not include source impedance
            if cpf_i == cpf_j || (occursin("source", dss_row_nd) && occursin("source", dss_col_nd))
                continue
            end
            # we ignore off diagonal transformer impedance b/c it causes numerical issues
            if isa(
                net[(CommonOPF.strip_phases(dss_row_nd), CommonOPF.strip_phases(dss_col_nd))], 
                CommonOPF.Transformer
                ) &&
                cpf_i != cpf_j
                continue
            end
            # OpenDSS includes impedance between phases on the same bus. These impedances are not
            # modeled in OPF so we ignore them.
            if CommonOPF.strip_phases(dss_row_nd) == CommonOPF.strip_phases(dss_col_nd)
                continue
            end
            
            try
                @test Ycpf[cpf_i, cpf_j] ≈ Ydss[dss_i, dss_j]
            catch
                println("test failed")
                println(dss_row_nd, " ", dss_col_nd, " -- ", "CPF: ($cpf_i, $cpf_j) ", "DSS: ($dss_i, $dss_j) ")
            end
        end
    end

end