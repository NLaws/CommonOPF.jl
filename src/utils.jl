"""
    function i_to_j(j::AbstractString, p::Inputs)
find all busses upstream of bus j

!!! note
    In a radial network this function should return an Array with length of 1.
"""
function i_to_j(j::AbstractString, p::Inputs)
    convert(Array{String, 1}, map(x->x[1], filter(t->t[2]==j, p.edges)))
end


"""
    function j_to_k(j::AbstractString, p::Inputs)
find all busses downstream of bus j
"""
function j_to_k(j::AbstractString, p::Inputs)
    convert(Array{String, 1}, map(x->x[2], filter(t->t[1]==j, p.edges)))
end


"""
    get_ij_idx(i::AbstractString, j::AbstractString, p::Inputs)

get the index for edge i->j in the `Inputs`` edge vectors: 
    `edges`, `linecodes`, `phases`, `edge_keys`, and `linelengths`
"""
function get_ij_idx(i::AbstractString, j::AbstractString, p::Inputs)
    ij_idxs = findall(t->(t[1]==i && t[2]==j), p.edges)
    if length(ij_idxs) > 1
        error("found more than one edge for i=$i and j=$j")
    elseif length(ij_idxs) == 0
        error("found no matching edges for i=$i and j=$j")
    else
        return ij_idxs[1]
    end
end


function get_ijlinelength(i::AbstractString, j::AbstractString, p::Inputs)
    ij_idx = get_ij_idx(i, j, p)
    return p.linelengths[ij_idx]
end


function get_ijlinecode(i::AbstractString, j::AbstractString, p::Inputs)
    ij_idx = get_ij_idx(i, j, p)
    return p.linecodes[ij_idx]
end


function get_ijedge(i::AbstractString, j::AbstractString, p::Inputs)
    ij_idx = get_ij_idx(i, j, p)
    return p.edges[ij_idx]
end


"""
    delete_edge_index!(idx::Int, p::Inputs)

Delete all the edge attributes in `Inputs`` at index `idx`
"""
function delete_edge_index!(idx::Int, p::Inputs)
    deleteat!(p.edges,       idx)
    deleteat!(p.linecodes,   idx)
    deleteat!(p.phases,      idx)
    deleteat!(p.linelengths, idx)
    deleteat!(p.edge_keys,   idx)
    true
end


"""
    delete_edge_ij!(i::String, j::String, p::Inputs)

delete edge `(i, j)` from
- p.edges
- p.phases
- p.linelengths
- p.edge_keys
- p.Isquared_up_bounds

NOTE do not delete!(p.Zdict, ij_linecode) nor delete!(p.Isquared_up_bounds, ij_linecode) 
because anything indexed on linecodes can be used for multiple lines
"""
function delete_edge_ij!(i::String, j::String, p::Inputs)
    idx = get_ij_idx(i, j, p)
    delete_edge_index!(idx, p)
    true
end


"""
    delete_bus_j!(j::String, p::Inputs)

Remove bus `j` from `p.busses`
"""
function delete_bus_j!(j::String, p::Inputs)
    p.busses = setdiff(p.busses, [j])
    if j in keys(p.Pload)
        delete!(p.Pload, j)
    end
    if j in keys(p.Qload)
        delete!(p.Qload, j)
    end
    if j in keys(p.phases_into_bus)
        delete!(p.phases_into_bus, j)
    end
    true
end


"""
    check_paths(paths::AbstractVecOrMat, p::Inputs)

paths is vector of vectors containing bus names for parallel lines.
if any load busses are in the paths then an error is thrown because we are not handling that case yet.
"""
function check_paths(paths::AbstractVecOrMat, p::Inputs)
    load_busses = union(keys(p.Pload), keys(p.Qload))
    for path in paths, bus in path
        if bus in load_busses
            @error("At least one load bus is in the parallel lines: not merging.")
        end
    end
    true
end


"""
    reg_busses(p::Inputs)

All of the regulated busses, i.e. the second bus in the regulated edges
"""
function reg_busses(p::Inputs)
    getindex.(keys(p.regulators), 2)
end


function turn_ratio(p::Inputs, b::AbstractString)
    if !(b in reg_busses(p))
        throw(@error "Bus $b is not a regulated bus")
    end
    for (edge_tuple, d) in p.regulators
        if edge_tuple[2] == b
            return d[:turn_ratio]
        end
    end
end


function has_vreg(p::Inputs, b::AbstractString)
    for (edge_tuple, d) in p.regulators
        if edge_tuple[2] == b  && :vreg in keys(d)
            return true
        end
    end
    return false
end


function vreg(p::Inputs, b::AbstractString)
    if !(b in reg_busses(p))
        throw(@error "Bus $b is not a regulated bus")
    end
    for (edge_tuple, d) in p.regulators
        if edge_tuple[2] == b  && :vreg in keys(d)
            return d[:vreg]
        end
    end
    false
end