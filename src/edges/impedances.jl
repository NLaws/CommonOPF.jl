# todo rij and rij_pu and _per_length methods for all edge types
# change edge attributes to r/x_per_length for clarity
# all supertype of AbstractEdge must have impedances, even if zero; decide where to put default
# valeu of zeros


function resistance_per_length(c::Conductor)
    if ismissing(c.phases)  # single phase
        return c.r1
    end
    return c.rmatrix
end


"""


"""
function resistance(c::Conductor)
    resistance_per_length(c) * c.length
end




function reactance_per_length(c::Conductor)
    if ismissing(c.phases)  # single phase
        return c.x1
    end
    return c.xmatrix
end


"""


"""
function reactance(c::Conductor)
    reactance_per_length(c) * c.length
end

function rij(i::AbstractString, j::AbstractString, net::Network{SinglePhase})
    resitance(net[(i,j)])
end

function rij_per_unit(i::AbstractString, j::AbstractString, net::Network{SinglePhase})
    resitance(net[(i,j)]) / net.Zbase
end


function xij(i::AbstractString, j::AbstractString, net::Network{SinglePhase})
    net[(i,j)].x1 * net[(i,j)].length
end



function xij_perunit(i::AbstractString, j::AbstractString, net::Network{SinglePhase})
    net[(i,j)].x1 * net[(i,j)].length / net.Zbase
end




function resistance(vr::VoltageRegulator)
    
end

function resistance(trfx::Transformer)

end


"""
    function zij(i::AbstractString, j::AbstractString, net::Network{SinglePhase})::Tuple{Real, Real}

Impedance for single phase models. 

Returns `(r1, x1) * length / net.Zbase` for the `Conductor` at `net[(i, j)]`.

TODO convert impedance methods to dispatch on edge type
TODO MultiPhase
"""
function zij(i::AbstractString, j::AbstractString, net::Network{SinglePhase})::Tuple{Real, Real}
    # only have Conductor edges now, later add impedances of other devices
    conductor = net[(i, j)]
    if ismissing(conductor)
        throw(ErrorException("No conductor found for edge ($i, $j)"))
    elseif typeof(conductor) != CommonOPF.Conductor
        throw(@error "Was looking for a Conductor in edge ($i, $j) but found a $(typeof(conductor))")
    end
    # TODO should instead dispatch on edge type
    # check for template 
    if !ismissing(conductor.template)
        conds = collect(conductors(net))
        results = filter(cond -> !ismissing(cond.name) && cond.name == conductor.template, conds)
        if length(results) == 0
            throw(ErrorException("No conductor template with name $conductor.template found."))
        end
        template_conductor = results[1]
        r1, x1 = template_conductor.r1, template_conductor.x1
    else  # get impedance from the conductor
        r1, x1 = conductor.r1, conductor.x1
    end
    if ismissing(r1) || ismissing(x1)
        throw(ErrorException("Missing at least one of r1 and x1 for edge ($i, $j)"))
    end
    L = conductor.length
    return (r1 * L / net.Zbase, x1 * L / net.Zbase)
end