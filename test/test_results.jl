@testset "Results" begin

    # TODO test Network.var_name_map and VARIABLE_NAMES
    # TODO test get_variable_values with vectors and matrices
    # TODO test get_variable_values with _squared, after defining containers with CommonOPF.VariableContainer
    m = Model()
    m.obj_dict[:vsqrd] = Dict("bus1" => [1.123456789])

    # overload JuMP.value to hack get_variable_values
    value(arg::Number) = arg

    vals_dict = CommonOPF.get_variable_values(:vsqrd, m; digits=4)
    @test vals_dict == Dict("bus1" => [1.1235])
end