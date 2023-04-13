module CommonOPF

using LinearAlgebra
import PowerModelsDistribution: parse_dss, DELTA
import Logging: SimpleLogger, Error, with_logger

const SBASE_DEFAULT = 1_000_000
const VBASE_DEFAULT = 12_470
const DEFAULT_AMP_LIMIT = 1000.0

export 
    heads,
    tails,
    dsstxt_to_sparse_array,
    dss_dict_to_arrays,
    dss_loads,
    dss_files_to_dict,
    AbstractInputs,
    Phases,
    SinglePhase,
    MultiPhase,
    Inputs,
    singlephase38linesInputs


include("io.jl")
include("types.jl")
include("inputs.jl")

end
