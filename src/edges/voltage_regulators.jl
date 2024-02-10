# use these in LoadFlow first to confirm test results
# then in BFM to continue the transition to Network from Inputs
"""
    struct VoltageRegulator <: AbstractEdge

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
@with_kw struct VoltageRegulator <: AbstractEdge
    # required values
    busses::Tuple{String, String}
    # optional values
    high_kv::Real = 1.0
    low_kv::Real = 1.0
    phases::Union{Vector{Int}, Missing} = missing
    reactance::Real = 0.0
    resistance::Real = 0.0
    vreg_pu::Union{Real, Missing} = missing
    turn_ratio::Union{Real, Missing} = missing
end


function check_edges!(regulators::AbstractVector{VoltageRegulator})
    bad_reg_busses = Tuple{String, String}[]
    for reg in regulators
        if ismissing(reg.vreg_pu) && ismissing(reg.turn_ratio)
            push!(bad_reg_busses, reg.busses)
        end
    end
    if !isempty(bad_reg_busses)
        @warn "Missing required inputs for VoltageRegulators on busses $(bad_reg_busses)"
        @warn "You must provide either vreg_pu or turn_ratio for each VoltageRegulator."
    end
    nothing
end

# methods for constraining regulated voltage? will need the voltage variable and model