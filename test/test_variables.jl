@testset "variable builders" begin
    clear_log!(test_logger)
    # single phase
    m = JuMP.Model()
    net = Network_IEEE13_SinglePhase()
    net.Ntimesteps = 3

    add_time_vector_variables!(m, net, :var, ["a", "b"])
    @test length(m[:var]["a"]) == 3  # 3 time steps
    @test length(m[:var]["b"]) == 3  # 3 time steps
    @test :var in net.var_names

    # multiphase
    net = Network(joinpath(@__DIR__, "data", "ieee13", "IEEE13Nodeckt.dss"))
    net.Ntimesteps = 2

    e = edges(net)[1]
    m[:edge_var] = multiphase_edge_variable_container(;default = JuMP.VariableRef)
    add_complex_vector_of_phase_variable!(m, net, e, :edge_var, 1)
    @test length(m[:edge_var][e][1]) == 3  # 3 phases
    @test length(m[:edge_var][e][1]) == 3  # 3 phases
    @test !(:edge_var in net.var_names)
    
    m[:bus_var] = multiphase_bus_variable_container()

    # time index order does not matters
    add_complex_vector_of_phase_variable!(m, net, "632", :bus_var, 2)
    add_complex_vector_of_phase_variable!(m, net, "632", :bus_var, 1)

    # adding more time steps than net.Ntimesteps warns
    add_complex_vector_of_phase_variable!(m, net, "632", :bus_var, 3)
    @test occursin("more than net.Ntimesteps", test_logger.logs[end].message)
    let err = nothing
        try
            add_complex_vector_of_phase_variable!(m, net, "b1", :bus_var, 1)
        catch err
        end
    
        @test err isa KeyError
        @test occursin("""key "b1" not found""", sprint(showerror, err))
    end
    
end