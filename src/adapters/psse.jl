"""
Utilities for parsing PSS/E RAW files.
"""

"""
    v33 = Dict{Symbol, Int}

Column indices for the v33 RAW format. See [./psse_raw_v33_format.md](./psse_raw_v33_format.md)
"""
const v33 = Dict{Symbol, Int}(

    # Bus data
    :bus_number => 1,
    :bus_kv => 3,
    :bus_type => 4,

    # Branch data
    :branch_from => 1,
    :branch_to => 2,
    :branch_r_pu => 4,
    :branch_x_pu => 5,

    # Transformer data (row 1 & row 2/3)
    :xf_bus1 => 1,
    :xf_bus2 => 2,
    :xf_r_pu => 1,
    :xf_x_pu => 2,
    :xf_high_kv => 9,
    :xf_low_kv => 10,

    # Generator data
    :gen_bus => 1,
    :id => 2,
    :pg => 3,
    :qg => 4,
    :qmax => 5,
    :qmin => 6,
    :voltage_pu => 7,
    :reg_bus => 8,
    :mva_base => 9,
    :zr => 10,
    :zx => 11,
    :rt => 12,
    :xt => 13,
    :gtap => 14,
    :status => 15,
    :rmpct => 16,
    :pmax => 17,
    :pmin => 18,

    # Load data
    :load_bus => 1,
    :p_mw => 6,
    :q_mvar => 7,

    # Fixed shunt data
    :shunt_bus => 1,
    :shunt_id => 2,
    :shunt_status => 3,
    :shunt_g_mw => 4,
    :shunt_b_mvar => 5,
)


"""
    psse_bus_data(lines::Vector{String})::Tuple{Dict, String}

Return a dict of bus name to kV and the slack bus. The slack bus is `missing` if no `bus_type == "3`
(`IDE` in PSSE).
"""
function psse_bus_data(lines::Vector{String})::Tuple{Dict, String}
    header = split(lines[1], ",")
    version = parse(Int, strip(header[3]))
    v = version == 33 ? v33 : throw(ArgumentError("Unsupported PSS/E RAW version $(version)"))

    slack_bus::Union{Missing, String} = missing
    bus_start = 4
    bus_end = findfirst(x -> occursin("END OF BUS DATA", x), lines) - 1
    bus_kv = Dict{String, Float64}()
    for ln in lines[bus_start:bus_end]
        cols = split(ln, ",")
        bus_kv[strip(cols[v[:bus_number]])] = parse(Float64, cols[v[:bus_kv]])
        if strip(cols[v[:bus_type]]) == "3"
            slack_bus = strip(cols[v[:bus_number]])
        end
    end
    return bus_kv, slack_bus
end


"""
    psse_branch_data(lines::Vector{String}, bus_kv::Dict{String, Float64})

Parse the branch section of a PSS/E RAW file and convert
per-unit impedances to ohms. Only version 33 RAW files are currently
supported and the parsing will throw an error for any other version.
Returns a vector of dictionaries suitable for [`Conductor`](@ref) objects.
"""
function psse_branch_data(lines::Vector{String}, bus_kv::Dict{String, Float64})
    header = split(lines[1], ",")
    MVA_base = parse(Float64, strip(header[2]))
    version = parse(Int, strip(header[3]))
    v = version == 33 ? v33 : throw(ArgumentError("Unsupported PSS/E RAW version $(version)"))

    br_start = findfirst(x -> occursin("BEGIN BRANCH DATA", x), lines) + 1
    br_end = findfirst(x -> occursin("END OF BRANCH DATA", x), lines) - 1

    conductor_dicts = Dict{Symbol, Any}[]
    for ln in lines[br_start:br_end]
        cols = split(ln, ",")
        bus1 = strip(cols[v[:branch_from]])
        bus2 = strip(cols[v[:branch_to]])
        r_pu = parse(Float64, cols[v[:branch_r_pu]])
        x_pu = parse(Float64, cols[v[:branch_x_pu]])
        Z_base = (bus_kv[bus1]^2) / MVA_base
        push!(conductor_dicts, Dict(
            :busses => (bus1, bus2),
            :r1 => r_pu * Z_base,
            :x1 => x_pu * Z_base,
            :length => 1.0,
        ))
    end

    return conductor_dicts

end


"""
    psse_transformer_data(lines::Vector{String}, bus_kv::Dict{String, Float64})

Parse the transformer section of a PSS/E RAW file and convert
per-unit impedances to ohms. Only version 33 RAW files are currently
supported and the parsing will throw an error for any other version.
Returns a vector of dictionaries suitable for [`Transformer`](@ref) objects.
"""
function psse_transformer_data(lines::Vector{String}, bus_kv::Dict{String, Float64})
    header = split(lines[1], ",")
    MVA_base = parse(Float64, strip(header[2]))
    version = parse(Int, strip(header[3]))
    v = version == 33 ? v33 : throw(ArgumentError("Unsupported PSS/E RAW version $(version)"))

    tr_start = findfirst(x -> occursin("BEGIN TRANSFORMER DATA", x), lines) + 1
    tr_end = findfirst(x -> occursin("END OF TRANSFORMER DATA", x), lines) - 1

    transformer_dicts = Dict{Symbol, Any}[]
    for i in tr_start:4:tr_end
        row1 = split(lines[i], ",")
        row2 = split(lines[i + 1], ",")
        row3 = split(lines[i + 2], ",")
        bus1 = strip(row1[v[:xf_bus1]])
        bus2 = strip(row1[v[:xf_bus2]])
        r_pu = parse(Float64, row2[v[:xf_r_pu]])
        x_pu = parse(Float64, row2[v[:xf_x_pu]])
        high_kv = parse(Float64, row3[v[:xf_high_kv]])
        low_kv = parse(Float64, row3[v[:xf_low_kv]])
        Z_base = (bus_kv[bus1]^2) / MVA_base
        push!(transformer_dicts, Dict(
            :busses => (bus1, bus2),
            :high_kv => high_kv,
            :low_kv => low_kv,
            :resistance => r_pu * Z_base,
            :reactance => x_pu * Z_base,
        ))
    end

    return transformer_dicts
end


"""
    psse_generator_data(lines::Vector{String}, bus_kv::Dict{String, Float64})

Parse the generator section of a PSS/E RAW (v33) file and return a vector of
dictionaries for [`Generator`](@ref) objects. Impedance values are converted from
per-unit to ohms.
"""
function psse_generator_data(lines::Vector{String}, bus_kv::Dict{String, Float64})
    header = split(lines[1], ",")
    MVA_base = parse(Float64, strip(header[2]))
    version = parse(Int, strip(header[3]))
    v = version == 33 ? v33 : throw(ArgumentError("Unsupported PSS/E RAW version $(version)"))

    gen_start = findfirst(x -> occursin("BEGIN GENERATOR DATA", x), lines) + 1
    gen_end = findfirst(x -> occursin("END OF GENERATOR DATA", x), lines) - 1

    # TODO merge with prior generator fields like is_PV_bus, which requires checking if pg and vg
    # are set? as well as the bus data with IDE = 2 (Generator)

    generator_dicts = Dict{Symbol, Any}[]
    for ln in lines[gen_start:gen_end]
        cols = split(ln, ",")
        bus = strip(cols[v[:gen_bus]])
        name = strip(cols[v[:id]], ['\'', ' '])
        pg = parse(Float64, cols[v[:pg]])
        qg = parse(Float64, cols[v[:qg]])
        qmax = parse(Float64, cols[v[:qmax]])
        qmin = parse(Float64, cols[v[:qmin]])
        voltage_pu = parse(Float64, cols[v[:voltage_pu]])
        reg_bus = strip(cols[v[:reg_bus]]) 
        mva_base = parse(Float64, cols[v[:mva_base]])
        Z_base = (bus_kv[bus]^2) / MVA_base
        r_step_up = parse(Float64, cols[v[:zr]])
        x_step_up = parse(Float64, cols[v[:zx]])
        r_tapping = parse(Float64, cols[v[:rt]])
        x_tapping = parse(Float64, cols[v[:xt]])
        z_trfx = Z_base * ( (r_step_up + r_tapping) + im * (x_step_up + x_tapping) )
        gtap = parse(Float64, cols[v[:gtap]])
        status = parse(Int, cols[v[:status]])
        rmpct = parse(Float64, cols[v[:rmpct]])
        pmax = parse(Float64, cols[v[:pmax]])
        pmin = parse(Float64, cols[v[:pmin]])
        push!(generator_dicts, Dict(
            :bus => bus,
            :name => name,
            :pg => pg,
            :qg => qg,
            :qmax => qmax,
            :qmin => qmin,
            :voltage_pu => voltage_pu,
            :reg_bus => reg_bus == "0" ? missing : reg_bus,
            :mva_base => mva_base,
            :z_transformers => z_trfx,
            :gtap => gtap,
            :status => status,  # TODO parse inactive generators? if so makes this a bool for :active
            :rmpct => rmpct,
            :pmax => pmax,
            :pmin => pmin,
        ))
    end

    return generator_dicts
end


"""
    psse_load_data(lines::Vector{String})

Parse the load section of a PSS/E RAW (v33) file and return a vector of
[`Load`](@ref) dictionaries. The MW/MVAr values are converted to single-phase
kW/kVAr loads.
"""
function psse_load_data(lines::Vector{String})
    header = split(lines[1], ",")
    version = parse(Int, strip(header[3]))
    v = version == 33 ? v33 : throw(ArgumentError("Unsupported PSS/E RAW version $(version)"))

    ld_start = findfirst(x -> occursin("BEGIN LOAD DATA", x), lines) + 1
    ld_end = findfirst(x -> occursin("END OF LOAD DATA", x), lines) - 1

    load_dicts = Dict{Symbol, Any}[]
    for ln in lines[ld_start:ld_end]
        cols = split(ln, ",")
        bus = strip(cols[v[:load_bus]])
        p_mw = parse(Float64, cols[v[:p_mw]])
        q_mvar = parse(Float64, cols[v[:q_mvar]])
        kw_per_phase = (p_mw * 1e3) / 3
        kvar_per_phase = (q_mvar * 1e3) / 3
        push!(load_dicts, Dict(
            :bus => bus,
            :kws1 => [kw_per_phase],
            :kvars1 => [kvar_per_phase],
        ))
    end

    return load_dicts
end


"""
    psse_shunt_data(lines::Vector{String}, bus_kv::Dict{String, Float64})

Parse the fixed shunt section of a PSS/E RAW (v33) file and return a vector of
[`ShuntAdmittance`](@ref) dictionaries with conductance and susceptance in
siemens.
"""
function psse_shunt_data(lines::Vector{String}, bus_kv::Dict{String, Float64})
    header = split(lines[1], ",")
    MVA_base = parse(Float64, strip(header[2]))
    version = parse(Int, strip(header[3]))
    v = version == 33 ? v33 : throw(ArgumentError("Unsupported PSS/E RAW version $(version)"))

    sh_start = findfirst(x -> occursin("BEGIN FIXED SHUNT DATA", x), lines) + 1
    sh_end = findfirst(x -> occursin("END OF FIXED SHUNT DATA", x), lines) - 1

    shunt_dicts = Dict{Symbol, Any}[]
    for ln in lines[sh_start:sh_end]
        cols = split(ln, ",")
        bus = strip(cols[v[:shunt_bus]])
        status = parse(Int, cols[v[:shunt_status]])
        gl = parse(Float64, cols[v[:shunt_g_mw]])
        bl = parse(Float64, cols[v[:shunt_b_mvar]])
        if status != 0
            V = bus_kv[bus] * 1e3
            g = gl * 1e6 / V^2
            b = bl * 1e6 / V^2
            push!(shunt_dicts, Dict(
                :bus => bus,
                :g => g,
                :b => b,
            ))
        end
    end

    return shunt_dicts
end


"""
    psse_to_Network(fp::AbstractString; allow_parallel_conductor::Bool=false)::Network

Parse a PSS/E RAW file and convert it into a [`Network`](@ref). Only version 33
RAW files are supported. Set `allow_parallel_conductor=true` to merge duplicate lines between the same pair of busses.
"""
function psse_to_Network(fp::AbstractString; allow_parallel_conductor::Bool=false)::Network
    lines = readlines(fp)

    header = split(lines[1], ",")
    MVA_base = parse(Float64, strip(header[2]))
    version = parse(Int, strip(header[3]))
    v = version == 33 ? v33 : throw(ArgumentError("Unsupported PSS/E RAW version $(version)"))

    bus_kv, slack_bus = psse_bus_data(lines)

    conds = psse_branch_data(lines, bus_kv)
    transformers = psse_transformer_data(lines, bus_kv)
    gens = psse_generator_data(lines, bus_kv)
    loads = psse_load_data(lines)
    shunts = psse_shunt_data(lines, bus_kv)

    Vbase = bus_kv[slack_bus] * 1e3

    net_dict = Dict{Symbol, Any}(
        :Network => Dict(
            :substation_bus => slack_bus,
            :Vbase => Vbase,
            :Sbase => MVA_base * 1e6,
        ),
        :Conductor => conds,
        :Transformer => transformers,
        :Generator => gens,
        :Load => loads,
        :ShuntAdmittance => shunts,
    )

    Network(net_dict; allow_parallel_conductor=allow_parallel_conductor)
end
