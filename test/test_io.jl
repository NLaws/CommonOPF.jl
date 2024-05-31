@testset "openDSS parsing" begin
    
    @testset "dss_to_Network" begin
        dssfilepath = joinpath("data", "ieee13", "IEEE13Nodeckt.dss")
        net = CommonOPF.dss_to_Network(dssfilepath)

        @test net["671"][:Load].kws2 == [1155.0 / 3]
        @test net["670"][:Load].kws1 == [17.0]
        @test net["670"][:Load].kvars3 == [68.0]

        # need to merge the phases together for regulator edges
        # and the transformers get overwritten (b/c they're parsed first, which is actually what we
        # want, maybe should silence the warnings about "Replacing existing data in edge"
        @test isa(net[("650", "rg60")], CommonOPF.VoltageRegulator)
        @test net[("650", "rg60")].vreg_pu ≈ 1.01667

        # TODO compare to data/yaml_inputs/ieee13_multi_phase.yaml (which was manually constructed)
        # can use dict equality for all conductors?
    end

    @testset "opendss admittance matrix" begin
        # openDSS models loads via their Thevinin equivalent and therefore includes the load
        # admittances in the "system" (i.e. bus) Y matrix. We do not want the load admittances when
        # extracting the bus admittance matrix from openDSS. So we use the simple circuit defined
        # here to test CommonOPF's capability of setting all loads to zero and getting the
        # admittance matrix that we want.
        CommonOPF.OpenDSS.dss("""
        clear
        
        new circuit.dummy basekv=12.47 phases=3 pu=1.0 bus1=bus1
        
        new line.line_b1_to_b2 phases=3 bus1=bus1 bus2=bus2 length=1
        ~ rmatrix = (1 | 2 3 | 4 5 6)
        ~ xmatrix = (1 | 2 3 | 4 5 6)
        ~ cmatrix = (0 | 0 0 | 0 0 0)
        
        New load.load1 phases=3 bus=bus2 kw=100 kvar=10
        
        calcv
        solve
        """)
        y_with_load = CommonOPF.OpenDSS.Circuit.SystemY()

        CommonOPF.OpenDSS.Loads.First()
        CommonOPF.OpenDSS.CktElement.Enabled(false)  # removes the only load
        CommonOPF.OpenDSS.dss("Solve")

        y_without_load = CommonOPF.OpenDSS.Circuit.SystemY()
        
        expected_impedance = [
            1.0+1*im  2+2*im  4+4*im; 
            2+2*im  3+3*im  5+5*im; 
            4+4*im  5+5*im  6+6*im
        ]

        zline1 = inv(y_with_load[4:6,4:6])
        @test !all(abs.(zline1) ≈ abs.(expected_impedance))

        zline2 = inv(y_without_load[4:6,4:6])
        @test all(abs.(zline2) ≈ abs.(expected_impedance))
        
        # OpenDSS provides 2x2 and 1x1 admittance matrices in 3 phase networks.
        # CommonOPF provides 3x3 matrices (with zeros as appropriate) s.t. the impedance matrices
        # are consistently sized and have phase admittance/impedance i,j values in row,column i,j
        # We test these expectations here using the IEEE13 system.
        CommonOPF.OpenDSS.dss("""
        clear
        redirect $(joinpath("data", "ieee13", "IEEE13Nodeckt.dss"))
        """)
        CommonOPF.OpenDSS.Lines.Idx(6)
        @test CommonOPF.OpenDSS.CktElement.BusNames() == ["632.2.3", "645.2.3"]
        dss_rmatrix = CommonOPF.OpenDSS.Lines.RMatrix()
        dss_xmatrix = CommonOPF.OpenDSS.Lines.XMatrix()
        phases = CommonOPF.OpenDSS.CktElement.NodeOrder()[1:CommonOPF.OpenDSS.CktElement.NumPhases()]
        r, x = CommonOPF.dss_impedance_matrices_to_three_phase(dss_rmatrix, dss_xmatrix, phases)
        @test r[2,2] == dss_rmatrix[1,1]
        @test x[3,2] == dss_xmatrix[2,1]

        # Single phase circuit impedances from CommonOPF should be scalar values, even though
        # OpenDSS always provides matrices for admittance values, which we tests here with a single
        # phase version of the IEEE13 system.
        dssfilepath = joinpath("data", "ieee13", "ieee13_makePosSeq", "Master.dss")
        net = CommonOPF.dss_to_Network(dssfilepath)
        for (i,j) in edges(net)
            println(net[(i,j)])
            @test typeof(rij(i, j, net)) <: Number
        end
        
    end
end
