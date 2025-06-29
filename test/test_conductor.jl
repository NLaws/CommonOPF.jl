@testset "Conductor single phase" begin

    # some single phase conductors to test with, constructed two different ways
    c1 = CommonOPF.Conductor(; busses=("b1", "b2"), name="edge1", template="edge2", length=1.2)
    c2 = CommonOPF.Conductor(;
        Dict(:busses => ("b2", "b3"), :name => "edge2", :r1 => 0.1, :x1 => 0.2, :length => 20)...
    )

    @testset "warn_singlephase_conductors_and_copy_templates" begin
        CommonOPF.warn_singlephase_conductors_and_copy_templates([c1, c2])
        @test CommonOPF.resistance_per_length(c1, CommonOPF.SinglePhase) == CommonOPF.resistance_per_length(c2, CommonOPF.SinglePhase) == 0.1
        @test CommonOPF.resistance(c1, CommonOPF.SinglePhase) == 0.1 * 1.2
        @test CommonOPF.resistance(c2, CommonOPF.SinglePhase) == 0.1 * 20
        @test CommonOPF.reactance_per_length(c1, CommonOPF.SinglePhase) == CommonOPF.reactance_per_length(c2, CommonOPF.SinglePhase) == 0.2
        @test CommonOPF.reactance(c1, CommonOPF.SinglePhase) == 0.2 * 1.2
        @test CommonOPF.reactance(c2, CommonOPF.SinglePhase) == 0.2 * 20
    end

    @testset "check_edges! for single phase Conductors" begin
        # check_edges! should do excactly what warn_singlephase_conductors_and_copy_templates did 
        CommonOPF.check_edges!([c1, c2])
        @test CommonOPF.resistance_per_length(c1, CommonOPF.SinglePhase) == CommonOPF.resistance_per_length(c2, CommonOPF.SinglePhase) == 0.1
        @test CommonOPF.resistance(c1, CommonOPF.SinglePhase) == 0.1 * 1.2
        @test CommonOPF.resistance(c2, CommonOPF.SinglePhase) == 0.1 * 20
        @test CommonOPF.reactance_per_length(c1, CommonOPF.SinglePhase) == CommonOPF.reactance_per_length(c2, CommonOPF.SinglePhase) == 0.2
        @test CommonOPF.reactance(c1, CommonOPF.SinglePhase) == 0.2 * 1.2
        @test CommonOPF.reactance(c2, CommonOPF.SinglePhase) == 0.2 * 20
    end

    @testset "admittance methods" begin
        z_magnitude = (
            CommonOPF.resistance(c1, CommonOPF.SinglePhase)^2 
            + CommonOPF.reactance(c1, CommonOPF.SinglePhase)^2
        )
        @test CommonOPF.conductance(c1, CommonOPF.SinglePhase) ≈ 
            CommonOPF.resistance(c1, CommonOPF.SinglePhase) / z_magnitude
        
        @test CommonOPF.susceptance(c1, CommonOPF.SinglePhase) ≈ 
            -CommonOPF.reactance(c1, CommonOPF.SinglePhase) / z_magnitude

        @test CommonOPF.conductance_per_length(c1, CommonOPF.SinglePhase) ≈ 
            CommonOPF.conductance(c1, CommonOPF.SinglePhase) / c1.length

        @test CommonOPF.susceptance_per_length(c1, CommonOPF.SinglePhase) ≈ 
            CommonOPF.susceptance(c1, CommonOPF.SinglePhase) / c1.length

    end

    @testset "ParallelConductor" begin
        pc = CommonOPF.ParallelConductor([c1])
        @test CommonOPF.resistance(c1, CommonOPF.SinglePhase) ≈ CommonOPF.resistance(pc, CommonOPF.SinglePhase)
        @test CommonOPF.reactance(c1, CommonOPF.SinglePhase) ≈ CommonOPF.reactance(pc, CommonOPF.SinglePhase)
        z = CommonOPF._parallel_impedance(pc, CommonOPF.SinglePhase)
        y = CommonOPF._parallel_admittance(pc, CommonOPF.SinglePhase)
        @test z ≈ (1 + 1im) / 2
        @test y ≈ 2 / (1 + 1im)
        @test CommonOPF.resistance_per_length(pc, CommonOPF.SinglePhase) == real(z)
        @test CommonOPF.reactance_per_length(pc, CommonOPF.SinglePhase) == imag(z)
        @test CommonOPF.conductance_per_length(pc, CommonOPF.SinglePhase) == real(y)
        @test CommonOPF.susceptance_per_length(pc, CommonOPF.SinglePhase) == imag(y)
    end
    
end

@testset "ParallelConductor multiphase" begin
    c1 = CommonOPF.Conductor(
        busses=("a","b"),
        phases=[1,2,3],
        rmatrix=Matrix{Float64}(I,3,3),
        xmatrix=Matrix{Float64}(I,3,3),
        length=1.0,
    )
    c2 = deepcopy(c1)
    pc = CommonOPF.ParallelConductor([c1,c2])
    z = CommonOPF._parallel_impedance(pc, CommonOPF.MultiPhase)
    y = CommonOPF._parallel_admittance(pc, CommonOPF.MultiPhase)
    expected_z = ((1 + 1im)/2) * Matrix{ComplexF64}(I,3,3)
    expected_y = (2/(1+1im)) * Matrix{ComplexF64}(I,3,3)
    @test all(z .≈ expected_z)
    @test all(y .≈ expected_y)
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
            "Missing conductor templates: [\"edge2\"]", 
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
        c3 = CommonOPF.Conductor(;
            busses=("b2", "b3"), 
            name="edge2", 
            rmatrix=[[1], [2,3]],
            xmatrix=[[1], [2,3]],
            length=20,
            phases=[2,3],
        )
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

    @testset "admittance methods" begin
        c3 = CommonOPF.Conductor(;
            busses=("b2", "b3"), 
            name="edge2", 
            rmatrix=[[1], [2,3]],
            xmatrix=[[1], [2,3]],
            length=20,
            phases=[2,3],
        )
        CommonOPF.unpack_input_matrices!(c3)
        # build test values
        sub_z_per_length_expected = [1 2; 2 3] .+ im * [1 2; 2 3]
        sub_y_per_length_expected = inv(sub_z_per_length_expected) / c3.length^2
        z_per_length_expected = zeros(ComplexF64, (3,3))
        y_per_length_expected = zeros(ComplexF64, (3,3))
        z_per_length_expected[c3.phases, c3.phases] .= sub_z_per_length_expected
        y_per_length_expected[c3.phases, c3.phases] .= sub_y_per_length_expected

        y = CommonOPF.conductance(c3, CommonOPF.MultiPhase) .+ 
            im * CommonOPF.susceptance(c3, CommonOPF.MultiPhase)

        z = CommonOPF.resistance(c3, CommonOPF.MultiPhase) .+ 
            im * CommonOPF.reactance(c3, CommonOPF.MultiPhase)

        y_per_length = CommonOPF.conductance_per_length(c3, CommonOPF.MultiPhase) .+
            im * CommonOPF.susceptance_per_length(c3, CommonOPF.MultiPhase)

        @test all(
            y .≈ y_per_length_expected * c3.length
        )

        @test all(
            y_per_length .≈ y_per_length_expected
        )

        @test all(
            CommonOPF.inverse_matrix_with_zeros(y) .≈ z
        )

        @test all(
            CommonOPF.inverse_matrix_with_zeros(y_per_length) .≈ z_per_length_expected * c3.length^2
        )
    end

end
