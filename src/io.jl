


function dss_files_to_dict(dssfilepath::String)
    # TODO change to use OpenDSSDirect.jl and convert to same dict that comes from load_yaml
    d = let d
        with_logger(SimpleLogger(Error)) do  # lots of info from parse_dss
            open(dssfilepath) do io
                parse_dss(io)  # method from PowerModelsDistribution
            end
        end
    end
    return d
end


"""
    strip_phases(bus::AbstractString)

strip off phases in a bus string that use the OpenDSS convention of dots like "bus_name.1.2"
"""
function strip_phases(bus::AbstractString)::AbstractString
    if !occursin(".", bus)
        return bus
    end
    string(chop(bus, tail=length(bus)-findfirst('.', bus)+1))
end


get_phases(bus::AbstractString) = sort!(collect(parse(Int,ph) for ph in split(bus[findfirst('.', bus)+1:end], ".")))


"""
    fill_transformer_vals!(d::Dict, p::Inputs)

Fill in necessary values for parsing transformers in the dict from parse_dss
"""
function fill_transformer_vals!(d::Dict, Sbase::Real, Vbase::Real)
    d["%r"]   = get(d, "%r",   0.01)
    d["%r_2"] = get(d, "%r_2", 0.01)

    if "kvs" in keys(d)
        d["kv"], d["kv_2"] = d["kvs"]
    else
        d["kv"]   = get(d, "kv", Vbase / 1000)
        d["kv_2"] = get(d, "kv_2", Vbase / 1000)
    end

    if "buses" in keys(d)
        d["bus"], d["bus_2"] = d["buses"]
    else
        d["bus"]   = get(d, "bus", nothing)
        d["bus_2"] = get(d, "bus_2", nothing)
    end

    # need to strip phases from bus names to use bus names in matching edges later
    if occursin(".", d["bus"])
        d["phases_list"] = get_phases(d["bus"])
        d["bus"] = strip_phases(d["bus"])
    end

    if occursin(".", d["bus_2"])
        d["bus_2"] = strip_phases(d["bus_2"])
    end

    if "kvas" in keys(d)
        d["kva"], d["kva_2"] = d["kvas"]
    else
        d["kva"]   = get(d, "kva", Sbase / 1000)
        d["kva_2"] = get(d, "kva_2", Sbase / 1000)
    end

    d["xlt"] = get(d, "xlt", 1)
    d["xht"] = get(d, "xlt", 1)
    d["xhl"] = get(d, "xlt", 1)
end


"""
    dss_dict_to_arrays(d::Dict)

Parse the dict from PowerModelsDistribution.parse_dss into values needed for OPF modules

TODO need a standardize format for the output of parse_dss rather than following all the ways
    of defining things in openDSS (for example busses can be defined as an array or individual 
    call outs for some objects).
"""
function dss_dict_to_arrays(d::Dict, Sbase::Real, Vbase::Real, substation_bus::String; 
    enforce_tree::Bool=true)
    # TODO allocate empty arrays with number of lines
    # TODO separate this method into sub-methods, generally parse components separately
    edges = Tuple[]
    phases = Vector[]
    linecodes = String[]
    linelengths = Float64[]
    Isquared_up_bounds = Dict{String, Float64}()

    if !("linecode" in keys(d))
        d["linecode"] = Dict{String, Any}()  # we add it b/c we use it for storing R/X values
    end

    # some reuseable stuff
    function get_b1_b2_phs(v::Dict)
        if occursin(".", v["bus1"])  # have to account for .1.2 phases for example
            b1 = strip_phases(v["bus1"])
            phs = get_phases(v["bus1"])
        else  # default to 3 phases
            b1 = v["bus1"]
            if v["phases"] == 1
                phs = [1]
            else
                phs = [1,2,3]
            end
        end

        if occursin(".", v["bus2"])
            b2 = strip_phases(v["bus2"])
        else
            b2 = v["bus2"]
        end
        return b1, b2, phs
    end

    switches_to_check = String[]  # only add switches if they are not in parallel with a line
    for (k,v) in d["line"]  # Line dict includes switches
        if "switch" in keys(v) && v["switch"] == true
            push!(switches_to_check, k)
            continue
        end
        try
            b1, b2, phs = get_b1_b2_phs(v)
            # TODO option to merge lines if they split and come back together
            if b2 in tails(edges)
                if enforce_tree
                    @warn "Not adding line $k ($b1 to $b2) because there is already an edge into $b2"
                    continue
                else
                    @warn "Adding line into a bus with a line already into it: line $k ($b1 to $b2)"
                end
            end
            push!(edges, (b1, b2))
            push!(phases, phs)

            if "linecode" in keys(v)
                push!(linecodes, v["linecode"])
            else  # assume positive sequence
                v["linecode"] = v["name"]
                push!(linecodes, v["linecode"])
                d["linecode"][v["name"]] = Dict{String, Any}(
                    "rmatrix" => [v["r1"]],
                    "xmatrix" => [v["x1"]],
                    "nphases" => 1,
                    "name" => v["name"]
                )
            end

            # TODO ratings could be in linecode dict too
            # TODO assuming that there are linecodes, should converge on consistent keys for lines
            Isquared_up_bounds[v["linecode"]] = DEFAULT_AMP_LIMIT^2
            if "normamps" in keys(v) && !(v["normamps"] ≈ 0)  # assuming lowercase keys
                Isquared_up_bounds[v["linecode"]] = v["normamps"]^2
            elseif "emergamps" in keys(v) && !(v["emergamps"] ≈ 0)
                Isquared_up_bounds[v["linecode"]] = v["emergamps"]^2
            end

            # TODO handle scaling of lengths and R/X values
            # for now just make sure the linecode and line values are in consistent units
            # and BEWARE PowerModelsDistribution will scale values from openDSS!
            push!(linelengths, v["length"]) 
        catch e
            @warn("Unable to parse line $(k) when processing OpenDSS model.")
            println(e)
        end
    end

    for k in switches_to_check
        v = d["line"][k]
        try
            # need to connect busses over switch
            b1, b2, phs = get_b1_b2_phs(v)
            if (b1,b2) in edges
                @warn "Not adding switch $k because there is already an edge from $b1 to $b2)"
                continue
            end
            linecode = "switch" * v["name"]
            push!(edges, (b1, b2))
            push!(linecodes, linecode)
            push!(linelengths, get(v, "length", 1.0))
            push!(phases, phs)

            Isquared_up_bounds[linecode] = DEFAULT_AMP_LIMIT^2
            if "normamps" in keys(v) && !(v["normamps"] ≈ 0)  # assuming lowercase keys
                Isquared_up_bounds[linecode] = v["normamps"]^2
            elseif "emergamps" in keys(v) && !(v["emergamps"] ≈ 0)
                Isquared_up_bounds[linecode] = v["emergamps"]^2
            end

            d["linecode"][linecode] = Dict(
                "nphases" => length(phs),
                "rmatrix" => Diagonal(ones(3)) * get(v, "r1", 0.001),
                "xmatrix" => Diagonal(ones(3)) *  get(v, "x1", 0.0),
            )
        catch e
            @warn("Unable to parse switch $(k) when processing OpenDSS model.")
            println(e)
        end
    end

    # make phases_into_bus to infer transformer phases
    phases_into_bus = Dict(k=>v for (k,v) in zip(tails(edges), phases))

    # TODO it is possible to have a transformer -> transformer, which could lead to failed
    # parsing
    transformers_to_try_again = String[]
    trfxs_with_regs = [innerd["transformer"] for (k, innerd) in get(d, "regcontrol", Dict())]
    regulators = Dict()
    for (k,v) in get(d, "transformer", Dict())
        try
            # need to connect busses over transformers
            fill_transformer_vals!(v, Sbase, Vbase)  # need Sbase, Vbase
            b1, b2 = v["bus"], v["bus_2"]

            if !(b1 in tails(edges)) && !(b2 in heads(edges))
                # this transformer does not connect anything so we ignore it
                @warn("Not parsing transformer $k between $b1 and $b2
                    because it does not have an edge in to or out of it.")
                continue
            end

            if b2 == substation_bus
                @warn("Not parsing transformer $k because it regulates the substation_bus $substation_bus")
                continue
            end

            if "phases_list" in keys(v)  # we got the phase(s) from the bus string
                phs = v["phases_list"]
            elseif b1 in tails(edges)
                phs = phases_into_bus[b1]
            else  # might be able to add the transformer after parsing others
                push!(transformers_to_try_again, k)
                continue
            end

            nwindings = v["windings"]
            if nwindings != 2
                @warn("Parsing a $nwindings winding transformer as a 2 winding transformer.")
            end

            R1 = v["%r"] / 100 * v["kv"]^2 * 1000 / v["kva"]
            R2 = v["%r_2"] / 100 * v["kv"]^2 * 1000 / v["kva"]
            R = R1 + R2
            X = (v["xhl"] + v["xlt"] + v["xht"]) / 100 * v["kv"]^2 * 1000 / v["kva"]
            # openDSS Manual says "Always use the kVA base of the first winding for entering impedances. 
            # Impedance values are entered in percent."

            linecode = v["name"]
            push!(edges, (b1, b2))
            push!(linecodes, linecode)
            push!(linelengths, 1.0)
            push!(phases, phs)
            phases_into_bus[b2] = phs

            Isquared_up_bounds[linecode] = DEFAULT_AMP_LIMIT^2

            rmatrix = zeros(3,3)
            xmatrix = zeros(3,3)
            # set the diagaonal values
            for phs1 in phs
                rmatrix[phs1, phs1] = R
                xmatrix[phs1, phs1] = X
            end

            # TODO handle missing r1 or x1
            d["linecode"][linecode] = Dict(
                "nphases" => length(phs),
                "rmatrix" => rmatrix,
                "xmatrix" => xmatrix,
            )
            # TODO parse turn ratios
            if linecode in trfxs_with_regs
                regulators[(b1,b2)] = Dict(:turn_ratio => Dict(ph => 1.0) for ph in phs)
            end

        catch e
            @warn("Unable to parse transformer $(k) when processing OpenDSS model.")
            println(e)
        end
    end

    for k in transformers_to_try_again
        v = d["transformer"][k]
        b1, b2 = v["bus"], v["bus_2"]

        if b1 in tails(edges)
            phs = phases_into_bus[b1]
        else  # should be feeder head transformer but TODO add checks
            if all(length(phz) == 1 for phz in phases)
                phs = [1]
            else
                phs = [1,2,3]
            end
        end
        nwindings = get(v, "windings", 2)
        if nwindings != 2
            @warn("Parsing a $nwindings winding transformer as a 2 winding transformer.")
        end

        R1 = v["%r"] / 100 * v["kv"]^2 * 1000 / v["kva"]
        R2 = v["%r_2"] / 100 * v["kv"]^2 * 1000 / v["kva"]
        R = R1 + R2
        X = (v["xhl"] + v["xlt"] + v["xht"]) / 100 * v["kv"]^2 * 1000 / v["kva"]
        # openDSS Manual says "Always use the kVA base of the first winding for entering impedances. 
        # Impedance values are entered in percent."

        linecode = v["name"]
        push!(edges, (b1, b2))
        push!(linecodes, linecode)
        push!(linelengths, 1.0)
        push!(phases, phs)
        phases_into_bus[b2] = phs

        Isquared_up_bounds[linecode] = DEFAULT_AMP_LIMIT^2

        rmatrix = zeros(3,3)
        xmatrix = zeros(3,3)
        # set the diagaonal values
        for phs1 in phs
            rmatrix[phs1, phs1] = R
            xmatrix[phs1, phs1] = X
        end

        # TODO handle missing r1 or x1
        d["linecode"][linecode] = Dict(
            "nphases" => length(phs),
            "rmatrix" => rmatrix,
            "xmatrix" => xmatrix,
        )
        # TODO parse turn ratios
        if linecode in trfxs_with_regs
            regulators[(b1,b2)] = Dict(:turn_ratio => Dict(ph => 1.0) for ph in phs)
        end
    end

    return edges, linecodes, linelengths, deepcopy(d["linecode"]), phases, Isquared_up_bounds, regulators
end


"""
    dss_loads(d::Dict)

Return the P,Q loads from the dict provided by parse_dss. Indexed on bus (String), phase (integer),
then time (integer)

- TODO other reactive power specifications ?
- TODO handle vectors ("yearly" loads). Does the parse_dss handle redirects to txt files for loads?
- TODO LoadXfmrs.dss in 8500 Node ntwk: all loads are put on phases 1 or 2, 
    but actual MV phase could be 1, 2, or 3 -> have to map load phases through transformers?
"""
function dss_loads(d::Dict)
    P, Q = Dict{String, Dict{Int, Array{Real}}}(), Dict{String, Dict{Int, Array{Real}}}()
    for v in values(d["load"])

        if occursin(".", v["bus1"])
            bus = strip_phases(v["bus1"])
            phases = collect(parse(Int,ph) for ph in split(v["bus1"][findfirst('.', v["bus1"])+1:end], "."))
        else
            bus = v["bus1"]
            phases = [1]
        end
        if !(bus in keys(P))
            P[bus] = Dict{Int, Array{Real}}(phases[1] => [0.0])
            Q[bus] = Dict{Int, Array{Real}}(phases[1] => [0.0])
        end

        # the "phases" value is really nphases (this key is set in PMD)
        if v["phases"] == 1 && get(v, "conn", "") != DELTA  # DELTA is a PMD Enum
            phs = phases[1]
            if phs in keys(P[bus])
                P[bus][phs][1] += v["kw"] * 1000
            else
                P[bus][phs] = [v["kw"] * 1000]
            end
            if "kvar" in keys(v)
                if phs in keys(Q[bus])
                    Q[bus][phs][1] += v["kvar"] * 1000
                else
                    Q[bus][phs] = [v["kvar"] * 1000]
                end
            elseif "pf" in keys(v)
                p = P[bus][phs][1]
                if phs in keys(Q[bus])
                    Q[bus][phs][1] += sqrt( (p/v["pf"])^2 - p^2 )
                else
                    Q[bus][phs] = [sqrt( (p/v["pf"])^2 - p^2 )]
                end
            end
        else  # split the load evenly across phases
            p = v["kw"] / length(phases) * 1000
            
            if "kvar" in keys(v)
                q = v["kvar"] / length(phases) * 1000
            elseif "pf" in keys(v)
                q = sqrt( (p/v["pf"])^2 - p^2 )
            else
                q = 0.0
            end
            for phs in phases
                if phs in keys(P[bus])
                    P[bus][phs][1] += p
                else
                    P[bus][phs] = [p]
                end
                if phs in keys(Q[bus])
                    Q[bus][phs][1] += q
                else
                    Q[bus][phs] = [q]
                end
            end
        end
    end
    return P, Q
end


"""
    pos_seq(z::AbstractArray)

Given a 2x2 or 3x3 matrix, return the positive sequence impedadance
"""
function pos_seq(z::AbstractArray)
    m, n = size(z,1), size(z,2)  # can't use size alone b/c of single phase lines
    if !(m == n)
        throw(@error "Cannot make positive sequence impendance from non-square matrix")
    end
    if m == 1
        return z
    end
    dg = diag(z)
    z_self   = 1/m * sum(dg)
    z_mutual = 1/m * sum(z[i,j] for i=1:m, j=1:n if i > j)
    return [z_self - z_mutual]
end


# """
#     extract_one_phase!(phs::Int, net::Network{MultiPhase}; use_extract_phase_impedance=false)

# Given a certain phase modify the `net` to convert a multiphase system into a single phase system. 
# This is _not_ a positive sequence model as we take only the appropriate diagaonal elements of the 
# r and x matrices for the specified phase.
# """
# function extract_one_phase!(phs::Int, net::Network{MultiPhase}; use_extract_phase_impedance=false)
#     throw(@error "Not implemented. Should we?")
#     # step 1 find the lines that include phs
#     indices_to_remove = Int[]
#     for (i, phase_vec) in enumerate(phases)
#         if !(phs in phase_vec)
#             push!(indices_to_remove, i)
#         end
#     end
    
#     # step 2 delete lines and associated values that do no include phs
#     deleteat!(phases,      indices_to_remove)
#     deleteat!(linecodes,   indices_to_remove)
#     deleteat!(edges,       indices_to_remove)
#     deleteat!(linelengths, indices_to_remove)

#     # step 3 modify the rmatrix, xmatrix values s.t. the rij, xij methods will get the right values
#     # (the SinglePhase rij, xij methods take the first value from the matrices)
#     if !use_extract_phase_impedance   # use traditional positive sequence
#         for d in values(linecodes_dict)
#             d["rmatrix"] = pos_seq(d["rmatrix"])
#             d["xmatrix"] = pos_seq(d["xmatrix"])
#             d["nphases"] = 1
#         end
#     else  # use the extract phase's self impedance rather than the average across phases
#         # NOTE using self impedance only results in WAY too high voltage drop / impedance
#         # this method can result in slightly more accurate voltage drop
#         for (phase_vec, line_code) in zip(phases, linecodes)
#             if length(phase_vec) == 1 || length(linecodes_dict[line_code]["rmatrix"]) == 1 continue end
#             d = linecodes_dict[line_code]
#             # the matrix values can be 2x2 or 3x3, with phases (1,2), (1,3), or (2,3) in 2x2 matrices
#             i = indexin(phs, sort(phase_vec))[1]
#             m,n = size(d["rmatrix"])
#             r_mutual = 1/m * sum(d["rmatrix"][i,j] for i=1:m, j=1:n if i > j)
#             x_mutual = 1/m * sum(d["xmatrix"][i,j] for i=1:m, j=1:n if i > j)
#             d["rmatrix"] = d["rmatrix"][i,i] - r_mutual
#             d["xmatrix"] = d["xmatrix"][i,i] - x_mutual
#             d["nphases"] = 1
#         end
#     end
#     lcs_to_delete = setdiff(keys(linecodes_dict), linecodes)
#     for lc in lcs_to_delete
#         delete!(linecodes_dict, lc)
#     end

#     # pull out one phase from regulators
#     new_regs = Dict()
#     for (b, d) in regulators
#         new_regs[b] = Dict(
#             k => v[phs]
#             for (k,v) in d
#         )
#     end

#     # adjust the phases
#     phases = repeat([[phs]], length(phases))
#     return phases, new_regs
# end


"""
    dsstxt_to_sparse_array(fp::String, first_data_row::Int = 5)

convert a SystemY.txt file from OpenDSS to a julia matrix.
assumes that Y is symmetric.
"""
function dsstxt_to_sparse_array(fp::String, first_data_row::Int = 5)

    rows = Int[]
    cols = Int[]
    real = Float64[]
    imag = Float64[]

    for (i, line) in enumerate(eachline(fp))

        if i < first_data_row continue end
        line = replace(line, " "=>"")  # "[1,1]=50500+j-50500"
        N = length(line)
        if N == 0 continue end

        append!(rows, tryparse(Int64,
                chop(line, head=findfirst("[", line)[end], tail=N-findfirst(",", line)[end]+1)
        ))

        append!(cols, tryparse(Int64,
                chop(line, head=findfirst(",", line)[end], tail=N-findfirst("]", line)[end]+1)
        ))

        append!(real, tryparse(Float64,
                chop(line, head=findfirst("=", line)[end], tail=N-findfirst("+", line)[end]+1)
        ))

        append!(imag, tryparse(Float64,
                chop(line, head=findfirst("j", line)[end], tail=0)
        ))
    end
    return convert(Array{Complex, 2}, Symmetric(sparse(rows, cols, complex.(real, imag)), :L))
end


"""
    function load_yaml(fp::String)

Check input yaml file has required top-level keys:
- network
- conductors

Convert busses to Tuple (comes in as Vector)
"""
function load_yaml(fp::String)
    d = YAML.load_file(fp; dicttype=Dict{Symbol, Any})
    format_input_dict(d)
end


function load_json(fp::String)
    throw("Unimplemented")
end


"""
    function format_input_dict(d::Dict)::Dict

Convert busses from Vector{String} to Tuple{String, String} for all edge types
"""
function format_input_dict(d::Dict)::Dict
    for EdgeType in subtypes(AbstractEdge)
        dkey = Symbol(split(string(EdgeType), ".")[end])  # left-strip "CommonOPF."
        if dkey in keys(d)  # the EdgeType is in the dict
            for sub_dict in d[dkey]  # each edge type specifies a vector of input values
                sub_dict[:busses] = Tuple(string.(sub_dict[:busses]))
            end
        end
    end
    return d
end


function dss_to_Network(dssfilepath::AbstractString)::Network
    
    # OpenDSS changes the working directory, so we need to change it back
    work_dir = pwd()
    OpenDSS.dss("""
        clear
        compile $dssfilepath
    """)
    cd(work_dir)
    
    net_dict = Dict{Symbol, Any}(
        :Network => Dict(
            :substation_bus => opendss_source_bus(),
            # following base values rely on calls in opendss_source_bus
            :Vbase => OpenDSS.Vsources.BasekV() * 1e3,
            # :Sbase => Tranformer value?,
        ),
        :Conductor => opendss_lines(),
    )

    Network(net_dict)
end


function opendss_lines()::Vector{Dict{Symbol, Any}}
    conductor_dicts = Dict{Symbol, Any}[]
    line_number = OpenDSS.Lines.First()
    while line_number > 0
        bus1 = OpenDSS.Lines.Bus1()
        bus2 = OpenDSS.Lines.Bus2()
        # impedance can be defined in several different ways in OpenDSS.
        # We take the phase impedance matrices and let OpenDSS handle all the ways.
        # Note that we have to extract phases from bus names. If no phases are specified then we
        # look at the Nphases and assume that 1 phases means phase 1, 2 phases means phases 1 and 2,
        # in that order for the impedance matrices.

        b1 = strip_phases(bus1)
        b2 = strip_phases(bus2)
        if occursin(".", bus1)
            phases = get_phases(bus1)
        elseif occursin(".", bus2)
            phases = get_phases(bus2)
        else  # no phases in bus names, infer phases from number of phases
            phases = collect(1:OpenDSS.Lines.Phases())
        end

        # The Conductor validator is expecting Vector{Vector{Float64}} for R and X like 
        # :xmatrix => [[1.0179], [0.5017, 1.0478], [0.4236, 0.3849, 1.0348]] 
        # (We could define Conductors directly using the struct but we should use the Network
        # constructor to take advantage of the validation therein.)

        # TODO serialize Network to yaml? s.t. don't have to parse dss every time
        push!(conductor_dicts, Dict(
            :busses => (b1, b2),
            :phases => phases,
            :rmatrix => OpenDSS.Lines.RMatrix(),
            :xmatrix => OpenDSS.Lines.XMatrix(),
            :length => OpenDSS.Lines.Length()
        ))
        
        line_number = OpenDSS.Lines.Next()
    end
    return conductor_dicts
end


"""
    opendss_source_bus()::String

Return the OpenDSS.Vsources.First() -> OpenDSS.Bus.Name
"""
function opendss_source_bus()::String
    OpenDSS.Vsources.First()
    source_bus = OpenDSS.Bus.Name()
    if OpenDSS.Vsources.Count() != 1
        @warn("More than one Vsource specified in OpenDSS model. 
              Using the first value: $source_bus")
    end
    return source_bus
end


# julia> OpenDSS.Transformers.
# AllLossesByType  AllNames         CoreType         Count            First
# Idx              IsDelta          LossesByType     MaxTap           MinTap
# Name             Next             NumTaps          NumWindings      R
# RdcOhms          Rneut            Tap              Wdg              WdgCurrents
# WdgVoltages      XfmrCode         Xhl              Xht              Xlt
# Xneut            eval             include          kV               kVA
# strWdgCurrents

# TODO transformers need to work with rij and xij methods s.t. they work in KVL definitions
function opendss_transformers()
    OpenDSS.Transformers.First()
    OpenDSS.CktElement.BusNames()  # can have phases
    OpenDSS.Transformers.Xhl()  # in percent of kVA of first winding (reactance is between windings)
    OpenDSS.Transformers.R()  # in percent of kVA of _active_ winding
    OpenDSS.Transformers.Wdg(1.0)  # change winding to get individual resistances and kVs
    OpenDSS.Transformers.kV()
    # Next start basic transformer model in CommonOPF, then finish IEEE13 parsing to test LoadFlow,
    # then on to 8500 node test network
end


# TODO regulated_busses(net::Network) to use in KVL definitions
# julia> OpenDSS.RegControls.
# AllNames       CTPrimary      Count          Delay          First          ForwardBand
# ForwardR       ForwardVreg    ForwardX       Idx            IsInverseTime  IsReversible
# MaxTapChange   MonitoredBus   Name           Next           PTRatio        Reset
# ReverseBand    ReverseR       ReverseVreg    ReverseX       TapDelay       TapNumber
# TapWinding     Transformer    VoltageLimit   Winding        eval           include

function opendss_regulators()
    # vreg: Voltage regulator setting, in VOLTS, for the winding being controlled. Multiplying this
    # value times the ptratio should yield the voltage across the WINDING of the controlled
    # transformer. Default is 120.0
    OpenDSS.RegControls.PTRatio() * OpenDSS.RegControls.ForwardVreg()

    # if MonitoredBus is an empty string then use the Transformer to get the regulated bus
    OpenDSS.RegControls.Transformer()
    OpenDSS.RegControls.Winding()
end