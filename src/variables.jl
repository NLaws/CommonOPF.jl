# SinglePhase variable containers and builders
"""
    add_time_vector_variables!(
        m::JuMP.AbstractModel, 
        net::Network{SinglePhase}, 
        var_symbol::Symbol, 
        indices::AbstractVector{T} 
    ) where {T}

Add variables to the `m.obj_dict` indexed on:
1. `var_symbol` like `:v`
2. `indices`, typically a `Vector{String}` for bus indices or a `Vector{Tuple{String, String}}` for
   edge indices (like `("bus1", "bus2")`)
3. timesteps in `1:net.Ntimesteps`
For example, accessing the edge variable `:sij` one edge `("bus1", "bus2")` voltage variable at time
step `5` looks like:
```julia
m[:sij][("bus1", "bus2")][5]
```
"""
function add_time_vector_variables!(
    m::JuMP.AbstractModel, 
    net::Network{SinglePhase}, 
    var_symbol::Symbol, 
    indices::AbstractVector{T};
    set::DataType=Real
) where {T}
    if set == Real
        jump_type = JuMP.VariableRef
    elseif set == ComplexPlane
        jump_type = GenericAffExpr{ComplexF64, VariableRef}
    else
        throw(@error "Got invalid set for creating variables: $set. Only Real and ComplexPlane are supported")
    end
    m[var_symbol] = Dict{T, AbstractVector{jump_type}}()
    for i in indices
        if set == Real  # Real is the default set and the @variable macro does not work with it passed in
            m[var_symbol][i] = @variable(m, [1:net.Ntimesteps])
        else
         m[var_symbol][i] = @variable(m, [1:net.Ntimesteps]; set=set())
        end
    end
    push!(net.var_names, var_symbol)
    nothing
end


# MultiPhase variable containers and builders
"""
    multiphase_variable_container(FirstKeyType::DataType; default::DefaultType=missing)

Return a DefaultDict of DefaultDict with three key types for indexing variables on:
1. `FirstKeyType`, typ. `AbstractString` for bus variables or `Tuple{String, String}` for edge variables
2. `Int` for time step
3. `AbstractVecOrMat` for vectors or matrices of phase variables
"""
function multiphase_variable_container(FirstKeyType::DataType; default::DefaultType=missing) where DefaultType
    builder = ( () -> DefaultDict{Int, Union{AbstractVecOrMat, DefaultType}}(default) )
    return DefaultDict{FirstKeyType, DefaultDict}(builder)
end


"""
    multiphase_bus_variable_container(; default::DefaultType=missing)

Return a DefaultDict of DefaultDict with three key types for indexing variables on:
1. `AbstractString` for bus names
2. `Int` for time step
3. `AbstractVecOrMat` for vectors or matrices of phase variables
"""
function multiphase_bus_variable_container(; default=missing)
    multiphase_variable_container(AbstractString; default=default)
end


"""
    multiphase_edge_variable_container(; default::DefaultType=missing)

Return a DefaultDict of DefaultDict with three key types for indexing variables on:
1. `Tuple{String, String}` for edge names
2. `Int` for time step
3. `AbstractVecOrMat` for vectors or matrices of phase variables
"""
function multiphase_edge_variable_container(; default=missing)
    multiphase_variable_container(Tuple{String, String}; default=default)
end


"""
    add_complex_vector_of_phase_variable!

Add a complex variable to the model `m` indexed by
1. `var_symbol` like `:v`
2. `bus_or_edge`
3. `time_step`  # TODO have not made the swap of time and bus_or_edge in this method yet
4. phase in `[1, 2, 3]`
```julia
# initialize variable as zeros that will remain for undefined phases

m[var_symbol][bus_or_edge][time_step] = convert(
    Vector{GenericAffExpr{ComplexF64, VariableRef}}, 
    [0im; 0im; 0im]
)
```
Upper and lower bounds are added if provided using constraints.
"""
function add_complex_vector_of_phase_variable!(
    m::JuMP.AbstractModel, 
    net::Network{MultiPhase},
    bus_or_edge::Union{String, Tuple{String, String}},
    var_symbol::Symbol,
    time_step::Int;
    upper_bound_real::Union{Real, Missing} = missing,
    lower_bound_real::Union{Real, Missing} = missing,
    upper_bound_imag::Union{Real, Missing} = missing,
    lower_bound_imag::Union{Real, Missing} = missing,
    upper_bound_mag::Union{Real, Missing} = missing,
    lower_bound_mag::Union{Real, Missing} = missing,
    )

    j = bus_or_edge  # an edge has two busses: (i, j)
    if isa(bus_or_edge, Tuple{String, String})
        j = bus_or_edge[2]
    end

    # initialize variable as zeros that will remain for undefined phases
    m[var_symbol][bus_or_edge][time_step] = convert(
        Vector{GenericAffExpr{ComplexF64, VariableRef}}, 
        [0im; 0im; 0im]
    )

    # fill in variables for complex vectors of phase
    # TODO vectorize variable definitions
    for phs in phases_connected_to_bus(net, j)

        m[var_symbol][bus_or_edge][time_step][phs] = @variable(m, 
            set = ComplexPlane(), 
            base_name=string(var_symbol) * "_" * string(time_step) *"_"* join([string(s) for s in bus_or_edge]) * "_" *  string(phs)
        )
        
        if !(ismissing(upper_bound_real))
            @constraint(m, real(m[var_symbol][bus_or_edge][time_step][phs]) <= upper_bound_real)
        end
        
        if !(ismissing(lower_bound_real))
            @constraint(m, lower_bound_real <= real(m[var_symbol][bus_or_edge][time_step][phs]))
        end
        
        if !(ismissing(upper_bound_imag))
            @constraint(m, imag(m[var_symbol][bus_or_edge][time_step][phs]) <= upper_bound_imag)
        end
        
        if !(ismissing(lower_bound_imag))
            @constraint(m, lower_bound_imag <= imag(m[var_symbol][bus_or_edge][time_step][phs]))
        end
        
        if !(ismissing(upper_bound_mag))
            x_real = real(m[var_symbol][bus_or_edge][time_step][phs])
            x_imag = imag(m[var_symbol][bus_or_edge][time_step][phs])
            @constraint(m, x_real^2 + x_imag^2 <= upper_bound_mag^2)
        end
        
        if !(ismissing(lower_bound_mag))
            x_real = real(m[var_symbol][bus_or_edge][time_step][phs])
            x_imag = imag(m[var_symbol][bus_or_edge][time_step][phs])
            @constraint(m, lower_bound_mag^2 <= x_real^2 + x_imag^2)
        end

    end
    nothing
end