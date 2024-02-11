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
        r1=0.1, 
        r0=0,
        x1=0.2,
        x0=0,
        length=20,
        phases=[1],
    )

    @testset "validate_multiphase_conductors!" begin
        c2.x0 = missing
        clear_log!(test_logger)
        @test CommonOPF.validate_multiphase_conductors!([c2]) == false
        @test occursin(
            "do not have sufficient parameters to define the impedance", 
            test_logger.logs[end].message
        )
        c2.x0 = 0

        c2.phases = missing
        clear_log!(test_logger)
        @test CommonOPF.validate_multiphase_conductors!([c2]) == false
        @test occursin(
            "1 conductors are missing phases.", 
            test_logger.logs[end].message
        )
        c2.phases = [1]

        clear_log!(test_logger)
        CommonOPF.validate_multiphase_conductors!([c1])
        @test occursin(
            "Missing templates: [\"edge2\"]", 
            test_logger.logs[end].message
        )

        # the template has different phases then the conductor
        clear_log!(test_logger) 
        @test CommonOPF.validate_multiphase_conductors!([c1, c2]) == false
        @test occursin(
            "Not copying template impedance matrices",
            test_logger.logs[end].message
        )

        c2.phases = c1.phases
        clear_log!(test_logger)
        @test CommonOPF.validate_multiphase_conductors!([c1, c2])
        @test isempty(test_logger.logs)
    end
end
