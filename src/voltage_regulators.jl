# use these in LoadFlow first to confirm test results
# then in BFM to continue the transition to Network from Inputs
"""
    struct VoltageRegulator <: AbstractBus

Required fields:
- `bus::String`
- `vreg_pu::Real`

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
            :bus => "2",
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
  bus: 2
  vreg_pu: 1.05
```
"""
@with_kw struct VoltageRegulator <: AbstractBus
    # required values
    bus::String
    vreg_pu::Real
    # optional values
    phases::Union{Vector{Int}, Missing} = missing
end
