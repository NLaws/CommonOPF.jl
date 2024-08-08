

function add_time_vector_variables!(
    m::JuMP.AbstractModel, 
    net::Network{SinglePhase}, 
    var_symbol::Symbol, 
    indices::AbstractVector{T} 
) where {T}
    m[var_symbol] = Dict{T, AbstractVector{JuMP.VariableRef}}()
    for i in indices
        m[var_symbol][i] = @variable(m, [1:net.Ntimesteps])
    end
end


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

    j = bus_or_edge
    if isa(bus_or_edge, Tuple{String, String})
        j = bus_or_edge[2]
    end

    # initialize variable as zeros that will remain for undefined phases
    m[var_symbol][time_step][bus_or_edge] = convert(
        Vector{GenericAffExpr{ComplexF64, VariableRef}}, 
        [0im; 0im; 0im]
    )

    # fill in variables for complex vectors of phase
    # TODO vectorize variable definitions
    for phs in phases_into_bus(net, j)

        m[var_symbol][time_step][bus_or_edge][phs] = @variable(m, 
            set = ComplexPlane(), 
            base_name=string(var_symbol) * "_" * string(time_step) *"_"* join([string(s) for s in bus_or_edge]) * "_" *  string(phs)
        )
        
        if !(ismissing(upper_bound_real))
            @constraint(m, real(m[var_symbol][time_step][bus_or_edge][phs]) <= upper_bound_real)
        end
        
        if !(ismissing(lower_bound_real))
            @constraint(m, lower_bound_real <= real(m[var_symbol][time_step][bus_or_edge][phs]))
        end
        
        if !(ismissing(upper_bound_imag))
            @constraint(m, imag(m[var_symbol][time_step][bus_or_edge][phs]) <= upper_bound_imag)
        end
        
        if !(ismissing(lower_bound_imag))
            @constraint(m, lower_bound_imag <= imag(m[var_symbol][time_step][bus_or_edge][phs]))
        end
        
        if !(ismissing(upper_bound_mag))
            x_real = real(m[var_symbol][time_step][bus_or_edge][phs])
            x_imag = imag(m[var_symbol][time_step][bus_or_edge][phs])
            @constraint(m, x_real^2 + x_imag^2 <= upper_bound_mag^2)
        end
        
        if !(ismissing(lower_bound_mag))
            x_real = real(m[var_symbol][time_step][bus_or_edge][phs])
            x_imag = imag(m[var_symbol][time_step][bus_or_edge][phs])
            @constraint(m, lower_bound_mag^2 <= x_real^2 + x_imag^2)
        end

    end
    nothing
end