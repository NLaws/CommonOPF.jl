"""
    @with_kw mutable struct Load <: AbstractBus

A Load input specifier, mapped from YAML, JSON, or manually populated.

The minimum required inputs include several options. All require a `bus` to place the load. For
single phase models provide one of the following sets of values:
- `bus`, `kws1`
- `bus`, `kws1`, `kvars1`
- `bus`, `kws1`, `q_to_p`
- `bus`, `csv` 
where `csv` is a path to a two column CSV file with a single line header like "kws1,kvars1". If only
`bus` and `kws1` are provided then the reactive load will be zero in the power flow model.

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

Once the `net::Network` is defined a load can be accessed like:
```julia
ld_busses = collect(load_busses(net))
lb = ld_busses[1]  # bus keys are strings in the network
net[lb, :kws, 1]  # last index is phase integer
```
"""
@with_kw mutable struct Load <: AbstractBus
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


LOAD_KEYS = [:kws1, :kvars1, :kws2, :kvars2, :kws3, :kvars3]


"""
    check_busses!(loads::AbstractVector{Load})

Remove (and warn about it) if any Load have no way to define the loads
"""
function check_busses!(loads::AbstractVector{Load})
    indices_to_delete = Int[]
    for (idx, load) in enumerate(loads)
        fill_load!(load)
        if all(ismissing.((
            load.kws1, load.kvars1, 
            load.kws2, load.kvars2, 
            load.kws3, load.kvars3, 
            load.csv,
        )))
            push!(indices_to_delete, idx)
            @warn "Load at bus $(load.bus) does not have enough values to define a load.\n"*
            "It has been removed from the model.\n"*
            "See https://nlaws.github.io/CommonOPF.jl/dev/inputs/#Loads for required inputs."
        end
    end
    # TODO check all time-series have same lengths
    # TODO how to check Load inputs for single phase vs multiphase? Need to no phase b/c a bus could 
        # have a load on only phase 1, 2, or 3 or some combination of them.
    deleteat!(loads, indices_to_delete)
    nothing
end


"""

Rules:
1. If `q_to_p` is defined and a `kwsN` value is defined then we fill the `kvarN` value, where ``N
   \\in {1,2,3}``.
2. 
"""
function fill_load!(load::Load)
    if ismissing(load.q_to_p) return end

    if !ismissing(load.kws1) && ismissing(load.kvars1)
        load.kvars1 = load.kws1 .* load.q_to_p
    end

    if !ismissing(load.kws2) && ismissing(load.kvars2)
        load.kvars2 = load.kws2 .* load.q_to_p
    end

    if !ismissing(load.kws3) && ismissing(load.kvars3)
        load.kvars3 = load.kws3 .* load.q_to_p
    end
    nothing
end


function load_from_csv(load::Load)
    throw("NotImplementedError")
end


load_busses(net::AbstractNetwork) = collect(b for b in busses(net) if haskey(net[b], :Load))


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
    sj(j::String, net::Network{SinglePhase})::AbstractVector{ComplexF64}

Return the complex power injections (negative of load) at bus `j` in kW / kVaR. 
"""
function sj(j::String, net::Network{SinglePhase})::AbstractVector{ComplexF64}
    pj, qj = [0.0], [0.0]
    if j in real_load_busses(net)
        pj = -net[j][:Load].kws1
    end
    if j in reactive_load_busses(net)
        qj = -net[j][:Load].kvars1
    end
    return pj + im * qj
end


"""
    sj_per_unit(j::String, net::Network{SinglePhase})::AbstractVector{ComplexF64}

Return the complex power injections (negative of load) at bus `j` per-unit power.
"""
function sj_per_unit(j::String, net::Network{SinglePhase})::AbstractVector{ComplexF64}
    return sj(j, net) * 1e3 / net.Sbase
end
