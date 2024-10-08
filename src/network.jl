"""
    struct Network <: AbstractNetwork
        graph::MetaGraphsNext.AbstractGraph
        substation_bus::String
        Sbase::Real
        Vbase::Real
        Zbase::Real
        v0::Union{Real, AbstractVecOrMat{<:Number}}
        Ntimesteps::Int
        bounds::VariableBounds
        var_names::AbstractVector{Symbol}
    end

The `Network` model is used to store all the inputs required to create power flow and optimal power
flow models. Underlying the Network model is a `MetaGraphsNext.MetaGraph` that stores the edge and
node data in the network. 

We leverage the `AbstractNetwork` type to make an intuitive interface for the Network model. For
example, `edges(network)` returns an iterator of edge tuples with bus name values; (but if we used
`Graphs.edges(MetaGraph)` we would get an iterator of Graphs.SimpleGraphs.SimpleEdge with integer
values).

A Network can be created directly, via a `Dict`, or a filepath. The minimum inputs must have a
vector of [Conductor](@ref) specifications and a `Network` key containing at least the
`substation_bus`. See [Input Formats](@ref) for more details.

`var_names` is empty be default. It is used in the results getters like `opf_results`.
"""
mutable struct Network{T<:Phases} <: AbstractNetwork
    graph::MetaGraphsNext.AbstractGraph
    substation_bus::String
    Sbase::Real
    Vbase::Real
    Zbase::Real
    v0::Union{Real, AbstractVecOrMat{<:Number}}
    Ntimesteps::Int
    bounds::VariableBounds
    var_names::AbstractVector{Symbol}
end


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
        Vector{Symbol}()
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

# make it so Network[(bus1, bus2)] returns the edge struct
Base.getindex(net::Network, idx::Tuple{String, String}) = net.graph[idx[1], idx[2]]


function Base.setindex!(net::Network, edge::CommonOPF.AbstractEdge, idx::Tuple{String, String}) 
    net.graph[idx[1], idx[2]] = edge
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


edges(net::AbstractNetwork) = collect(MetaGraphsNext.edge_labels(net.graph))


Graphs.inneighbors(net::Network, bus::String) = MetaGraphsNext.inneighbor_labels(net.graph, bus)
Graphs.outneighbors(net::Network, bus::String) = MetaGraphsNext.outneighbor_labels(net.graph, bus)


function phases_into_bus(net::Network, bus::String)::Vector{Int64}
    phase_set = Set{Int64}()
    for in_bus in inneighbors(net, bus)
        union!(phase_set, net[(in_bus, bus)].phases)
    end
    return sort(collect(phase_set))
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


load_busses(net::AbstractNetwork) = collect(b for b in busses(net) if haskey(net[b], :Load))


voltage_regulator_edges(net::AbstractNetwork) = collect(e for e in edges(net) if isa(net[e], VoltageRegulator))
# TODO account for reverse flow voltage regulation?


real_load_busses(net::Network{SinglePhase}) = collect(b for b in load_busses(net) if !ismissing(net[b][:Load].kws1))
real_load_busses(net::Network{MultiPhase}) = collect(
    b for b in load_busses(net) 
    if !ismissing(net[b][:Load].kws1) || !ismissing(net[b][:Load].kws2) || !ismissing(net[b][:Load].kws3)
)


reactive_load_busses(net::Network{SinglePhase}) = collect(b for b in load_busses(net) if !ismissing(net[b][:Load].kvars1))
reactive_load_busses(net::Network{MultiPhase}) = collect(
    b for b in load_busses(net) 
        if !ismissing(net[b][:Load].kvars1) || !ismissing(net[b][:Load].kvars2) || !ismissing(net[b][:Load].kvars3)
)

total_load_kw(net::Network{SinglePhase}) = sum(net[load_bus][:Load].kws1 for load_bus in real_load_busses(net))
total_load_kvar(net::Network{SinglePhase}) = sum(net[load_bus][:Load].kvars1 for load_bus in real_load_busses(net))


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


conductors(net::AbstractNetwork) = collect(
    net[ekey] for ekey in edges(net) if net[ekey] isa CommonOPF.Conductor
)


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
        if !isempty( get(g[node.bus], Symbol(type), []) )
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
        @warn "Missing templates: $missing_templates"
        return false
    end
    return true
end


function is_connected(net::Network)::Bool
    length(Graphs.weakly_connected_components(net.graph)) == 1
    # TODO undirected graphs, strongly_connected_components
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


function Network_Papavasiliou_2018()
    fp = joinpath(dirname(@__FILE__), 
        "..", "test", "data", "yaml_inputs", "Papavasiliou_2018_with_shunts.yaml"
    )
    return Network(fp)
end