# the Network struct is defined in types.jl so that we can use it in function signatures throughout
# the src code (by including types.jl first in the module).


network_phase_type(net::Network{T}) where {T} = T


"""
    function Network(g::MetaGraphsNext.AbstractGraph, ntwk::Dict) 

Given a MetaGraph create a Network by extracting the edges and busses from the MetaGraph
"""
function Network(g::MetaGraphsNext.AbstractGraph, ntwk::Dict, net_type::Type) 
    # TODO MultiPhase based on inputs
    Sbase = get(ntwk, :Sbase, SBASE_DEFAULT)
    Vbase = get(ntwk, :Vbase, VBASE_DEFAULT)
    Zbase = get(ntwk, :Zbase, Vbase^2 / Sbase)
    v0 = get(ntwk, :v0, 1)
    Ntimesteps = get(ntwk, :Ntimesteps, 1)
    bounds = VariableBounds(ntwk)
    Network{net_type}(
        g,
        string(ntwk[:substation_bus]),
        Sbase,
        Vbase,
        Zbase,
        v0,
        Ntimesteps,
        bounds,
        Vector{Symbol}(),
        Dict{Symbol, VariableInfo}(),
        Dict{Symbol, ConstraintInfo}(),
    )
end


REQUIRED_EDGES = [CommonOPF.Conductor]


"""
    function Network(d::Dict; directed::Union{Bool,Missing}=missing)

Construct a `Network` from a dictionary that has at least keys for:
1. `:Conductor`, a vector of dicts with [Conductor](@ref) specs
2. `:Network`, a dict with at least `:substation_bus`

If `directed` is missing then the graph is directed only if the number of busses and edges imply a 
    radial graph.

"""
function Network(d::Dict; directed::Union{Bool,Missing}=missing)
    edge_structs = CommonOPF.AbstractEdge[]
    for EdgeType in subtypes(CommonOPF.AbstractEdge)
        dkey = Symbol(split(string(EdgeType), ".")[end])  # left-strip CommonOPF.
        if dkey in keys(d)
            edge_structs = vcat(edge_structs, CommonOPF.build_edges(d[dkey], EdgeType))
        elseif EdgeType in REQUIRED_EDGES
            throw(error("Missing required input $(string(dkey))"))
        end
    end
    # merge any duplicate conductor edges into ParallelConductor structs
    tmp = Dict{Tuple{String,String}, Any}()
    new_edges = CommonOPF.AbstractEdge[]
    for e in edge_structs
        if e isa CommonOPF.Conductor
            if haskey(tmp, e.busses)
                existing = tmp[e.busses]
                if existing isa CommonOPF.ParallelConductor
                    push!(existing.conductors, e)
                    existing.phases = isempty([c.phases for c in existing.conductors if !ismissing(c.phases)]) ? missing :
                        sort(unique(reduce(vcat, [c.phases for c in existing.conductors if !ismissing(c.phases)])))
                    existing.length = mean(c.length for c in existing.conductors)
                elseif existing isa CommonOPF.Conductor
                    tmp[e.busses] = CommonOPF.ParallelConductor([existing, e])
                end
            else
                tmp[e.busses] = e
            end
        else
            push!(new_edges, e)
        end
    end
    append!(new_edges, values(tmp))
    edge_structs = new_edges
    # Single vs. MultiPhase is determined by edge.phases
    net_type = CommonOPF.SinglePhase
    if any((!ismissing(e.phases) for e in edge_structs))
        net_phases = phases_union(edge_structs)
        if length(net_phases) > 1
            net_type = CommonOPF.MultiPhase
        end
    end
    bus_vec = CommonOPF.AbstractBus[]
    for BusType in subtypes(CommonOPF.AbstractBus)
        dkey = Symbol(split(string(BusType), ".")[end])   # left-strip CommonOPF.
        if dkey in keys(d)
            bus_vec = vcat(bus_vec, build_busses(d[dkey], BusType))
        end
    end

    # make the graph
    g = make_graph(edge_structs; directed=directed)
    if length(bus_vec) > 0
        fill_node_attributes!(g, bus_vec)
    end
    return Network(g, d[:Network], net_type)
end


"""
    function Network(fp::String)

Construct a `Network` from a yaml at the file path `fp`.
"""
function Network(fp::String)
    # parse inputs
    if endswith(lowercase(fp), ".yaml") ||  endswith(lowercase(fp), ".yml")
        d = load_yaml(fp)
    elseif endswith(lowercase(fp), ".dss")
        return CommonOPF.dss_to_Network(fp)
    else
        # TODO json
        throw(error("Only parsing yaml (or yml) and dss files so far."))
    end
    Network(d)
end


"""
    Base.getindex(net::Network, idx::Tuple{String, String}) 

make it so `Network[(bus1, bus2)]` and `Network[(bus2, bus1)]` return the edge struct
"""
function Base.getindex(net::Network, idx::Tuple{String, String}) 
    try 
        return net.graph[idx[1], idx[2]] 
    catch KeyError
        # let it ride
    end
    try
        return net.graph[idx[2], idx[1]]
    catch KeyError
        # let it ride
    end
    return MissingEdge
end


"""
    Base.setindex!(net::Network, edge::CommonOPF.AbstractEdge, idx::Tuple{String, String})

make it so `Network[(bus1, bus2)] = edge` sets `Network.graph[bus1, bus2] = edge`
"""
function Base.setindex!(net::Network, edge::CommonOPF.AbstractEdge, idx::Tuple{String, String})
    b1, b2 = idx
    try
        existing = net.graph[b1, b2]
        if existing isa ParallelConductor && edge isa Conductor
            push!(existing.conductors, edge)
            existing.phases = isempty([c.phases for c in existing.conductors if !ismissing(c.phases)]) ? missing :
                sort(unique(reduce(vcat, [c.phases for c in existing.conductors if !ismissing(c.phases)])))
            existing.length = mean(c.length for c in existing.conductors)
        elseif existing isa Conductor && edge isa Conductor
            net.graph[b1, b2] = ParallelConductor([existing, edge])
        else
            net.graph[b1, b2] = edge
        end
    catch e
        if e isa KeyError
            net.graph[b1, b2] = edge
        else
            rethrow(e)
        end
    end
end


# make it so Network[node_string] returns the bus struct
Base.getindex(net::Network, idx::String) = net.graph[idx]


"""
    function Base.getindex(net::Network, bus::String, kws_kvars::Symbol, phase::Int)

Load getter for `Network`. Use like:
```julia
net["busname", :kws, 2]

net["busname", :kvars, 3]
```
The second argument must be one of `:kws` or `:kvars`. The third arbument must be one of `[1,2,3]`.
If the `"busname"` exists and has a `:Load` dict, but the load (e.g. `:kvars2`) is not defined then
`zeros(net.Ntimesteps)` is returned.
"""
function Base.getindex(net::Network, bus::String, kws_kvars::Symbol, phase::Int)
    load_key = Symbol(kws_kvars, Symbol(phase))
    if !(load_key in LOAD_KEYS)
        throw(KeyError("To get a Load use :kws or :kvars and a phase in [1,2,3]"))
    end
    # make sure that there is a bus and Load
    try
        net[bus][:Load]
    catch e
        # if the key error is from the bus or :Load we throw it
        if typeof(e) == KeyError 
            if e.key == :Load
                throw(KeyError("There is no Load at bus $bus"))
            elseif e.key == bus
                throw(KeyError("There is no bus in the Network at $bus"))
            end
        else
            rethrow(e)
        end
    end
    if ismissing(getproperty(net[bus][:Load], load_key))
        return zeros(net.Ntimesteps)
    end
    return getproperty(net[bus][:Load], load_key)
end


"""
    edges(net::AbstractNetwork)

returns a vector of the edge indices in the network
"""
edges(net::AbstractNetwork) = collect(MetaGraphsNext.edge_labels(net.graph))


Graphs.inneighbors(net::Network, bus::String) = MetaGraphsNext.inneighbor_labels(net.graph, bus)
Graphs.outneighbors(net::Network, bus::String) = MetaGraphsNext.outneighbor_labels(net.graph, bus)


"""
    phases_into_bus(net::Network, bus::String)::Vector{Int64}

All the phases on the edges found via `inneighbors(net, bus)`.
"""
function phases_into_bus(net::Network, bus::String)::Vector{Int64}
    phase_set = Set{Int64}()
    for in_bus in inneighbors(net, bus)
        union!(phase_set, net[(in_bus, bus)].phases)
    end
    return sort(collect(phase_set))
end


"""
    phases_out_of_bus(net::Network, bus::String)::Vector{Int64}

All the phases on the edges found via `outneighbors(net, bus)`.
"""
function phases_out_of_bus(net::Network, bus::String)::Vector{Int64}
    phase_set = Set{Int64}()
    for out_bus in outneighbors(net, bus)
        union!(phase_set, net[(bus, out_bus)].phases)
    end
    return sort(collect(phase_set))
end


"""
    phases_connected_to_bus(net::Network, bus::String)::Vector{Int64}

Union of `phases_into_bus` and `phases_out_of_bus`.
"""
function phases_connected_to_bus(net::Network, bus::String)::Vector{Int64}
    sort(union(
        phases_into_bus(net, bus), phases_out_of_bus(net, bus)
    ))
end


"""
    i_to_j(j::String, net::Network)

all the inneighbors of bus j
"""
i_to_j(j::String, net::Network) = collect(inneighbors(net::Network, j::String))


"""
    j_to_k(j::String, net::Network)

all the outneighbors of bus j
"""
j_to_k(j::String, net::Network) = collect(outneighbors(net::Network, j::String))


busses(net::AbstractNetwork) = collect(MetaGraphsNext.labels(net.graph))


voltage_regulator_edges(net::AbstractNetwork) = collect(e for e in edges(net) if isa(net[e], VoltageRegulator))
# TODO account for reverse flow voltage regulation?



"""
    leaf_busses(net::Network)

returns `Vector{String}` containing all of the leaf busses in `net.graph`
"""
function leaf_busses(net::Network)
    leafs = String[]
    for j in busses(net)
        if !isempty(i_to_j(j, net)) && isempty(j_to_k(j, net))
            push!(leafs, j)
        end
    end
    return leafs
end


conductors(net::AbstractNetwork) = collect(Iterators.flatten(
    net[ekey] isa CommonOPF.ParallelConductor ? net[ekey].conductors :
        (net[ekey] isa CommonOPF.Conductor ? [net[ekey]] : [])
    for ekey in edges(net)
))


function conductors_with_attribute_value(net::AbstractNetwork, attr::Symbol, val::Any)::AbstractVector{CommonOPF.Conductor}
    collect(
        filter(
            c -> !ismissing(getproperty(c, attr)) && getproperty(c, attr) == val,
            collect(conductors(net))
        )
    )
end


"""
    fill_node_attributes!(g::MetaGraphsNext.AbstractGraph, vals::AbstractVector{<:AbstractBus})

For each concrete bus in `vals` store the concrete bus in the graph at `concrete_bus.node`.
"""
function fill_node_attributes!(g::MetaGraphsNext.AbstractGraph, vals::AbstractVector{<:AbstractBus})
    for node in vals
        if !(node.bus in MetaGraphsNext.labels(g))
            @warn "Bus $(node.bus) is not in the graph after adding edges but has attributes:\n"*
                "$node\n"*
                "You will have to manually add bus $(node.bus) if you want it in the graph."
            continue
        end
        type = split(string(typeof(node)), ".")[end]  # e.g. "CommonOPF.Load" -> "Load"
        if haskey(g[node.bus], Symbol(type))
            @warn "Replacing existing attributes $(g[node.bus][Symbol(type)]) in node $(node.bus)"
        end
        g[node.bus][Symbol(type)] = node
    end
end


function check_missing_templates(net::Network) 
    conds = collect(conductors(net))
    missing_templates = String[]
    for c in conds
        if !ismissing(c.template)
            results = filter(con -> !ismissing(con.name) && con.name == c.template, conds)
            if length(results) == 0
                push!(missing_templates, c.template)
            end
        end
    end
    if length(missing_templates) > 0
        @warn "Missing conductor templates: $missing_templates"
        return false
    end
    return true
end


function is_connected(net::Network)::Bool
    length(Graphs.weakly_connected_components(net.graph)) == 1
    # TODO undirected graphs, strongly_connected_components, phases
end


##############################################################################
##############################################################################
##############################################################################
# some test networks for use in BranchFlowModel.jl, etc.

function Network_IEEE13_SinglePhase()
    fp = joinpath(dirname(@__FILE__), 
        "..", "test", "data", "yaml_inputs", "ieee13_single_phase.yaml"
    )
    return Network(fp)
end


function Network_IEEE13()
    fp = joinpath(dirname(@__FILE__), 
        "..", "test", "data", "yaml_inputs", "ieee13_multi_phase.yaml"
    )
    return Network(fp)
end


function Network_IEEE8500()
    fp = joinpath(dirname(@__FILE__), 
        "..", "test", "data", "ieee8500", "Master-no-secondaries.dss"
    )
    return Network(fp)
end


function Network_Papavasiliou_2018()
    fp = joinpath(dirname(@__FILE__), 
        "..", "test", "data", "yaml_inputs", "Papavasiliou_2018_with_shunts.yaml"
    )
    return Network(fp)
end