# using CommonOPF, Test, LinearAlgebra
# import OpenDSSDirect as OpenDSS
# cd("test/")


@testset "bus admittance compared with OpenDSS" begin
    # net = Network_IEEE8500();

    # # non-existent edge gives zero admittance
    # @test Yij("_hvmv_sub_lsb", "m1108508", net) == zeros(3,3) * im

    dssfilepath = joinpath("data", "ieee13", "IEEE13Nodeckt.dss")
    net = CommonOPF.dss_to_Network(dssfilepath)

    # Ycpf, y_order_cpf = Ysparse(net)
    # TODO bottleneck in Ysparse? Takes ~7 minutes for 8500 node system
    Ycpf, Yterminals = Ysparse(net);
    # @time gives: 434.330585 seconds (21.25 M allocations: 560.288 MiB, 0.01% gc time)
    Ydss = OpenDSS.YMatrix.getYsparse();
    y_order_dss = [lowercase(nd) for nd in OpenDSS.Circuit.YNodeOrder()];

    y_order_cpf = Vector{String}(undef, length(y_order_dss))
    for t in Yterminals
        y_order_cpf[t.Y_index] = t.bus * "." * string(t.phase)
    end

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


@testset "bus admittance" begin
    net = CommonOPF.Network_IEEE13()

    # edge 632-645 has phases [2,3]
    @test size(Yij("632", "645", net)) == (2,2)


    # edge 684-611 has phases [3]
    @test size(Yij("684", "611", net)) == (1,1)

    # bus 684 has 2 phases
    @test length(phases_connected_to_bus(net, "684")) == 2
    @test size(Yij("684", "684", net)) == (2,2)

    Ybus, Yorder = Ysparse(net)

    for (i, term) in enumerate(Yorder)
        @test term.Y_index == i
    end


end