# TODO mv MultiPhase rij xij to CommonOPF (requires something new to handle BFM vs. LDF)


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