# TODO mv MultiPhase rij xij to CommonOPF (requires something new to handle BFM vs. LDF)

"""
    check_paths(paths::AbstractVecOrMat, net::Network)

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


function heads(edges:: Vector{Tuple})
    return collect(e[1] for e in edges)
end


function tails(edges:: Vector{Tuple})
    return collect(e[2] for e in edges)
end
