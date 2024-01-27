

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