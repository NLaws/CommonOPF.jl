abstract type Phases end
abstract type SinglePhase <: Phases end
abstract type MultiPhase <: Phases  end

# time::Int, bus or edge :: String, phase :: Int || (Int, Int)
MultiPhaseVariableContainerType = Dict{Int64, Dict{String, AbstractVecOrMat}}

abstract type AbstractNetwork end
abstract type AbstractEdge end
abstract type AbstractBus end

# used to return zero admittance and infinite impedance for missing edges
abstract type MissingEdge end


"""
    VarUnits

Units acceptable for CommonOPF variables.
"""
@enum VarUnits begin
    AmpUnit
    VoltUnit
    TimeUnit
    RealPowerUnit
    ReactivePowerUnit
    ApparentPowerUnit
end


"""
    VarDimension

Dimensions for specifying variable indexes in CommonOPF variables.
"""
@enum VarDimensions begin
    BusDimension
    EdgeDimension
    TimeDimension
    PhaseDimension
end


"""
    VarInfo

Variable information for describing variables in sub-modules of CommonOPF
"""
struct VarInfo
    symbol::Symbol
    description::String
    units::VarUnits
    dimensions::Tuple{Vararg{VarDimensions}}
end


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
    v0::Union{Number, AbstractVecOrMat{<:Number}}
    Ntimesteps::Int
    bounds::VariableBounds
    var_names::AbstractVector{Symbol}
    var_info::Dict{Symbol, VarInfo}
end