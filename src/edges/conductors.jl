"""
    struct Conductor <: AbstractEdge

Interface for conductors in a Network. Fieldnames can be provided via a YAML file, JSON file, or
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
x1)` respectively; or via the lower-diagaonal portion of the phase-impedance matrix. 

Using the Multi-phase models require specifing `phases` (and the zero and positive sequence
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
    rmatrix::Union{AbstractArray, Missing} = missing
    xmatrix::Union{AbstractArray, Missing} = missing
    length::Union{Real, Missing} = missing
    amps_limit::Union{Real, Missing} = missing
end


function check_edges!(conductors::AbstractVector{Conductor})
    # check multiphase conductors
    if any((!ismissing(c.phases) for c in conductors))
        validate_multiphase_conductors!(conductors)
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
        if (
            any(ismissing.([cond.template, cond.length])) &&
            any(ismissing.([cond.x1, cond.r1, cond.length]))
        )
            n_cannot_define_impedance += 1
        end
        if !ismissing(cond.template)
            push!(templates, cond.template)
        end
    end

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
        @warn "Missing templates: $(missing_templates)."
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
    function unpack_input_matrices!(cond::Conductor)

Convert lower diagonal impedance matrices loaded in from YAML or JSON to 3x3 matrices.
The "matrices" come in as Vector{Vector} and look like:
```
julia> d[:conductors][3][:rmatrix]
3-element Vector{Vector{Float64}}:
 [0.31]
 [0.15, 0.32]
 [0.15, 0.15, 0.33]
```
"""
function unpack_input_matrices!(cond::Conductor)
    rmatrix = zeros(3,3)
    xmatrix = zeros(3,3)
    for (i, phs1) in enumerate(cond.phases), (j, phs2) in enumerate(cond.phases)
        try
            if i >= j # in lower triangle
                rmatrix[phs1, phs2] = cond.rmatrix[i][j]
                xmatrix[phs1, phs2] = cond.xmatrix[i][j]
            else  # flip i,j to mirror in to upper triangle
                rmatrix[phs1, phs2] = cond.rmatrix[j][i]
                xmatrix[phs1, phs2] = cond.xmatrix[j][i]
            end
        catch BoundsError
            @warn "Unable to process impedance matrices for conductor:\n"*
                "$cond\n"*
                "Probably because the phases do not align with one or both of the rmatrix and xmatrix."
            return
        end
    end
    cond.rmatrix = rmatrix
    cond.xmatrix = xmatrix
    nothing
end


"""
    validate_multiphase_conductors!(conds::AbstractVector{Conductor})

Fill in impedance matrices and `@warn` for any conductors that do not have inputs required to define
impedance.
"""
function validate_multiphase_conductors!(conds::AbstractVector{Conductor})
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
                # unpack the Vector{Vector} (lower diagaonal portion of matrix)
                if typeof(c.rmatrix) <: Vector
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
            if Set(sort(c.phases)) != Set(sort(template_cond.phases))
                @warn """Conductor with name $(c.name) and phases $(c.phases) has template $(c.template) 
                         with phases $(template_cond.phases). Not copying template impedance matrices."""
                good = false
            end
            c.xmatrix = template_cond.xmatrix
            c.rmatrix = template_cond.rmatrix
        end
    end

    if n_no_phases > 0
        @warn "$(n_no_phases) conductors are missing phases."
        good = false
    end

    if length(missing_templates) > 0
        @warn "Missing templates: $(missing_templates)."
        good = false
    end

    if n_no_impedance > 0
        @warn "$(n_no_impedance) conductors do not have sufficient parameters to define the impedance.\n"*
            "see https://nlaws.github.io/CommonOPF.jl/dev/inputs/#CommonOPF.Conductor"
        good = false
    end
    return good
end
