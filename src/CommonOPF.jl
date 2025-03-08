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
import DataStructures: DefaultDict

const SBASE_DEFAULT = 1
const VBASE_DEFAULT = 1
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

export 
    dsstxt_to_sparse_array,
    Phases,
    SinglePhase,
    MultiPhase,
    MultiPhaseVariableContainerType,
    check_paths_for_loads,
    info_max_rpu_xpu,

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

    # impedance and admittance
    rij,
    rij_per_unit,
    xij,
    xij_per_unit,
    zij,
    zij_per_unit,
    gij,
    gij_per_unit,
    bij,
    bij_per_unit,
    yij,
    yij_per_unit,
    yj,
    Yij_per_unit,
    Yij,

    # io
    dss_to_Network,

    # network reduction
    reduce_tree!,
    remove_bus!,
    trim_tree!,
    trim_tree_once!,
    combine_parallel_lines!,
    trim_above_bus!,

    # attributes of the Network
    edges,
    busses,
    connected_busses,
    generator_busses,
    leaf_busses,
    phases_into_bus,
    phases_out_of_bus,
    phases_connected_to_bus,
    i_to_j,
    j_to_k,
    kron_reduce,

    info_max_Ppu_Qpu,
    get_variable_values,
    Network,
    conductors,
    conductors_with_attribute_value,
    voltage_regulator_edges,
    is_connected,

    # loads
    load_busses,
    real_load_busses,
    reactive_load_busses,
    total_load_kw,
    total_load_kvar,
    sj,
    sj_per_unit,
    power_injection_vector_pu,
    
    # test Networks
    Network_IEEE13_SinglePhase,
    Network_Papavasiliou_2018,

    # variables
    VARIABLE_NAMES,
    multiphase_bus_variable_container,
    multiphase_edge_variable_container,
    add_time_vector_variables!,
    add_complex_vector_of_phase_variable!,
    opf_results,

    # decomposition
    split_network,
    splitting_busses,
    split_at_busses,
    init_split_networks!,
    connect_subgraphs_at_busses,

    # model building support
    cj,
    substation_voltage,
    phi_ij,
    matrix_phases_to_vec



include("models/bounds.jl")
include("types.jl")
include("graphs.jl")

include("busses/busses.jl")
include("busses/capacitors.jl")
include("busses/loads.jl")
include("busses/generators.jl")

include("edges/edges.jl")
include("edges/conductors.jl")
include("edges/transformers.jl")
include("edges/voltage_regulators.jl")

include("io.jl")

include("network.jl")
include("edges/impedances.jl")
include("edges/admittances.jl")
include("busses/shunt_admittances.jl")
include("network_reduction.jl")
include("decomposition.jl")

include("models/construction_utils.jl")
include("models/variables.jl")
include("models/results.jl")
include("opendss.jl")


end
