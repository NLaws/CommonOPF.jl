"""
    struct Conductor <: AbstractEdge

Interface for conductors in a Network. Fieldnames can be provided via a YAML file or
    populated manually. Conductors are specified via two busses, the **impedance in ohms per-unit
    length**, and a length value. 

# Single phase models
The minimum inputs for a single phase conductor look like:
```yaml
Conductor:
  - busses: 
      - b1
      - b2
    r1: 0.1
    x1: 0.1
    length: 100
```
Note that the order of the items in the YAML file does not matter.

A conductor can also leverage a `template`, i.e. another conductor with a `name` that matches the
`template` value so that we can re-use the impedance values:
```yaml
Conductor:
  - name: cond1
    busses: 
      - b1
      - b2
    r1: 0.1
    x1: 0.1
    length: 100
  - busses:
      - b2
      - b3
    template: cond1
    length: 200
```
The second conductor in the `conductors` above will use the `r0` and `x0` values from `cond1`,
scaled by the `length` of 200 and normalized by `Zbase`.

!!! note 
    The `name` field is optional unless a `conductor.name` is also the `template` of another
    conductor.
    
!!! warning 
    If any `phases` properties are set in the `conductors` then it is assumed that the model is 
    multi-phase.

# Multi-phase models

Multi-phase conductors can be modeled as symmetrical or asymmetrical components. Similar to OpenDSS,
line impedances can be specified via the zero and positive sequence impedances, `(r0, x0)` and `(r1,
x1)` respectively; or via the lower-diagonal portion of the phase-impedance matrix. 

Using the Multi-phase models requires specifying `phases` (and the zero and positive sequence
impedances) like:
```yaml
Conductor:
  - busses: 
      - b1
      - b2
    phases:
      - 2
      - 3
    r0: 0.766
    x0: 1.944
    r1: 0.301
    x1: 0.627
    length: 100
```
When the sequence impedances are provided the phase-impedance matrix is determined using the math in
[Symmetrical Mutliphase Conductors](@ref).


Alternatively one can specify the `rmatrix` and `xmatrix` like:
```yaml
Conductor:
  - busses: 
      - b1
      - b2
    phases:
      - 1
      - 3
    rmatrix: 
      - [0.31]
      - [0.15, 0.32]
    xmatrix:
      - [1.01]
      - [0.5, 1.05]
    length: 100
```
!!! warning
    The order of the `phases` is assumed to match the order of the `rmatrix` and `xmatrix`. For
    example using the example just above the 3x3 `rmatrix` looks like 
    ``[0.31, 0, 0.15; 0, 0, 0; 0.15, 0, 0.32]``

Conductors also have a `cmatrix` attribute that is used when parsing OpenDSS models. The `cmatrix`
is used to define `ShuntAdmittance` values for busses.

For high kV lines one can specify the `kv_class` instead of impedance values. The impedance values
are populated using a look up table. Only r1 and x1 are filled in and have units of ohms/km; which
means that **the length value should be provided in km**. For
example, a conductor like:
```yaml
Conductor:
  - busses: 
      - b1
      - b2
    kv_class: 345 
    length: 100
```
will be filled such that the `Conductor` in the `Network` looks like:
```julia
TODO
```
"""
@with_kw mutable struct Conductor <: AbstractEdge
    # mutable because we set the rmatrix and xmatrix later in some cases
    # required values
    busses::Tuple{String, String}
    # optional values
    phases::Union{Vector{Int}, Missing} = missing
    name::Union{String, Missing} = missing
    template::Union{String, Missing} = missing
    r0::Union{Real, Missing} = missing
    x0::Union{Real, Missing} = missing
    r1::Union{Real, Missing} = missing
    x1::Union{Real, Missing} = missing
    c1::Union{Real, Missing} = missing
    rmatrix::Union{AbstractArray, Missing} = missing
    xmatrix::Union{AbstractArray, Missing} = missing
    cmatrix::Union{AbstractArray, Missing} = missing
    length::Union{Real, Missing} = missing
    amps_limit::Union{Real, Missing} = missing
    kv_class::Union{Int, Missing} = missing
end


"""
    @with_kw mutable struct ParallelConductor <: AbstractEdge

Store multiple [`Conductor`](@ref) objects that share the same pair of busses.
Impedance and admittance functions operate on a `ParallelConductor` just like on
a single conductor whose parameters are the parallel combination of the contained
lines.
"""
@with_kw mutable struct ParallelConductor <: AbstractEdge
    busses::Tuple{String, String}
    conductors::Vector{Conductor} = Vector{Conductor}[]
    phases::Union{Vector{Int}, Missing} = missing
    length::Union{Real, Missing} = missing
end


"""
    ParallelConductor(cs::Vector{Conductor})

Create a [`ParallelConductor`](@ref) from a vector of `Conductor` objects. All
conductors must share the same pair of busses. The phases are the union of the
phases on the contained lines and the length is the mean length of the lines.
"""
function ParallelConductor(cs::Vector{Conductor})
    # canonicalize a pair so that (a,b) and (b,a) become the same tuple
    canon(p) = (min(p[1], p[2]), max(p[1], p[2]))
    @assert !isempty(cs)
    busses = cs[1].busses
    @assert all(c -> canon(c.busses) == canon(busses), cs)
    phs = [c.phases for c in cs if !ismissing(c.phases)]
    phases = isempty(phs) ? missing : sort(unique(reduce(vcat, phs)))
    len = sum(c.length for c in cs) / length(cs)  # mean length
    ParallelConductor(busses, cs, phases, len)
end


"""
    check_edges!(conductors::AbstractVector{Conductor})

if all `phases` are missing then
    - `warn_singlephase_conductors_and_copy_templates(conductors)`
else
    - `validate_multiphase_edges!(conductors)`
"""
function check_edges!(conductors::AbstractVector{Conductor})
    if any((!ismissing(c.phases) for c in conductors)) && length(phases_union(conductors)) > 1
        validate_multiphase_edges!(conductors)
    else
        warn_singlephase_conductors_and_copy_templates(conductors)
    end
    return nothing
end


"""
    warn_singlephase_conductors_and_copy_templates(conds::AbstractVector{Conductor})

1. Warn when missing templates and/or cannot define impedances.
2. Copy template r1 and x1 values.
"""
function warn_singlephase_conductors_and_copy_templates(conds::AbstractVector{Conductor})
    n_cannot_define_impedance = 0
    templates = String[]
    for cond in conds
        # these are all the ways that we can define impedance:
        if (
            any(ismissing.([cond.template, cond.length])) &&
            any(ismissing.([cond.x1, cond.r1, cond.length])) &&
            any(ismissing.([cond.kv_class, cond.length]))
        )
            n_cannot_define_impedance += 1
        end
        if !ismissing(cond.template)
            push!(templates, cond.template)
        end

        # fill r1, x1 based on kv_class
        if !(ismissing(cond.kv_class))
            if !_check_kv_class(cond.kv_class)
                continue
            end
            if ismissing(cond.r1)
                cond.r1 = OVERHEAD_LINE_IMPEDANCES_BY_KV[cond.kv_class][:R_ohm_per_km]
            end
            if ismissing(cond.x1)
                cond.x1 = OVERHEAD_LINE_IMPEDANCES_BY_KV[cond.kv_class][:X_ohm_per_km]
            end
        end
    end

    # copy template resistance and reactance values, check for missing templates 
    missing_templates = String[]
    for template_name in templates
        template_index = findfirst(c -> !ismissing(c.name) && c.name == template_name, conds)
        if isnothing(template_index)
            push!(missing_templates, template_name)
            continue
        end
        template_cond = conds[template_index]
        for c in filter(c -> !ismissing(c.template) && c.template == template_name, conds)
            c.r1 = template_cond.r1
            c.x1 = template_cond.x1
        end
    end

    good = true
    if n_cannot_define_impedance > 0
        @warn "$(n_cannot_define_impedance) conductors are missing inputs to define impedance.\n"*
              "For single phase conductors you must provide either (template, length) or (r1, x1, length)."
        good = false
    end
    if length(missing_templates) > 0
        @warn "Missing conductor templates: $(missing_templates)."
        good = false
    end
    return good
end


"""
    function fill_impedance_matrices!(cond::Conductor)

Use zero and positive sequence impedances to create phase-impedance matrix.
"""
function fill_impedance_matrices!(cond::Conductor)
    # TODO use symmetric matrices s.t. can reduce memory footprint?
    rself = 1/3 * cond.r0 + 2/3 * cond.r1
    rmutual = 1/3 * (cond.r0 - cond.r1)
    xself = 1/3 * cond.x0 + 2/3 * cond.x1
    xmutual = 1/3 * (cond.x0 - cond.x1)
    # fill the matrices
    rmatrix = zeros(3,3)
    xmatrix = zeros(3,3)
    for phs1 in cond.phases, phs2 in cond.phases
        if phs1 == phs2  # diagaonal
            rmatrix[phs1, phs1] = rself
            xmatrix[phs1, phs1] = xself
        else  # off-diagonal
            rmatrix[phs1, phs2] = rmutual
            xmatrix[phs1, phs2] = xmutual
        end
    end
    cond.rmatrix = rmatrix
    cond.xmatrix = xmatrix
    nothing
end


"""
    validate_multiphase_edges!(conds::AbstractVector{Conductor})::Bool

Fill in impedance matrices and `@warn` for any conductors that do not have inputs required to define
impedance.
"""
function validate_multiphase_edges!(conds::AbstractVector{Conductor})::Bool
    n_no_phases = 0
    n_no_impedance = 0
    templates = String[]

    for c in conds
        if ismissing(c.phases)
            n_no_phases += 1
        elseif (
            any(ismissing.([c.template, c.length])) &&
            any(ismissing.([c.r0, c.x0, c.r1, c.x1, c.length])) &&
            any(ismissing.([c.rmatrix, c.xmatrix, c.length]))
        ) # if all of these are true then we cannot define impedance
            n_no_impedance += 1
        else  # we have everything we need to define rmatrix, xmatrix
            if !ismissing(c.rmatrix) 
                if typeof(c.rmatrix) <: Vector
                    # unpack the Vector{Vector} (lower diagonal portion of matrix)
                    unpack_input_matrices!(c)
                # elseif typeof(c.rmatrix) <: Matrix  # do nothing, we're good
                    # NOTE assuming R and X provided in the same format
                end

            elseif !ismissing(c.template)  
                # defer template copying in case the template requires calculating matrices
                push!(templates, c.template)
            else  # use zero and positive sequence impedances
                fill_impedance_matrices!(c)
            end
        end
    end

    good = true

    # copy template values
    missing_templates = String[]
    for template_name in templates
        template_index = findfirst(c -> !ismissing(c.name) && c.name == template_name, conds)
        if isnothing(template_index)
            push!(missing_templates, template_name)
            continue
        end
        template_cond = conds[template_index]
        for c in filter(c -> !ismissing(c.template) && c.template == template_name, conds)
            if Set(c.phases) != Set(template_cond.phases)
                @warn """Conductor with name $(c.name) and phases $(c.phases) has template $(c.template) 
                         with phases $(template_cond.phases). Not copying template impedance matrices."""
                good = false
            end
            c.xmatrix = template_cond.xmatrix
            c.rmatrix = template_cond.rmatrix
            c.cmatrix = template_cond.cmatrix
        end
    end

    if n_no_phases > 0
        @warn "$(n_no_phases) conductors are missing phases."
        good = false
    end

    if length(missing_templates) > 0
        @warn "Missing conductor templates: $(missing_templates)."
        good = false
    end

    if n_no_impedance > 0
        @warn "$(n_no_impedance) conductors do not have sufficient parameters to define the impedance.\n"*
            "see https://nlaws.github.io/CommonOPF.jl/dev/inputs/#CommonOPF.Conductor"
        good = false
    end

    return good
end
