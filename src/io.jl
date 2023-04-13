



function heads(edges:: Vector{Tuple})
    return collect(e[1] for e in edges)
end