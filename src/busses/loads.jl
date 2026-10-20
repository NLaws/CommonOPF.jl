"""
    @with_kw mutable struct Load <: AbstractBus

A Load input specifier, mapped from YAML, JSON, or manually populated.

The minimum required inputs include several options. All require a `bus` to place the load. For
single phase models provide one of the following sets of values:
- `bus`, `p1`
- `bus`, `p1`, `q1`
- `bus`, `p1`, `q_to_p`
- `bus`, `csv` 
where `csv` is a path to a two column CSV file with a single line header like "p1,q1". If only
`bus` and `p1` are provided then the reactive load will be zero in the power flow model.

For unbalanced multiphase models one must provide one of:
- `bus`, [`p1`, `q1`], [`p2`, `q2`], [`p3`, `q3`] <-- brackets imply optional
  pairs, depending on the phases at the load bus
- `bus`, `csv`
where the `csv` has 2, 4, or 6 columns with a single line header like
"p1,q1,p2,q2,p3,q3" or "p2,q2,p3,q3".

!!! note 
    We always put the loads in vectors, even with one timestep. We do this so that the modeling
    packages that build on CommonOPF do not have to account for both scalar values and vector
    values.

Once the `net::Network` is defined a load can be accessed like:
```julia
ld_busses = collect(load_busses(net))
lb = ld_busses[1]  # bus keys are strings in the network
net[lb, :p, 1]  # last index is phase integer
```
"""
@with_kw mutable struct Load <: AbstractBus
    # required values
    bus::String
    # optional values
    p1::Union{AbstractVector{<:Real}, Missing} = missing
    q1::Union{AbstractVector{<:Real}, Missing} = missing
    p2::Union{AbstractVector{<:Real}, Missing} = missing
    q2::Union{AbstractVector{<:Real}, Missing} = missing
    p3::Union{AbstractVector{<:Real}, Missing} = missing
    q3::Union{AbstractVector{<:Real}, Missing} = missing
    q_to_p::Union{Real, Missing} = missing
    csv::Union{String, Missing} = missing
end


LOAD_KEYS = [:p1, :q1, :p2, :q2, :p3, :q3]


"""
    check_busses!(loads::AbstractVector{Load})

Remove (and warn about it) if any Load have no way to define the loads
"""
function check_busses!(loads::AbstractVector{Load})
    indices_to_delete = Int[]
    for (idx, load) in enumerate(loads)
        fill_load!(load)
        if all(ismissing.((
            load.p1, load.q1, 
            load.p2, load.q2, 
            load.p3, load.q3, 
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
1. If `q_to_p` is defined and a `pN` value is defined then we fill the `qN` value, where ``N
   \\in {1,2,3}``.
2. 
"""
function fill_load!(load::Load)
    if ismissing(load.q_to_p) return end

    if !ismissing(load.p1) && ismissing(load.q1)
        load.q1 = load.p1 .* load.q_to_p
    end

    if !ismissing(load.p2) && ismissing(load.q2)
        load.q2 = load.p2 .* load.q_to_p
    end

    if !ismissing(load.p3) && ismissing(load.q3)
        load.q3 = load.p3 .* load.q_to_p
    end
    nothing
end


function load_from_csv(load::Load)
    throw("NotImplementedError")
end


load_busses(net::AbstractNetwork) = collect(b for b in busses(net) if haskey(net[b], :Load))


real_load_busses(net::Network{SinglePhase}) = collect(b for b in load_busses(net) if !ismissing(net[b][:Load].p1))


real_load_busses(net::Network{MultiPhase}) = collect(
    b for b in load_busses(net) 
    if !ismissing(net[b][:Load].p1) || !ismissing(net[b][:Load].p2) || !ismissing(net[b][:Load].p3)
)


reactive_load_busses(net::Network{SinglePhase}) = collect(b for b in load_busses(net) if !ismissing(net[b][:Load].q1))


reactive_load_busses(net::Network{MultiPhase}) = collect(
    b for b in load_busses(net) 
        if !ismissing(net[b][:Load].q1) || !ismissing(net[b][:Load].q2) || !ismissing(net[b][:Load].q3)
)


total_load_p(net::Network{SinglePhase}) = sum(net[load_bus][:Load].p1 for load_bus in real_load_busses(net))


total_load_q(net::Network{SinglePhase}) = sum(net[load_bus][:Load].q1 for load_bus in real_load_busses(net))


"""
    sj(j::String, net::Network{SinglePhase})::AbstractVector{ComplexF64}

Return the complex power injections (negative of load) at bus `j`. 
"""
function sj(j::String, net::Network{SinglePhase})::AbstractVector{ComplexF64}
    pj, qj = zeros(net.Ntimesteps), zeros(net.Ntimesteps)
    if j in real_load_busses(net)
        pj = -net[j][:Load].p1
    end
    if j in reactive_load_busses(net)
        qj = -net[j][:Load].q1
    end
    return pj + im * qj
end


"""
    sj_per_unit(j::String, net::Network{SinglePhase})::AbstractVector{ComplexF64}

Return the complex power injections (negative of load) at bus `j` per-unit power.
"""
function sj_per_unit(j::String, net::Network{SinglePhase})::AbstractVector{ComplexF64}
    return sj(j, net) / net.Sbase
end


"""
    sj_per_unit(j::String, net::Network{MultiPhase})::Tuple{Vector{Vector{<:Real}}, Vector{Vector{<:Real}}}

return the real and reactive power injections as vectors with 3 phase indices and net.Ntimesteps time
indices like:
```julia
sj = sj_per_unit(my_bus, net)
...
sj[phase][time_step]
```
"""
function sj_per_unit(j::String, net::Network{MultiPhase})::Vector{Vector{ComplexF64}}
    pj = [zeros(net.Ntimesteps) for _ in 1:3] # first dim is phase, like pj[phs][t]
    qj = [zeros(net.Ntimesteps) for _ in 1:3]
    if j in real_load_busses(net)
        for phs in 1:3
            pj[phs] = -net[j, :p, phs] / net.Sbase
        end
    end
    if j in reactive_load_busses(net)
        for phs in 1:3 
            qj[phs] = -net[j, :q, phs] / net.Sbase
        end
    end
    return pj + im * qj
end