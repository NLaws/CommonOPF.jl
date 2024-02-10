# TODO mv MultiPhase rij xij to CommonOPF (requires something new to handle BFM vs. LDF)
"""
    rij(i::AbstractString, j::AbstractString, p::Inputs{SinglePhase})

The per-unit resistance of line i->j
"""
function rij(i::AbstractString, j::AbstractString, p::Inputs{SinglePhase})
    linecode = get_ijlinecode(i, j, p)
    linelength = get_ijlinelength(i, j, p)
    rmatrix = p.Zdict[linecode]["rmatrix"] * linelength / p.Zbase
    return rmatrix[1]  # 1 index b/c single phase
end





"""
    xij(i::AbstractString, j::AbstractString, p::Inputs{SinglePhase})

The per-unit reacttance of line i->j
"""
function xij(i::AbstractString, j::AbstractString, p::Inputs{SinglePhase})
    linecode = get_ijlinecode(i, j, p)
    linelength = get_ijlinelength(i, j, p)
    xmatrix = p.Zdict[linecode]["xmatrix"] * linelength / p.Zbase
    return xmatrix[1]  # 1 index b/c single phase
end





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
function check_paths_for_loads(paths::AbstractVecOrMat, net::Network)
    for path in paths, bus in path
        if bus in load_busses(net)
            throw("At least one load bus is in the parallel lines: not merging.")
        end
    end
    true
end


"""
    leaf_busses(p::Inputs)

returns `Vector{String}` containing all of the leaf busses in `p.busses`
"""
function leaf_busses(p::Inputs)
    leafs = String[]
    for j in p.busses
        if !isempty(i_to_j(j, p)) && isempty(j_to_k(j, p))
            push!(leafs, j)
        end
    end
    return leafs
end


"""
    trim_tree_once!(p::Inputs)

A support function for `trim_tree!`. When trimming the tree sometimes new leafs are created. 
So `trim_tree!` loops over `trim_tree_once!`.
"""
function trim_tree_once!(p::Inputs)
    trimmable_busses = setdiff(leaf_busses(p), union(keys(p.Pload), keys(p.Qload)))
    if isempty(trimmable_busses) return false end
    trimmable_edges = Tuple[]
    for j in trimmable_busses
        for i in i_to_j(j, p)
            push!(trimmable_edges, (i,j))
        end
    end
    @debug("Deleting the following edges from the Inputs:")
    for edge in trimmable_edges @debug(edge) end
    for (i,j) in trimmable_edges
        delete_edge_ij!(i, j, p)
        delete_bus_j!(j, p)
    end
    true
end


"""
    trim_tree!(p::Inputs)

Trim any branches that do not contain load busses.
"""
function trim_tree!(p::Inputs)
    n_edges_before = length(p.edges)
    trimming = trim_tree_once!(p)
    while trimming
        trimming = trim_tree_once!(p)
    end
    n_edges_after = length(p.edges)
    @info("Removed $(n_edges_before - n_edges_after) edges.")
    true
end


# """
#     remove_bus!(j::String, p::Inputs{MultiPhase})

# Remove bus `j` in the line i->j->k from the model by making an equivalent line from busses i->k
# """
# function remove_bus!(j::String, p::Inputs{MultiPhase})
#     # get all the old values
#     i, k = i_to_j(j, p)[1], j_to_k(j, p)[1]
#     ij_idx, jk_idx = get_ij_idx(i, j, p), get_ij_idx(j, k, p)
#     ij_len, jk_len = p.linelengths[ij_idx], p.linelengths[jk_idx]
#     ij_linecode, jk_linecode = get_ijlinecode(i,j,p), get_ijlinecode(j,k,p)
#     # scale impedances by lengths s.t. we can make per length again using ik_len
#     r_ij, x_ij = p.Zdict[ij_linecode]["rmatrix"] * ij_len, p.Zdict[ij_linecode]["xmatrix"] * ij_len
#     r_jk, x_jk = p.Zdict[jk_linecode]["rmatrix"] * jk_len, p.Zdict[jk_linecode]["xmatrix"] * jk_len
#     # NOTE the r,x matrices can be 1D, 2D, or 3D; but we convert to 3D for use in model building
#     # (this is a vestige of OpenDSS that should be removed TODO)
#     phases = p.phases[ij_idx]
#     # make the new values
#     r_ik = r_ij .+ r_jk
#     x_ik = x_ij .+ x_jk
#     ik_len = ij_len + jk_len
#     ik_linecode = ik_key = i * "-" * k
#     ik_amps = minimum([p.Isquared_up_bounds[ij_linecode], p.Isquared_up_bounds[jk_linecode]])
#     # delete the old values
#     delete_edge_ij!(i, j, p)
#     delete_edge_ij!(j, k, p)
#     delete_bus_j!(j, p)
#     # add the new values
#     push!(p.edges, (i, k))
#     push!(p.linecodes, ik_linecode)
#     push!(p.phases, phases)
#     push!(p.linelengths, ik_len)
#     push!(p.edge_keys, ik_key)
#     p.Zdict[ik_linecode] = Dict(
#         "nphases" => length(phases),
#         "name" => ik_linecode,
#         "rmatrix" => r_ik ./ ik_len,
#         "xmatrix" => x_ik ./ ik_len,
#     )
#     p.Isquared_up_bounds[ik_linecode] = ik_amps
# end


function heads(edges:: Vector{Tuple})
    return collect(e[1] for e in edges)
end


function tails(edges:: Vector{Tuple})
    return collect(e[2] for e in edges)
end