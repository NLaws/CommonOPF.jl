"""
    mutable struct Inputs{T<:Phases} <: AbstractInputs
        edges::Array{Tuple, 1}
        linecodes::Array{String, 1}
        linelengths::Array{Float64, 1}
        busses::Array{String}
        phases::Vector{Vector}
        substation_bus::String
        Pload::Dict{String, Any}
        Qload::Dict{String, Any}
        Sbase::Real
        Vbase::Real
        Ibase::Real
        Zdict::Dict{String, Dict{String, Any}}
        v0::Real
        v_lolim::Real
        v_uplim::Real
        Zbase::Real
        Ntimesteps::Int
        pf::Float64
        Nnodes::Int
        P_up_bound::Float64
        Q_up_bound::Float64
        P_lo_bound::Float64
        Q_lo_bound::Float64
        Isquared_up_bounds::Dict{String, <:Real}
        phases_into_bus::Dict{String, Vector{Int}}
        relaxed::Bool
        edge_keys::Vector{String}
        regulators::Dict
    end

Inputs
- `edges` Vector{Tuple} e.g. `[("0", "1"), ("1", "2")]`
- `linecodes` vector of string keys for the Zdict (impedance values for lines). When using an OpenDSS model a `linecode` is the `name` in `New linecode.name`
- `linelengths` vector of floats to scale impedance values
- `busses` vector of bus names
- `phases` vector of vectors with ints for the line phases (e.g. `[[1,2,3], [1,3], ...]`)
- `Pload` dict with `busses` for keys and uncontrolled real power loads (positive is load) by phase and time
- `Qload` dict with `busses` for keys and uncontrolled reactive power loads (positive is load) by phase and time
- `Sbase` base apparent power for network, typ. feeder capacity. Used to normalize all powers in model
- `Vbase` base voltage for network, used to determine `Zbase = Vbase^2 / Sbase`
- `Ibase` = `Sbase / (Vbase * sqrt(3))`
- `Zdict` dict with `linecodes` for keys and subdicts with "xmatrix" and "zmatrix" keys with per unit length values. Values are divided by `Zbase` and multiplied by linelength in mathematical model.
- `v0` slack bus reference voltage

TODO Zdict example

TODO test against simple model to make sure scaling is done right

!!! note
    The `edges`, `linecodes`, `phases`, `edge_keys`, and `linelengths` are in mutual order (i.e. the i-th value in each list corresponds to the same line)

"""
mutable struct Inputs{T<:Phases} <: AbstractInputs
    edges::Array{Tuple, 1}
    linecodes::Array{String, 1}
    linelengths::Array{Float64, 1}
    busses::Array{String}
    phases::Vector{Vector}
    substation_bus::String
    Pload::Dict{String, Any}
    Qload::Dict{String, Any}
    Sbase::Real
    Vbase::Real
    Ibase::Real
    Zdict::Dict{String, Dict{String, Any}}
    v0::Union{Real, AbstractVecOrMat{<:Number}}  # TODO MultiPhase v0 
    v_lolim::Real
    v_uplim::Real
    Zbase::Real
    Ntimesteps::Int
    pf::Float64
    Nnodes::Int
    P_up_bound::Float64
    Q_up_bound::Float64
    P_lo_bound::Float64
    Q_lo_bound::Float64
    Isquared_up_bounds::Dict{String, <:Real}  # index on ij_edges = [string(i*"-"*j) for j in p.busses for i in i_to_j(j, p)]
    phases_into_bus::Dict{String, Vector{Int}}
    relaxed::Bool
    edge_keys::Vector{String}
    regulators::Dict
end
# TODO line flow limits


"""
    Inputs(
        edges::Array{Tuple}, 
        linecodes::Array{String}, 
        linelengths::Array{Float64}, 
        phases::Vector{Vector},
        substation_bus::String;
        Pload, 
        Qload, 
        Sbase=1, 
        Vbase=1, 
        Zdict, 
        v0, 
        v_lolim=0.95, 
        v_uplim=1.05,
        Ntimesteps=1, 
        P_up_bound=1e4,
        Q_up_bound=1e4,
        P_lo_bound=-1e4,
        Q_lo_bound=-1e4,
        Isquared_up_bounds=Dict{String, Float64}(),
        relaxed=true
    )

Lowest level Inputs constructor (the only one that returns the Inputs struct). 

!!! note
    The real and reactive loads provided are normalized using `Sbase`.
"""
function Inputs(
        edges::AbstractVector{<:Tuple}, 
        linecodes::AbstractVector{<:AbstractString}, 
        linelengths::AbstractVector{<:Real}, 
        phases::AbstractVector{<:AbstractVector},
        substation_bus::String;
        Pload, 
        Qload, 
        Sbase=1, 
        Vbase=1, 
        Zdict, 
        v0, 
        v_lolim=0.95, 
        v_uplim=1.05,
        Ntimesteps=1, 
        P_up_bound=1e4,
        Q_up_bound=1e4,
        P_lo_bound=-1e4,
        Q_lo_bound=-1e4,
        Isquared_up_bounds=Dict{String, Float64}(),
        relaxed=true,
        regulators=Dict()
    )

    Ibase = Sbase / (Vbase * sqrt(3))
    # Ibase^2 should be used to recover amperage from lij ?
    Zbase = Vbase^2 / Sbase

    busses = busses_from_edges(edges)

    if isempty(Isquared_up_bounds)
        Isquared_up_bounds = Dict(l => DEFAULT_AMP_LIMIT^2 for l in linecodes)
    end

    if v_lolim < 0 @error("lower voltage limit v_lolim cannot be less than zero") end
    if v_uplim < 0 @error("upper voltage limit v_uplim cannot be less than zero") end

    receiving_busses = collect(e[2] for e in edges)
    phases_into_bus = Dict(k=>v for (k,v) in zip(receiving_busses, phases))

    input_type = SinglePhase
    if any(get(v, "nphases", 1) > 1 for v in values(Zdict))
        input_type = MultiPhase
    end

    edge_keys = [string(i*"-"*j) for (i,j) in edges]

    Inputs{input_type}(
        edges,
        linecodes,
        linelengths,
        busses,
        phases,
        substation_bus,
        Pload,
        Qload,
        Sbase,
        Vbase,
        Ibase,
        Zdict,
        v0,
        v_lolim, 
        v_uplim,
        Zbase,
        Ntimesteps,
        0.1,  # power factor
        length(busses),  # Nnodes
        P_up_bound,
        Q_up_bound,
        P_lo_bound,
        Q_lo_bound,
        Isquared_up_bounds,
        phases_into_bus,
        relaxed,
        edge_keys,
        regulators
    )
end


"""
    Inputs(
        dssfilepath::String, 
        substation_bus::String;
        Pload::AbstractDict=Dict(), 
        Qload::AbstractDict=Dict(), 
        Sbase=1, 
        Vbase=1, 
        v0, 
        v_lolim=0.95, 
        v_uplim=1.05,
        Ntimesteps=1, 
        P_up_bound=1e4,
        Q_up_bound=1e4,
        P_lo_bound=-1e4,
        Q_lo_bound=-1e4,
        relaxed=true,
        extract_phase::Int=0  # set to 1, 2, or 3
    )

Inputs constructor that parses a openDSS file for the network. If `Pload` and `Qload` are not provided
then the loads are also parsed from the openDSS file.

If `extract_phase` is set to 1, 2, 3 then the loads for that phase are put into `Pload` and `Qload`
and the impedance values are set to the positive sequence impedance for each line. Note that single
phase lines and two phase lines do not have positive sequence definitions but single phase lines only
have one impedance value anyway and for two phase lines we use 
z_mutual = z12 and z_self = 1/2(z11 + z22).
"""
function Inputs(
        dssfilepath::String, 
        substation_bus::String;
        Pload::AbstractDict=Dict(), 
        Qload::AbstractDict=Dict(), 
        Sbase=1.0, 
        Vbase=1.0, 
        v0=1.0, 
        v_lolim=0.95, 
        v_uplim=1.05,
        Ntimesteps=1, 
        P_up_bound=1e4,
        Q_up_bound=1e4,
        P_lo_bound=-1e4,
        Q_lo_bound=-1e4,
        relaxed=true,
        extract_phase::Int=0,  # set to 1, 2, or 3,
        use_extract_phase_impedance::Bool=false,
        enforce_tree::Bool=true,
        trim_above_substation_bus::Bool=true
    )

    d = dss_files_to_dict(dssfilepath)

    edges, linecodes, linelengths, linecodes_dict, phases, Isquared_up_bounds, regulators = 
        dss_dict_to_arrays(d, Sbase, Vbase, substation_bus; enforce_tree=enforce_tree)

    if extract_phase in [1,2,3]
        phases = extract_one_phase!(extract_phase, edges, linecodes, linelengths, phases, linecodes_dict; 
            use_extract_phase_impedance=use_extract_phase_impedance
        )
    end

    if isempty(Pload) && isempty(Qload)
        Pload, Qload = dss_loads(d)
        # hack for single phase models
        if all(length(phs) == 1 for phs in phases)
            # strip phase index out of loads
            phs = extract_phase == 0 ? 1 : extract_phase  # default to phs 1, else extract_phase
            newP = Dict{String, Any}()
            for (b,v) in Pload
                if phs in keys(v)
                    newP[b] = v[phs]
                end
            end
            Pload = newP
            newQ = Dict{String, Any}()
            for (b,v) in Qload
                if phs in keys(v)
                    newQ[b] = v[phs]
                end
            end
            Qload = newQ
        end
    end

    if trim_above_substation_bus
        g = make_graph(edges)
        busses_to_delete = all_inneighbors(g, substation_bus, Vector{String}())
        edges_to_delete = [e for e in edges if e[1] in busses_to_delete]
        indices_to_delete = Int[]
        for e in edges_to_delete
            push!(indices_to_delete, indexin([e], edges)[1])
        end
        deleteat!(edges, indices_to_delete)
        deleteat!(phases, indices_to_delete)
        deleteat!(linecodes, indices_to_delete)
        deleteat!(linelengths, indices_to_delete)
    end

    # TODO line limits from OpenDSS ?

    Inputs(
        edges,
        linecodes,
        linelengths,
        phases,
        substation_bus;
        Pload=Pload, 
        Qload=Qload,
        Sbase=Sbase, 
        Vbase=Vbase, 
        Zdict=linecodes_dict, 
        v0=v0,
        v_lolim = v_lolim, 
        v_uplim = v_uplim, 
        Ntimesteps=Ntimesteps,
        P_up_bound=P_up_bound,
        Q_up_bound=Q_up_bound,
        P_lo_bound=P_lo_bound,
        Q_lo_bound=Q_lo_bound,
        Isquared_up_bounds=Isquared_up_bounds,
        relaxed=relaxed,
        regulators=regulators
    )
end


function info_max_Ppu_Qpu(p::Inputs)
    maxP = maximum(maximum.(values(p.Pload))) / p.Sbase
    maxQ = maximum(maximum.(values(p.Qload))) / p.Sbase
    @info("Max. Ppu: $maxP   Max Qpu: $maxQ")
    return maxP, maxQ
end


"""
    singlephase38linesInputs(;
        Pload=Dict{String, AbstractArray{Real, 1}}(), 
        Qload=Dict{String, AbstractArray{Real, 1}}(), 
        T=24,
        loadnodes = ["3", "5", "36", "9", "10", "11", "12", "13", "15", "17", "18", "19", "22", "25", 
                    "27", "28", "30", "31", "32", "33", "34", "35"],
        Sbase = 1e6,
        Vbase = 12.5e3,
        v0=1.0,
        v_uplim = 1.05,
        v_lolim = 0.95,
    )

Convenience function for creating a single phase network with 38 lines and nodes. 
Taken from:
Andrianesis et al. 2019 "Locational Marginal Value of Distributed Energy Resources as Non-Wires Alternatives"

NOTE that Inputs is a mutable struct (s.t. loads can be added later).
"""
function singlephase38linesInputs(;
        Pload=Dict{String, AbstractArray{Real, 1}}(), 
        Qload=Dict{String, AbstractArray{Real, 1}}(), 
        T=24,
        loadnodes = ["3", "5", "36", "9", "10", "11", "12", "13", "15", "17", "18", "19", "22", "25", 
                    "27", "28", "30", "31", "32", "33", "34", "35"],
        Sbase = 1e6,
        Vbase = 12.5e3,
        v0=1.0,
        v_uplim = 1.05,
        v_lolim = 0.95,
    )

    if isempty(Pload)  # fill in default loadnodes
        Pload = Dict(k => Real[] for k in loadnodes)
    end
    if isempty(Qload)  # fill in default loadnodes
        Qload = Dict(k => Real[] for k in loadnodes)
    end

    Inputs(
        joinpath(dirname(@__FILE__), "..", "test", "data", "singlephase38lines", "master.dss"), 
        "0";
        Pload=Pload, 
        Qload=Qload,
        Sbase=Sbase, 
        Vbase=Vbase, 
        v0 = v0,
        v_uplim = v_uplim,
        v_lolim = v_lolim,
        Ntimesteps = T
    )
end
