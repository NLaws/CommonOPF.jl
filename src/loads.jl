"""
    struct Load <: AbstractBus

A Load input specifier, mapped from YAML, JSON, or manually populated.

The minimum required inputs include several options. All require a `bus` to place the load. For
single phase models provide one of the following sets of values:
- `bus`, `kws1`
- `bus`, `kws1`, `kvars1`
- `bus`, `kws1`, `q_to_p`
- `bus`, `csv` 
where `csv` is a path to a two column CSV file with a single line header like "kws1,kvars1". If only
`bus` and `kws1` are provided then the reactive load will be zero in the power flow model.

For multiphase models any of the single phase options above can be used and the load will be split
evenly across the phases (the `Network.graph` nodes will get attributes for `kws2`, `kvars2`, etc.
as appropriate). Note that bus phases are inferred from the conductors.

For unbalanced multiphase models one must provide one of:
- `bus`, [`kws1`, `kvars1`], [`kws2`, `kvars2`], [`kws3`, `kvars3`] <-- brackets imply optional
  pairs, depending on the phases at the load bus
- `bus`, `csv`
where the `csv` has 2, 4, or 6 columns with a single line header like
"kws1,kvars1,kws2,kvars2,kws3,kvars3" or "kws2,kvars2,kws3,kvars3".


!!! note 
    The `kws` and `kvars` inputs are plural because we always put the loads in vectors, even with
    one timestep. We do this so that the modeling packages that build on CommonOPF do not have to
    account for both scalar values and vector values.

bus, phase, time
"""
@with_kw struct Load <: AbstractBus
    # required values
    bus::String
    # optional values
    kws1::Union{AbstractVector{<:Real}, Missing} = missing
    kvars1::Union{AbstractVector{<:Real}, Missing} = missing
    kws2::Union{AbstractVector{<:Real}, Missing} = missing
    kvars2::Union{AbstractVector{<:Real}, Missing} = missing
    kws3::Union{AbstractVector{<:Real}, Missing} = missing
    kvars3::Union{AbstractVector{<:Real}, Missing} = missing
    q_to_p::Union{Real, Missing} = missing
    csv::Union{String, Missing} = missing
end


function build_loads(d::Dict)::AbstractVector{Load}
    if !(:loads in keys(d))
        return Load[]
    end
    loads = Load[Load(;ld...) for ld in d[:loads]]
    check_loads!(loads)
    return loads
end


function check_loads!(loads::AbstractVector{Load})
    indices_to_delete = Int[]
    for (idx, load) in enumerate(loads)
        if all(ismissing.((
            load.kws1, load.kvars1, 
            load.kws2, load.kvars2, 
            load.kws3, load.kvars3, 
            load.csv,
        )))
            push!(indices_to_delete, idx)
            @warn "Load at bus $(load.bus) does not have enough values to define a multi-phase load.\n"*
            "It has been removed from the model.\n"*
            "See https://nlaws.github.io/CommonOPF.jl/dev/inputs/#Loads for required inputs."
        end
    end
    deleteat!(loads, indices_to_delete)
    nothing
end


function load_from_csv(load::Load)
    throw("NotImplementedError")
end