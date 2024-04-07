

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
    kron_reduce(M::AbstractMatrix)::Matrix

Given a 4x4 matrix remove the 4th row and column to create a 3x3 matrix.

The new values in the 3x3 are:
```julia
M_new[i,j] = M[i,j] - M[i,4] *  M[4,j] / M[4,4]  
```
where `i` and `j` are in the `Set((1,2,3))`.
"""
function kron_reduce(M::AbstractMatrix)::Matrix
    M_new = zeros(3,3)
    for i = 1:3, j = 1:3
        M_new[i,j] = M[i,j] - M[i,4] *  M[4,j] / M[4,4]
    end
    return M_new
end


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
        solve
    """)
    cd(work_dir)
    Y = OpenDSS.Circuit.SystemY()  # ordered by OpenDSS object definitions
    # Vector{String} w/values like "BUS1.1"
    node_order = [lowercase(s) for s in OpenDSS.Circuit.YNodeOrder()] 
    
    net_dict = Dict{Symbol, Any}(
        :Network => Dict(
            :substation_bus => opendss_source_bus(),
            # following base values rely on calls in opendss_source_bus
            :Vbase => OpenDSS.Vsources.BasekV() * 1e3,
            # :Sbase => Tranformer value?,
        ),
        :Conductor => opendss_lines(),
        :Transformer => opendss_transformers(Y, node_order)
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
        # TODO sort r and x matrices and phases in to numerical order
        push!(conductor_dicts, Dict(
            :busses => (b1, b2),
            :name => OpenDSS.Lines.Name(),
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


"""

Given two bus names, the OpenDSS.Circuit.SystemY(), and the OpenDSS.Circuit.YNodeOrder() return the sub-matrix of Y that correspondes to the bus names sorted in numerical phase order.

!!! note
    The OpenDSS Y matrix is in 1/impedance units (as defined in the OpenDSS model), like 1,000-ft/ohms.

TODO expand matrices to 3x3 with zeros in this method?
"""
function phase_admittance(bus1::String, bus2::String, Y::Matrix{ComplexF64}, node_order::Vector{String})
    y_busses = strip_phases.(node_order)
    b1_indices = findall(x -> x == bus1, y_busses)
    b2_indices = findall(x -> x == bus2, y_busses)
    b1_phases = [phs[1] for phs in get_phases.(node_order[b1_indices])]
    b2_phases = [phs[1] for phs in get_phases.(node_order[b2_indices])]
    # TODO need order of each phase set?
    return Y[b1_indices, b2_indices], union(b1_phases, b2_phases)
end


# TODO transformers need to work with rij and xij methods s.t. they work in KVL definitions
function opendss_transformers(
        Y::Matrix{ComplexF64}, 
        node_order::Vector{String}
    )::Vector{Dict{Symbol, Any}}

    trfx_dicts = Dict{Symbol, Any}[]
    trfx_number = OpenDSS.Transformers.First()
    while trfx_number > 0

        # BusNames can have phases like bname.1.2
        busses = [lowercase(s) for s in OpenDSS.CktElement.BusNames()]
        bus1, bus2 = busses[1], busses[2]
        # num_phases = OpenDSS.CktElement.NumPhases()
        Y_trfx, phases = phase_admittance(bus1, bus2, Y, node_order)
        rmatrix, xmatrix = real(Y_trfx), imag(Y_trfx)

        # TODO can have more than two windings, so change Transformer properties?
        # kvs = Float64[]
        # for wdg_int in 1:Int(OpenDSS.Transformers.NumWindings())
        #     # set the wdg to get individual kVs
        #     OpenDSS.Transformers.Wdg(Float64(wdg_int))
        #     push!(kvs, OpenDSS.Transformers.kV())
        # end
        # rating_kva = OpenDSS.Transformers.kVA()

        push!(trfx_dicts, Dict(
            :busses => (bus1, bus2),
            :name => OpenDSS.Transformers.Name(),
            :phases => phases,
            :rmatrix => rmatrix,
            :xmatrix => xmatrix,
        ))
        trfx_number = OpenDSS.Transformers.Next()
    end

    return trfx_dicts
    
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