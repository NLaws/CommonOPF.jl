@testset "Conductor single phase" begin

    # some single phase conductors to test with, constructed two different ways
    c1 = CommonOPF.Conductor(; busses=("b1", "b2"), name="edge1", template="edge2", length=1.2)
    c2 = CommonOPF.Conductor(;
        Dict(:busses => ("b2", "b3"), :name => "edge2", :r1 => 0.1, :x1 => 0.2, :length => 20)...
    )

    @testset "warn_singlephase_conductors_and_copy_templates" begin
        CommonOPF.warn_singlephase_conductors_and_copy_templates([c1, c2])
        @test resistance_per_length(c1) == resistance_per_length(c2) == 0.1
        @test resistance(c1) == 0.1 * 1.2
        @test resistance(c2) == 0.1 * 20
        @test reactance_per_length(c1) == reactance_per_length(c2) == 0.2
        @test reactance(c1) == 0.2 * 1.2
        @test reactance(c2) == 0.2 * 20
    end

    @testset "check_edges! for single phase Conductors" begin
        # check_edges! should do excactly what warn_singlephase_conductors_and_copy_templates did 
        CommonOPF.check_edges!([c1, c2])
        @test resistance_per_length(c1) == resistance_per_length(c2) == 0.1
        @test resistance(c1) == 0.1 * 1.2
        @test resistance(c2) == 0.1 * 20
        @test reactance_per_length(c1) == reactance_per_length(c2) == 0.2
        @test reactance(c1) == 0.2 * 1.2
        @test reactance(c2) == 0.2 * 20
    end
end


@testset "Conductor multi-phase" begin

    # some multi-phase conductors to test with
    c1 = CommonOPF.Conductor(; 
        busses=("b1", "b2"), 
        name="edge1", 
        template="edge2", 
        length=1.2, 
        phases=[2,3],
    )
    c2 = CommonOPF.Conductor(;
        busses=("b2", "b3"), 
        name="edge2", 
        r1=1, 
        r0=2,
        x1=3,
        x0=4,
        length=20,
        phases=[1],
    )
    c3 = CommonOPF.Conductor(;
        busses=("b2", "b3"), 
        name="edge2", 
        rmatrix=[[1], [2,3]],
        xmatrix=[[1], [2,3]],
        length=20,
        phases=[2,3],
    )

    @testset "validate_multiphase_edges!" begin
        c2.x0 = missing
        clear_log!(test_logger)
        @test CommonOPF.validate_multiphase_edges!([c2]) == false
        @test occursin(
            "do not have sufficient parameters to define the impedance", 
            test_logger.logs[end].message
        )
        c2.x0 = 0

        c2.phases = missing
        clear_log!(test_logger)
        @test CommonOPF.validate_multiphase_edges!([c2]) == false
        @test occursin(
            "1 conductors are missing phases.", 
            test_logger.logs[end].message
        )
        c2.phases = [1]

        clear_log!(test_logger)
        CommonOPF.validate_multiphase_edges!([c1])
        @test occursin(
            "Missing templates: [\"edge2\"]", 
            test_logger.logs[end].message
        )

        # the template has different phases then the conductor
        clear_log!(test_logger) 
        @test CommonOPF.validate_multiphase_edges!([c1, c2]) == false
        @test occursin(
            "Not copying template impedance matrices",
            test_logger.logs[end].message
        )

        c2.phases = c1.phases
        clear_log!(test_logger)
        @test CommonOPF.validate_multiphase_edges!([c1, c2])
        @test isempty(test_logger.logs)
        @test c2.rmatrix == c1.rmatrix
        @test c2.xmatrix == c1.xmatrix
    end

    @testset "fill_impedance_matrices!" begin
        c2.rmatrix = missing
        c2.xmatrix = missing
        CommonOPF.fill_impedance_matrices!(c2)
        # first row is all zeros b/c c2.phases == [2,3]
        @test all(c2.rmatrix[1, i] == 0 for i=1:3)
        @test all(c2.xmatrix[1, i] == 0 for i=1:3)
        # first column is all zeros b/c c2.phases == [2,3]
        @test all(c2.rmatrix[i, 1] == 0 for i=1:3)
        @test all(c2.xmatrix[i, 1] == 0 for i=1:3)
        @test c2.rmatrix[2,2] == c2.rmatrix[3,3] ≈ 1/3 * c2.r0 + 2/3 * c2.r1
        @test c2.rmatrix[2,3] == c2.rmatrix[3,2] ≈ 1/3 * (c2.r0 - c2.r1)
    end

    @testset "unpack_input_matrices!" begin
        CommonOPF.unpack_input_matrices!(c3)
        # first row is all zeros b/c c3.phases == [2,3]
        @test all(c3.rmatrix[1, i] == 0 for i=1:3)
        @test all(c3.xmatrix[1, i] == 0 for i=1:3)
        # first column is all zeros b/c c3.phases == [2,3]
        @test all(c3.rmatrix[i, 1] == 0 for i=1:3)
        @test all(c3.xmatrix[i, 1] == 0 for i=1:3)

        @test c3.rmatrix[2,2] == 1
        @test c3.rmatrix[2,3] == 2 == c3.rmatrix[3,2]
        @test c3.rmatrix[3,3] == 3

        @test c3.xmatrix[2,2] == 1
        @test c3.xmatrix[2,3] == 2 == c3.rmatrix[3,2]
        @test c3.xmatrix[3,3] == 3
    
        # test phases mismatch with passed in lower triangle values
        clear_log!(test_logger)
        c3.phases = [1,2,3]
        c3.rmatrix = [[1], [2,3]]
        c3.xmatrix=[[1], [2,3]]
        CommonOPF.unpack_input_matrices!(c3)
        @test occursin(
            "Unable to process impedance matrices", 
            test_logger.logs[end].message
        )
    end

end
