abstract type AbstractInputs end
abstract type Phases end
abstract type SinglePhase <: Phases end
abstract type MultiPhase <: Phases  end

# time::Int, bus or edge :: String, phase :: Int || (Int, Int)
MultiPhaseVariableContainerType = Dict{Int64, Dict{String, AbstractVecOrMat}}

abstract type AbstractNetwork end
abstract type AbstractEdge end
abstract type AbstractBus end