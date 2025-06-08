
function print_constraint_info(net::Network)
    varinfos = collect(values(net.constraint_info))
    header_syms = fieldnames(CommonOPF.ConstraintInfo)
    header = vec([string(f) for f in header_syms])
    flat_data = [string(getfield(s, f)) for s in varinfos, f in header_syms]

    # Always reshape into (n_rows, n_cols)
    data_matrix = reshape(flat_data, length(varinfos), length(header_syms))

    # format the dimensions by removing "CommonOPF." prefix and "Dimension" suffix
    # e.g. "(CommonOPF.BusDimension, CommonOPF.TimeDimension, CommonOPF.PhaseDimension)"
    # becomes "(Bus, Time, Phase)"
    dim_idx = indexin(["dimensions"], header)[1]
    for i in 1:size(data_matrix, 1)
        dims = data_matrix[i, dim_idx]
        # Remove surrounding parentheses
        inner = dims[2:end-1]
        # Split by comma and optional spaces
        parts = split(inner, r",\s*")
        # Remove "CommonOPF." prefix and "Dimension" suffix from each part
        cleaned_parts = [
            replace(p, r"^CommonOPF\." => "") |> x -> replace(x, r"Dimension$" => "") for p in parts
        ]
        # Join back with comma and add parentheses
        data_matrix[i, dim_idx] = "(" * join(cleaned_parts, ", ") * ")"
    end
    # Sort by column 1 ("symbol")
    rows = [data_matrix[i, :] for i in 1:size(data_matrix, 1)]

    # Sort by a specific column — e.g., "symbol"
    col_index = findfirst(==("symbol"), header)
    sorted_rows = sort(rows, by = row -> row[col_index])

    # Convert back to matrix
    if length(sorted_rows) > 0
        data_matrix = reduce(vcat, permutedims.(sorted_rows))
    end

    bold_crayon = Crayon(foreground = :blue, background = :black, bold = :true)

    # Print with PrettyTables
    pretty_table(
        data_matrix; 
        header = header, 
        hlines = :all, # Add horizontal lines between all rows
        autowrap = true,
        backend = Val(:text),
        header_crayon=bold_crayon,
    )
end
