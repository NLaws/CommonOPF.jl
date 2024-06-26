"""
    struct VoltageRegulator <: AbstractEdge
        # required values
        busses::Tuple{String, String}
        # optional values
        high_kv::Real = 1.0
        low_kv::Real = 1.0
        phases::Union{Vector{Int}, Missing} = missing
        reactance::Real = 0.0
        resistance::Real = 0.0
        vreg_pu::Union{Real, AbstractVector{<:Number}, Missing} = missing
        turn_ratio::Union{Real, Missing} = missing
    end

Required fields:
- `busses::Tuple{String, String}`
- either `vreg_pu::Real` or `turn_ratio::Real`

If `vreg_pu` is specified then the regulator is "perfect" and the second bus in `busses` is fixed to
the value provided for `vreg_pu`.

If `turn_ratio` is provided then the voltage across the regulator is scaled by the `turn_ratio`.

# Examples:
## Julia Dict
```julia
netdict = Dict(
    :network => Dict(:substation_bus => "1", :Sbase => 1),
    :conductors => [
        ...
    ],
    :voltage_regulators => [
        Dict(
            :busses => ("2", "3")
            :vreg_pu => 1.05
        )
    ]
)
```
## YAML file
```yaml
Network:
  substation_bus: 0
  Sbase: 1

Conductor:
    ...

VoltageRegulator:
  busses: 
    - 2
    - 3
  vreg_pu: 1.05
```
"""
@with_kw mutable struct VoltageRegulator <: AbstractEdge
    # required values
    busses::Tuple{String, String}
    # optional values
    name::Union{String, Missing} = missing
    high_kv::Real = 1.0
    low_kv::Real = 1.0
    phases::Union{Vector{Int}, Missing} = missing
    reactance::Real = 0.0
    resistance::Real = 0.0
    vreg_pu::Union{Real, AbstractVector{<:Number}, Missing} = missing
    turn_ratio::Union{Real, Missing} = missing
    rmatrix::Union{AbstractArray, Missing} = missing
    xmatrix::Union{AbstractArray, Missing} = missing
end


"""
    check_edges!(regulators::AbstractVector{VoltageRegulator})::Bool

Warn if not missing both vreg_pu and turn_ratio and call validate_multiphase_edges! if any `phases`
are not missing.
"""
function check_edges!(regulators::AbstractVector{VoltageRegulator})::Bool
    bad_reg_busses = Tuple{String, String}[]
    good = true
    for reg in regulators
        if ismissing(reg.vreg_pu) && ismissing(reg.turn_ratio)
            push!(bad_reg_busses, reg.busses)
        end
    end
    if !isempty(bad_reg_busses)
        @warn "Missing required inputs for VoltageRegulators on busses $(bad_reg_busses)"
        @warn "You must provide either vreg_pu or turn_ratio for each VoltageRegulator."
        good = false
    end
    if any((!ismissing(reg.phases) for reg in regulators)) && length(phases_union(regulators)) > 1
        good = validate_multiphase_edges!(regulators)
    end
    return good
end

# TODO methods for constraining regulated voltage, pass in model and variable references
function regulator_with_fixed_tap_ratio() end
function regulator_with_fixed_voltage() end
function regulator_with_continuous_voltage_variable() end
function regulator_with_discrete_voltage_variables() end
