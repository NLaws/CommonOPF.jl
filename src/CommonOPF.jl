module CommonOPF

using LinearAlgebra
using JuMP
import Graphs, MetaGraphsNext
import MetaGraphsNext: inneighbors, outneighbors, induced_subgraph, delete!
import Logging: SimpleLogger, Error, with_logger
import YAML
import Parameters: @with_kw
import InteractiveUtils: subtypes
import OpenDSSDirect as OpenDSS

const SBASE_DEFAULT = 1_000_000
const VBASE_DEFAULT = 12_470
const DEFAULT_AMP_LIMIT = 1000.0
const VARIABLE_NAMES = String[
    "net_real_power_injection",
    "net_reactive_power_injection",
    "sending_end_real_power_flow",
    "sending_end_reactive_power_flow",
    "voltage_magnitude",
    "voltage_magnitude_squared",
    "voltage_angle",
    "current_magnitude",
    "current_magnitude_squared",
]
VariableContainer = Dict{String, Dict{Int, Any}}  # edge/bus String, time step Int, variable(s)

export 
    heads,
    tails,
    dsstxt_to_sparse_array,
    Phases,
    SinglePhase,
    MultiPhase,
    MultiPhaseVariableContainerType,
    check_paths_for_loads,
    info_max_rpu_xpu,
    info_max_Ppu_Qpu,

    # graphs
    make_graph,
    outneighbors,
    all_outneighbors,
    inneighbors,
    all_inneighbors,
    induced_subgraph,
    busses_from_deepest_to_source,
    vertices_from_deepest_to_source,
    busses_with_multiple_inneighbors,
    next_bus_above_with_outdegree_more_than_one,
    paths_between,

    # impedance
    resistance,
    resistance_per_length,
    rij,
    rij_per_unit,
    reactance,
    reactance_per_length,
    xij,
    xij_per_unit,
    zij,

    # io
    dss_to_Network,

    # network reduction
    reduce_tree!,
    remove_bus!,
    trim_tree!,
    trim_tree_once!,
    combine_parallel_lines!,
    trim_above_bus!,

    i_to_j,
    j_to_k,

    info_max_Ppu_Qpu,
    leaf_busses,
    get_variable_values,
    Network,
    edges,
    busses,
    conductors,
    conductors_with_attribute_value,
    load_busses,
    voltage_regulator_edges,
    is_connected,
    real_load_busses,
    reactive_load_busses,
    # test Networks
    Network_IEEE13_SinglePhase,
    Network_Papavasiliou_2018,
    VARIABLE_NAMES,
    VariableContainer,
    add_time_vector_variables!,

    # decomposition
    split_network


include("types.jl")
include("graphs.jl")
include("io.jl")

include("busses/busses.jl")
include("busses/loads.jl")
include("busses/shunts.jl")

include("edges/edges.jl")
include("edges/conductors.jl")
include("edges/transformers.jl")
include("edges/voltage_regulators.jl")

include("network.jl")
include("edges/impedances.jl")  # Network type in signatures, move the struct to types?
include("network_reduction.jl")
include("decomposition.jl")

include("utils.jl")
include("variables.jl")
include("results.jl")


end
