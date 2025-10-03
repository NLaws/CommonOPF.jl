

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
    dss_impedance_matrices_to_three_phase(
        dss_rmatrix::AbstractMatrix{Float64},
        dss_xmatrix::AbstractMatrix{Float64},
        dss_cmatrix::AbstractMatrix{Float64}, 
        phases::AbstractVector{Int}
    )::Tuple{Matrix{Float64}, Matrix{Float64}, Matrix{Float64}}

resize OpenDSS matrices to 3x3 and sort values by numerical phase order. Can also be used to slice
out phases of OpenDSS matrices 
"""
function dss_impedance_matrices_to_three_phase(
        dss_rmatrix::AbstractMatrix{Float64},
        dss_xmatrix::AbstractMatrix{Float64},
        dss_cmatrix::AbstractMatrix{Float64}, 
        phases::AbstractVector{Int}
    )::Tuple{Matrix{Float64}, Matrix{Float64}, Matrix{Float64}}

    if size(dss_rmatrix, 1) != size(dss_rmatrix, 2)
        throw(@error "Got non-square R matrix: $dss_rmatrix")
    end

    if size(dss_xmatrix, 1) != size(dss_xmatrix, 2)
        throw(@error "Got non-square X matrix: $dss_xmatrix")
    end

    if size(dss_cmatrix, 1) != size(dss_cmatrix, 2)
        throw(@error "Got non-square C matrix: $dss_cmatrix")
    end

    # OpenDSS impedance matrices are sized according to the number of phases in a power delivery
    # element. So something with phases 1 and 2 or 1 and 3 have a 2x2 matrix. We assume that the
    # phases are sorted according to the phases in the impedance matrices.
    r, x, c = zeros(3,3), zeros(3,3), zeros(3,3)
    if size(dss_rmatrix, 1) == length(phases)
        for (i, phs1) in enumerate(phases), (j, phs2) in enumerate(phases)
            r[phs1, phs2] = dss_rmatrix[i, j]
            x[phs1, phs2] = dss_xmatrix[i, j]
            c[phs1, phs2] = dss_cmatrix[i, j]
        end
    # in the following case, we extract 1 or 2 phases from a larger impedance matrix.
    # this case arises when something is modeled by phase in the OpenDSS files in order to control
    # it by phase (e.g. capacitor or regulator).
    elseif maximum(phases) <= size(dss_rmatrix, 1)
        for phs1 in phases, phs2 in phases
            r[phs1, phs2] = dss_rmatrix[phs1, phs2]
            x[phs1, phs2] = dss_xmatrix[phs1, phs2]
            c[phs1, phs2] = dss_cmatrix[phs1, phs2]
        end
    else
        throw(@error "Got phases $phases with $(size(dss_rmatrix)) rmatrix . Unclear which values to take.")
    end

    return r, x, c
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
    dss_to_Network(dssfilepath::AbstractString; allow_parallel_conductor::Bool=false)::Network

Using a OpenDSS command to compile `dssfilepath` we load in the data from `.dss`
files and parse the data into a [`Network`](@ref). Set
`allow_parallel_conductor=true` to merge duplicate lines between the same pair of
busses.
"""
function dss_to_Network(dssfilepath::AbstractString; allow_parallel_conductor::Bool=false)::Network
    # OpenDSS changes the working directory, so we need to change it back
    work_dir = pwd()
    OpenDSS.dss("""
        clear
        compile $dssfilepath
    """)
    cd(work_dir)
    # must disable loads before getting Y s.t. the load impedances are excluded
    load_dicts = opendss_loads(;disable=true)
    OpenDSS.Solution.MaxControlIterations(50)
    OpenDSS.Solution.Solve()
    Y = OpenDSS.Circuit.SystemY()  # ordered by OpenDSS object definitions
    # Vector{String} w/values like "BUS1.1"
    node_order = [lowercase(s) for s in OpenDSS.Circuit.YNodeOrder()]
    num_phases = opendss_circuit_num_phases()
    
    conductors = opendss_lines(num_phases)
    net_dict = Dict{Symbol, Any}(
        :Network => Dict(
            :substation_bus => opendss_source_bus(),
            # following base values rely on calls in opendss_source_bus
            :Vbase => OpenDSS.Vsources.BasekV() * 1e3,
            # :Sbase => Tranformer value?,
        ),
        :Capacitor => opendss_capacitors(),
        :Conductor => conductors,
        :Load => load_dicts,
        :Transformer => opendss_transformers(num_phases, Y, node_order),
        :VoltageRegulator => opendss_regulators(num_phases, Y, node_order),
        :ShuntAdmittance => opendss_shunts(num_phases, conductors)
    )
    # TODO set v0 from OpenDSS solution with loads (after confirming that the resulting loads are
    # equal to the inputs, i.e. the load model=1 for constant power and the vmin/maxpu values were
    # not violated, which causes the load model to change in OpenDSS)

    Network(net_dict; allow_parallel_conductor=allow_parallel_conductor)
end




"""
    merge_single_phase_lines_between_shared_busses!()

For various reasons (usually to enable some control by phase like CapControl) an OpenDSS model will
include line definitions that share busses but are defined for each phase between the busses. The
CommonOPF.Network model does not allow multiple edges between busses. So we merge these lines from
OpenDSS into a single Conductor.
"""
function merge_single_phase_lines_between_shared_busses!(conductor_dicts::Vector{Dict{Symbol, Any}})

    function _can_merge(edges::Vector)::Bool
        # check if the basic rules for merging more than one conductor dict apply:
        # 1. no overlapping phases
        # 2. lengths are all the same (TODO could rescale impedance to merge)
        # 3. r, x, and c matrices are populated
        seen_phases = Set{Int}()
        for e in edges
            for p in e[:phases]
                if p in seen_phases
                    return false  # Found a duplicate phase
                end
                push!(seen_phases, p)
            end
            if ismissing(e[:rmatrix]) || ismissing(e[:xmatrix]) || ismissing(e[:cmatrix])
                return false
            end
        end

        length_1 = edges[1][:length]
        for e in edges[2:end]
            if !(e[:length] ≈ length_1)
                return false
            end
        end

        return true  # No duplicates found
    end

    function _merge_conductor_dicts(conds::Vector{Dict})::Dict
        return Dict(
            :busses => conds[1][:busses],
            :name => join([get(d, :name, "") for d in conds], "-"),
            :phases => vcat([d[:phases] for d in conds]...),
            :rmatrix => sum(d[:rmatrix] for d in conds),
            :xmatrix => sum(d[:xmatrix] for d in conds),
            :cmatrix => sum(d[:cmatrix] for d in conds),
            :length => conds[1][:length]
        )
    end
    
    # make a map of conductors that share busses like (bus1, bus2) => [cond_dict1, cond_dict2, ...]
    busses_to_conds = Dict{Tuple{String, String}, Vector{Dict}}()
    for d in conductor_dicts
        push!(get!(busses_to_conds, d[:busses], []), d)
    end
    # Filter out entries where the busses are not shared
    filter!(kv -> length(kv[2]) > 1, busses_to_conds)

    # NEXT confirm that each group of conductors don't share phases, merge them into one conductor,
    # and delete the original conductors from the conductor_dicts -> need to know indices in
    # conductor_dicts
    to_remove = Set{UInt64}()
    for (busses, conds) in busses_to_conds
        if !(_can_merge(conds))
            @warn "Cannot merge conductors between busses $busses."
            continue
        end
        push!(to_remove, objectid.(conds)...)
        push!(conductor_dicts, _merge_conductor_dicts(conds))
        @info "Successully merged conductors between $busses"
    end
    # TODO need to merge single phase capacitors in IEEE 8500 

    # Remove merged dicts from the original list
    filter!(d -> objectid(d) ∉ to_remove, conductor_dicts)
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
        rmatrix, xmatrix, cmatrix = dss_impedance_matrices_to_three_phase(
            OpenDSS.Lines.RMatrix(), OpenDSS.Lines.XMatrix(), OpenDSS.Lines.CMatrix(), phases
        )
        # TODO cmatrix into ShuntAdmittance? cmatrix is line capacitive susceptance -> divide it by
        # 2 to get bus shunt susceptance.

        if num_phases == 1
            i = collect(phases)[1]
            push!(conductor_dicts, Dict(
                :busses => (strip_phases(bus1), strip_phases(bus2)),
                :name => OpenDSS.Lines.Name(),
                :phases => phases,
                :r1 => rmatrix[i, i],
                :x1 => xmatrix[i, i],
                :c1 => cmatrix[i, i],
                :length => OpenDSS.Lines.Length()
            ))
        else
            push!(conductor_dicts, Dict(
                :busses => (strip_phases(bus1), strip_phases(bus2)),
                :name => OpenDSS.Lines.Name(),
                :phases => phases,
                :rmatrix => rmatrix,
                :xmatrix => xmatrix,
                :cmatrix => cmatrix,
                :length => OpenDSS.Lines.Length()
            ))
        end
        
        line_number = OpenDSS.Lines.Next()
    end
    merge_single_phase_lines_between_shared_busses!(conductor_dicts)
    return conductor_dicts
end


"""

Parse the line cmatrix values into shunt susceptance values (placing )
"""
function opendss_shunts(num_phases::Int, conductors::Vector{Dict{Symbol, Any}})::Vector{Dict{Symbol, Any}}
    # for now using the line into the bus to get the shunt susceptance (not clear if we should
    # average together the other line susceptances that are connected to the bus)
    shunt_dicts = Dict{Symbol, Any}[]
    f = 2π*60 * 1e-9  # nanofarads to siemens
    for c in conductors
        in_bus = c[:busses][1]
        bus = c[:busses][2]

        if num_phases == 1
            push!(shunt_dicts, Dict(
                :bus => bus,
                :b => ismissing(c[:c1]) ? 0.0 : c[:c1] * c[:length] / 2 * f
            ))
        else
            push!(shunt_dicts, Dict(
                :bus => bus,
                :bmatrix => ismissing(c[:cmatrix]) ? zeros(3,3) : c[:cmatrix] * c[:length] / 2 * f
            ))
        end

        # hack in source bus shunt admittance
        if in_bus == opendss_source_bus()
            if num_phases == 1
                push!(shunt_dicts, Dict(
                    :bus => in_bus,
                    :b => ismissing(c[:c1]) ? 0.0 : c[:c1] * c[:length] / 2 * f
                ))
            else
                push!(shunt_dicts, Dict(
                    :bus => in_bus,
                    :bmatrix => ismissing(c[:cmatrix]) ? zeros(3,3) : c[:cmatrix] * c[:length] / 2 * f
                ))
            end
        end
        
    end
    
    
    return shunt_dicts
end


"""
    opendss_source_bus()::String

Return the OpenDSS.Vsources.First() -> OpenDSS.Bus.Name
"""
function opendss_source_bus()::String
    OpenDSS.Circuit.SetActiveClass("VSource")
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
sub-matrix of Y that corresponds to the bus names sorted in numerical phase order.

!!! note
    The OpenDSS Y matrix is in 1/impedance units (as defined in the OpenDSS model), like 1,000-ft/ohms.
"""
function phase_admittance(bus1::String, bus2::String, Y::Matrix{ComplexF64}, node_order::Vector{String})
    if bus1 == bus2
        throw(@error("Cannot extract phase admittance from bus admittance matrix for the same busses: $bus1"))
    end
    y_busses = strip_phases.(node_order)
    b1_indices = findall(x -> x == bus1, y_busses)
    b2_indices = findall(x -> x == bus2, y_busses)
    # -1 b/c off-diagonal Y values equal -y_ij
    return -1 * Y[b1_indices, b2_indices]
end


"""
    transformer_impedance(
        Y::Matrix{ComplexF64}, 
        node_order::Vector{String}, 
        bus1::String, 
        bus2::String, 
        phases::AbstractVector{Int},
    )

Extract the transformer impedance from the "system Y" matrix, removing the turns ratio that OpenDSS
embeds in the admittance values.
"""
function transformer_impedance(
        Y::Matrix{ComplexF64}, 
        node_order::Vector{String}, 
        bus1::String, 
        bus2::String, 
        phases::AbstractVector{Int},
    )
    # see https://drive.google.com/file/d/1cNc7sFwxUZAuNT3JtUy4vVCeiME0NxJO/view?usp=drive_link
    # for modeling transformers in OpenDSS
    Y_trfx = phase_admittance(bus1, bus2, Y, node_order)
    # Y_trfx has all phases at busses (even if a trfx is defined as single phase i.e. length(phases)
    # is 1)
    kV1, kV2 = 1.0, 1.0
    # have to back-out the tap ratio that OpenDSS embeds in Y
    # except for the source transformer :shrug:
    if bus1 != opendss_source_bus()
        OpenDSS.Transformers.Wdg(1.0) 
        kV1 = OpenDSS.Transformers.kV()
        OpenDSS.Transformers.Wdg(2.0) 
        kV2 = OpenDSS.Transformers.kV()
    end
    # NOTE ignoring off diagonal terms since they cause numerical issues in IEEE13 source
    # transformer
    # NOTE split phase (single phase) transformers have 1x2 impedance matrices and can have
    # arbitrary low side phase like bus1=highbus.3 and bus2=lowbus.1.2 (with 2 wdgs on lowbus). A
    # 1x2 impedance matrix does not fit in the CommonOPF paradigm because the number of phases out
    # of the bus are greater than the number of phases into the bus (like a phase is created).
    Z = inverse_matrix_with_zeros(Diagonal(Y_trfx)) * kV1 / kV2
    r, x, _ = dss_impedance_matrices_to_three_phase(real(Z), imag(Z), zeros(3,3), phases)
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
        bus1, bus2 = strip_phases(bus1), strip_phases(bus2)
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
                reg_dicts[reg_edge][:phases] = sort(union(phases, reg_dicts[reg_edge][:phases]))
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


"""
    opendss_capacitors()::Vector{Dict{Symbol, Any}}

Parse OpenDSS.Capacitors into dicts to be used for constructing `CommonOPF.Capacitor`s
"""
function opendss_capacitors()::Vector{Dict{Symbol, Any}}
    # TODO track CapControls.Capacitor to determine which Capacitors are fixed or not
    cap_number = OpenDSS.Capacitors.First()
    # we track busses to merge any single phase capacitors that share a bus into one capacitor
    # then at the end just return the vector of dicts.
    caps = Dict{String, Dict{Symbol, Any}}()
    while cap_number > 0
        bus1, bus2 = [lowercase(s) for s in OpenDSS.CktElement.BusNames()]
        phases = OpenDSS.CktElement.NodeOrder()[1:OpenDSS.CktElement.NumPhases()]
        bus1 = strip_phases(bus1)
        bus2 = strip_phases(bus2)
        per_phase_kvar = OpenDSS.Capacitors.kvar() / length(phases)

        if !(bus1 == bus2)
            @warn "Series capacitors are not modeled. Found one between busses $bus1 and $bus2"
            cap_number = OpenDSS.Capacitors.Next()
            continue
        end

        if !(bus1 in keys(caps))
            caps[bus1] = Dict(
                :bus => bus1,
                :kvar1 => 1 in phases ? per_phase_kvar : 0.0,
                :kvar2 => 2 in phases ? per_phase_kvar : 0.0,
                :kvar3 => 3 in phases ? per_phase_kvar : 0.0,
            )
        else  # merge into existing capacitor
            caps[bus1][:kvar1] += 1 in phases ? per_phase_kvar : 0.0
            caps[bus1][:kvar2] += 2 in phases ? per_phase_kvar : 0.0
            caps[bus1][:kvar3] += 3 in phases ? per_phase_kvar : 0.0
        end
        cap_number = OpenDSS.Capacitors.Next()
    end
    return collect(values(caps))
end


"""

A hack to get the 8500 node system to work for OPF by moving all the load objects to the high sides
of the secondary transformers. The output is a .dss file that defines all the loads with each their kv
and bus values changed so that the .dss file can be used in forming an OpenDSS model without the
split phase transformers. (The split phase transformers are problematic to translate to
CommonOPF format because the effectively create a new phase accounting system on the secondary
side.)

The task is accomplished by:
    1. for each load
    2. find the load bus
    3. find the line connected to that bus (a triplex in the 8500 node system)
    4. find the other bus that the line is connected to
    5. find the transformer at that bus
    6. find the high side bus of the transformer
    7. write out the load with the high side bus of the transformer and primary kv value.

There are lots of assumptions in this method related to the 8500 node system so it is unlikely that
this method will work for other OpenDSS models. Note that we use the balanced model so that we don't
have to account for the phases on the secondary side of the transformers.
"""
function _move_secondary_loads_to_primary_side_of_transformers(load_file_name::String="moved_loads.dss")


    function _get_load_values()::Tuple{Dict, String}
        return Dict(
            :name => OpenDSS.Loads.Name(),
            :kw => OpenDSS.Loads.kW(),
            :pf => OpenDSS.Loads.PF(),
        ),  OpenDSS.CktElement.BusNames()[1]
    end


    function _find_transformer(bus::String)::Tuple{String, Vector{Integer}, Integer}
        OpenDSS.Circuit.SetActiveBus(bus)
        triplex_line = OpenDSS.Bus.AllPDEatBus()[1]
        OpenDSS.Circuit.SetActiveElement(triplex_line)
        line_busses = OpenDSS.CktElement.BusNames()
        trfx_low_bus = first(setdiff(Set(line_busses), Set([bus])))
        OpenDSS.Circuit.SetActiveBus(trfx_low_bus)
        pdes = OpenDSS.Bus.AllPDEatBus()
        trfx = pdes[findfirst(x -> startswith(x, "Transformer"),  pdes)]
        # remove "Transformer."
        trfx = last(trfx, length(trfx) - length("Transformer."))
        OpenDSS.Transformers.Name(trfx)
        # have to strip phases to get the high bus
        trfx_busses = strip_phases.(OpenDSS.CktElement.BusNames())
        trfx_high_bus = first(setdiff(Set(trfx_busses), Set([strip_phases(trfx_low_bus)])))
        nphases = OpenDSS.CktElement.NumPhases()
        # but we need the phases for defining the load, yarg
        return trfx_high_bus, OpenDSS.CktElement.NodeOrder()[1:nphases], nphases
    end


    function _update_trfxs_dict!(d::Dict, trfx_bus::String, phases::Vector{Integer}, nphases::Integer, load_dict::Dict)
        # note that only the first load name found on the transformer will be used
        if !(trfx_bus in keys(d))
            d[trfx_bus] = load_dict
            d[trfx_bus][:nphases] = nphases
            d[trfx_bus][:bus] = trfx_bus
            d[trfx_bus][:phases] = phases
        else
            d[trfx_bus][:kw] += load_dict[:kw]
            d[trfx_bus][:nphases] += nphases
            union!(d[trfx_bus][:phases], phases)
        end
    end

    transformer_loads = Dict()

    OpenDSS.Loads.First()
    load_dict, bus = _get_load_values()
    trfx_high_bus, phases, nphases = _find_transformer(bus)
    _update_trfxs_dict!(transformer_loads, trfx_high_bus, phases, nphases, load_dict)

    while OpenDSS.Loads.Next() > 0
        load_dict, bus = _get_load_values()
        trfx_high_bus, phases, nphases = _find_transformer(bus)
        _update_trfxs_dict!(transformer_loads, trfx_high_bus, phases, nphases, load_dict)
    end

    io = open(load_file_name, "w")
  
    for d in values(transformer_loads)
        kv = 12.47
        if d[:nphases] == 1
            kv = 7.2
        end
        write(io,
            "New Load.$(d[:name]) phases=$(d[:nphases]) Bus1=$(d[:bus] * "." * join(d[:phases], ".")) kv=$kv model=1 conn=wye kW=$(d[:kw]) pf=$(d[:pf]) Vminpu=.88\n"
        )
    end

    close(io)

end