

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


"""
    dss_to_Network(dssfilepath::AbstractString)::Network

Using a OpenDSS command to compile the `dssfilepath` we load in the data from .dss files and parse
the data into a `Network` model.
"""
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