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
    @enum VarUnits begin
        AmpUnit
        VoltUnit
        TimeUnit
        ApparentPowerUnit
        ComplexPowerUnit
        ReactivePowerUnit
        RealPowerUnit
    end

Units acceptable for CommonOPF variables.
"""
@enum VarUnits begin
    AmpUnit
    VoltUnit
    TimeUnit
    ApparentPowerUnit
    ComplexPowerUnit
    ReactivePowerUnit
    RealPowerUnit
end


"""
    @enum VarDimensions begin
        BusDimension
        EdgeDimension
        TimeDimension
        PhaseDimension
    end

Dimensions for specifying variable indexes in CommonOPF variables.
"""
@enum VarDimensions begin
    BusDimension
    EdgeDimension
    TimeDimension
    PhaseDimension
end


"""
    struct VarInfo
        symbol::Symbol
        description::String
        units::VarUnits
        dimensions::Tuple{Vararg{VarDimensions}}
    end

Variable information for describing variables in sub-modules of CommonOPF.
See also [`VarUnits`](@ref), [`VarDimensions`](@ref), and [`print_var_info`](@ref).
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
        var_info::Dict{Symbol, VarInfo}
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

`var_info` is empty be default. It is used in other packages like BranchFlowModel.jl to document the
variables that are created for OPF models. See [`VarInfo`](@ref) for more.
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