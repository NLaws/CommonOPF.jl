

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


"""
    get_phases(bus::AbstractString)

If a period occurs in the `bus` string then return a Vector{Int} of the values after the period;
else return `nothing`.
"""
get_phases(bus::AbstractString) = occursin(".", bus) ? 
    sort!(collect(parse(Int,ph) for ph in split(bus[findfirst('.', bus)+1:end], "."))) : 
    nothing


function opendss_regulator_transformers()::Vector{String}
    n = OpenDSS.RegControls.First()
    names = String[]
    while n > 0
        push!(names, 
            OpenDSS.RegControls.Transformer()
        )
        n = OpenDSS.RegControls.Next()
    end
    return names
end


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
    dss_impedance_matrices_to_three_phase(fp::String, first_data_row::Int = 5)

resize OpenDSS matrices to 3x3 and sort values by numerical phase order
"""
function dss_impedance_matrices_to_three_phase(
    dss_rmatrix::AbstractMatrix{Float64}, 
    dss_xmatrix::AbstractMatrix{Float64}, 
    phases::AbstractVector{Int}
    )::Tuple{Matrix{Float64}, Matrix{Float64}}
    r, x = zeros(3,3), zeros(3,3)
    for (i, phs1) in enumerate(phases), (j, phs2) in enumerate(phases)
        r[phs1, phs2] = dss_rmatrix[i, j]
        x[phs1, phs2] = dss_xmatrix[i, j]
    end
    return r, x
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
    opendss_loads(;disable::Bool=true)::Vector{Dict{Symbol, Any}}

Construct a vector of dicts to pass to the `Network` builder for the `Load` structs.
If `disable` then all loads are disabled, which is necessary to exclude the load impedances from the 
OpenDSS SystemY matrix.

!!! note
    Determining OpenDSS phase numbers (not number of phases) is tricky: if the 
    OpenDSS.CktElement.BusNames() do not have the dot-phases, like "671.2.3", then one must find the 
    number of phases (e.g. NPhases = OpenDSS.Loads.Phases()) and then the phases are 1, ..., NPhases.
"""
function opendss_loads(;disable::Bool=true)::Vector{Dict{Symbol, Any}}
    OpenDSS.Circuit.SetActiveClass("Load")  # have to do this to use CktElement stuff
    # we track load busses to merge any multiphase unbalanced loads into one 
    # CommonOPF.Load then at the end just return the vector of dicts.
    loads = Dict{String, Dict{Symbol, Any}}()
    load_number = OpenDSS.Loads.First()
    while load_number > 0
        # how do we get load bus phase numbers?
        bus = OpenDSS.CktElement.BusNames()[1]
        phases = get_phases(bus)
        if isnothing(phases)
            phases = collect(1:OpenDSS.Loads.Phases())
        end

        kw_per_phase = OpenDSS.Loads.kW() / length(phases)
        kvar_per_phase = OpenDSS.Loads.kvar() / length(phases)

        kws1 = 1 in phases ? [kw_per_phase] : missing
        kws2 = 2 in phases ? [kw_per_phase] : missing
        kws3 = 3 in phases ? [kw_per_phase] : missing

        kvars1 = 1 in phases ? [kvar_per_phase] : missing
        kvars2 = 2 in phases ? [kvar_per_phase] : missing
        kvars3 = 3 in phases ? [kvar_per_phase] : missing

        # TODO time-series loads

        bus = strip_phases(bus)
        if !(bus in keys(loads))
            loads[bus] = Dict(
                :bus => bus,
                :kws1 => kws1,
                :kws2 => kws2,
                :kws3 => kws3,
                :kvars1 => kvars1,
                :kvars2 => kvars2,
                :kvars3 => kvars3,
            )
        else  # add to existing bus load (accounting for missing values)
            loads[bus][:kws1] = ismissing(loads[bus][:kws1]) ? kws1 : loads[bus][:kws1] + (
                ismissing(kws1) ? [0.0] : kws1
            )
            loads[bus][:kws2] = ismissing(loads[bus][:kws2]) ? kws2 : loads[bus][:kws2] + (
                ismissing(kws2) ? [0.0] : kws2
            )
            loads[bus][:kws3] = ismissing(loads[bus][:kws3]) ? kws3 : loads[bus][:kws3] + (
                ismissing(kws3) ? [0.0] : kws3
            )

            loads[bus][:kvars1] = ismissing(loads[bus][:kvars1]) ? kvars1 : loads[bus][:kvars1] + (
                ismissing(kvars1) ? [0.0] : kvars1
            )
            loads[bus][:kvars2] = ismissing(loads[bus][:kvars2]) ? kvars2 : loads[bus][:kvars2] + (
                ismissing(kvars2) ? [0.0] : kvars2
            )
            loads[bus][:kvars3] = ismissing(loads[bus][:kvars3]) ? kvars3 : loads[bus][:kvars3] + (
                ismissing(kvars3) ? [0.0] : kvars3
            )
        end

        if disable
            OpenDSS.CktElement.Enabled(false)
        end

        load_number = OpenDSS.Loads.Next()
    end

    return collect(values(loads))
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
    # must disable loads before getting Y s.t. the load impedances are excluded
    load_dicts = opendss_loads(;disable=true)
    OpenDSS.Solution.Solve()
    Y = OpenDSS.Circuit.SystemY()  # ordered by OpenDSS object definitions
    # Vector{String} w/values like "BUS1.1"
    node_order = [lowercase(s) for s in OpenDSS.Circuit.YNodeOrder()]
    num_phases = opendss_circuit_num_phases()
    
    net_dict = Dict{Symbol, Any}(
        :Network => Dict(
            :substation_bus => opendss_source_bus(),
            # following base values rely on calls in opendss_source_bus
            :Vbase => OpenDSS.Vsources.BasekV() * 1e3,
            # :Sbase => Tranformer value?,
        ),
        :Conductor => opendss_lines(num_phases),
        :Load => load_dicts,
        :Transformer => opendss_transformers(num_phases, Y, node_order),
        :VoltageRegulator => opendss_regulators(num_phases, Y, node_order),
    )

    Network(net_dict)
end


"""
    opendss_lines(num_phases::Int)::Vector{Dict{Symbol, Any}}

Parse all OpenDSS.Lines into dictionaries to be used in constructing CommonOPF.Conductor
"""
function opendss_lines(num_phases::Int)::Vector{Dict{Symbol, Any}}
    OpenDSS.Circuit.SetActiveClass("Line")  # have to do this to use CktElement stuff
    conductor_dicts = Dict{Symbol, Any}[]
    line_number = OpenDSS.Lines.First()
    while line_number > 0
        bus1 = OpenDSS.Lines.Bus1()
        bus2 = OpenDSS.Lines.Bus2()
        # impedance can be defined in several different ways in OpenDSS.
        # We take the phase impedance matrices and let OpenDSS handle all the ways.
        
        # NodeOrder is list of node names in the order the nodes appear in the Y matrix.
        phases = OpenDSS.CktElement.NodeOrder()[1:OpenDSS.CktElement.NumPhases()]
        rmatrix, xmatrix = dss_impedance_matrices_to_three_phase(
            OpenDSS.Lines.RMatrix(), OpenDSS.Lines.XMatrix(), phases
        )

        if num_phases == 1
            i = collect(phases)[1]
            push!(conductor_dicts, Dict(
                :busses => (strip_phases(bus1), strip_phases(bus2)),
                :name => OpenDSS.Lines.Name(),
                :phases => phases,
                :r1 => rmatrix[i, i],
                :x1 => xmatrix[i, i],
                :length => OpenDSS.Lines.Length()
            ))
        else
            push!(conductor_dicts, Dict(
                :busses => (strip_phases(bus1), strip_phases(bus2)),
                :name => OpenDSS.Lines.Name(),
                :phases => phases,
                :rmatrix => rmatrix,
                :xmatrix => xmatrix,
                :length => OpenDSS.Lines.Length()
            ))
        end
        
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


function opendss_circuit_num_phases()::Int
    OpenDSS.Vsources.First()
    return OpenDSS.Vsources.Phases()
end


"""
    phase_admittance(bus1::String, bus2::String, Y::Matrix{ComplexF64}, node_order::Vector{String})

Given two bus names, the OpenDSS.Circuit.SystemY(), and the OpenDSS.Circuit.YNodeOrder() return the 
sub-matrix of Y that correspondes to the bus names sorted in numerical phase order.

!!! note
    The OpenDSS Y matrix is in 1/impedance units (as defined in the OpenDSS model), like 1,000-ft/ohms.
"""
function phase_admittance(bus1::String, bus2::String, Y::Matrix{ComplexF64}, node_order::Vector{String})
    y_busses = strip_phases.(node_order)
    b1_indices = findall(x -> x == bus1, y_busses)
    b2_indices = findall(x -> x == bus2, y_busses)
    return Y[b1_indices, b2_indices]
end


"""
    transformer_impedance(Y::Matrix{ComplexF64}, node_order::Vector{String})

Extract the transformer impedance from the "system Y" matrix, removing the turns ratio that OpenDSS
embeds in the admittance values.
"""
function transformer_impedance(Y::Matrix{ComplexF64}, node_order::Vector{String}, bus1::String, bus2::String, phases::AbstractVector{Int})
    # BusNames can have phases like bname.1.2
    # see https://drive.google.com/file/d/1cNc7sFwxUZAuNT3JtUy4vVCeiME0NxJO/view?usp=drive_link
    Y_trfx = phase_admittance(bus1, bus2, Y, node_order)
    kV1, kV2 = 1.0, 1.0
    # have to back-out the tap ratio that OpenDSS embeds in Y
    # except for the source transformer :shrug:
    if bus1 != opendss_source_bus()
        OpenDSS.Transformers.Wdg(1.0) 
        kV1 = OpenDSS.Transformers.kV()
        OpenDSS.Transformers.Wdg(2.0) 
        kV2 = OpenDSS.Transformers.kV()
    end
    # NOTE ignoring off diagonal terms since they cause numerical issues in IEEE13 source transformer
    Z = inv(Diagonal(Y_trfx)) * kV1 / kV2
    r, x = dss_impedance_matrices_to_three_phase(abs.(real(Z)), -1*imag(Z), phases)
    return r, x, kV1, kV2
end


function opendss_transformers(
        num_phases::Int,
        Y::Matrix{ComplexF64}, 
        node_order::Vector{String}
    )::Vector{Dict{Symbol, Any}}
    reg_transformers = opendss_regulator_transformers()
    OpenDSS.Circuit.SetActiveClass("Transformer")  # have to do this to use CktElement stuff
    trfx_dicts = Dict{Symbol, Any}[]
    trfx_number = OpenDSS.Transformers.First()
    while trfx_number > 0
        if OpenDSS.Transformers.Name() in reg_transformers
            trfx_number = OpenDSS.Transformers.Next()
            continue
        end

        bus1, bus2 = [lowercase(s) for s in OpenDSS.CktElement.BusNames()]
        phases = OpenDSS.CktElement.NodeOrder()[1:OpenDSS.CktElement.NumPhases()]
        rmatrix, xmatrix, kV1, kV2 = transformer_impedance(Y, node_order, bus1, bus2, phases)

        if num_phases == 1
            i = collect(phases)[1]
            push!(trfx_dicts, Dict(
                :busses => (bus1, bus2),
                :name => OpenDSS.Transformers.Name(),
                :phases => phases,
                :high_kv => kV1,
                :low_kv => kV2,
                :resistance => rmatrix[i, i],
                :reactance => xmatrix[i, i],
            ))
        else
            push!(trfx_dicts, Dict(
                :busses => (bus1, bus2),
                :name => OpenDSS.Transformers.Name(),
                :phases => phases,
                :high_kv => kV1,
                :low_kv => kV2,
                :rmatrix => rmatrix,
                :xmatrix => xmatrix,
            ))
        end
        
        trfx_number = OpenDSS.Transformers.Next()
    end

    return trfx_dicts
    
end


function opendss_regulators(
    num_phases::Int,
    Y::Matrix{ComplexF64}, 
    node_order::Vector{String},
    )::Vector{Dict{Symbol, Any}}
    # vreg: Voltage regulator setting, in VOLTS, for the winding being controlled. Multiplying this
    # value times the ptratio should yield the voltage across the WINDING of the controlled
    # transformer. Default is 120.0
    reg_dicts = Dict{Tuple{String, String}, Dict{Symbol, Any}}()
    reg_number = OpenDSS.RegControls.First()

    while reg_number > 0
        OpenDSS.Transformers.Name(OpenDSS.RegControls.Transformer())

        OpenDSS.Transformers.Wdg(2.0)  # we want kV of 2nd winding, assuming two windings only
        vreg_pu = round(
            OpenDSS.RegControls.PTRatio() * OpenDSS.RegControls.ForwardVreg() / (
            OpenDSS.Transformers.kV() * 1_000 ), 
        digits=5)

        bus1, bus2 = [lowercase(s) for s in OpenDSS.CktElement.BusNames()]
        phases = OpenDSS.CktElement.NodeOrder()[1:OpenDSS.CktElement.NumPhases()]
        bus1 = strip_phases(bus1)
        bus2 = strip_phases(bus2)
        reg_edge = (bus1, bus2)

        rmatrix, xmatrix, kV1, kV2 = transformer_impedance(Y, node_order, bus1, bus2, phases)
        
        OpenDSS.Transformers.Wdg(1.0)  # we want first winding kVA for impedances
        if !(reg_edge in keys(reg_dicts))
            i = collect(phases)[1]
            if num_phases == 1
                reg_dicts[reg_edge] = Dict(
                    :busses => (bus1, bus2),
                    :name => OpenDSS.RegControls.Name(),
                    :high_kv => kV1,
                    :low_kv => kV2,
                    :phases => phases,
                    :resistance => rmatrix[i, i],
                    :reactance => xmatrix[i, i],
                    :vreg_pu => vreg_pu,
                )
            else
                reg_dicts[reg_edge] = Dict(
                    :busses => (bus1, bus2),
                    :name => OpenDSS.RegControls.Name(),
                    :high_kv => kV1,
                    :low_kv => kV2,
                    :phases => phases,
                    :rmatrix => rmatrix,
                    :xmatrix => xmatrix,
                    :vreg_pu => vreg_pu,
                )
            end
        else
            if !issubset(phases, reg_dicts[reg_edge][:phases])
                # merge into existing regulator
                reg_dicts[reg_edge][:phases] = union(phases, reg_dicts[reg_edge][:phases])
                reg_dicts[reg_edge][:rmatrix] += rmatrix
                reg_dicts[reg_edge][:xmatrix] += xmatrix
            else
                @warn "Not parsing regulator $(OpenDSS.RegControls.Name()) because a regulator already exists between its terminals."
            end
        end

        reg_number = OpenDSS.RegControls.Next()
    end
    return collect(values(reg_dicts))
end


function opendss_capacitors()::Vector{Dict{Symbol, Any}}
    cap_number = OpenDSS.Capacitors.First()
    cap_dicts = Dict{Symbol, Any}[]
    while cap_number > 0

    end
    return cap_dicts
end