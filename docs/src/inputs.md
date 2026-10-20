# Input Formats
CommmonOPF provides three ways to construct the [Network Model](@ref) model:
1. YAML file(s)
2. JSON file(s)
3. Julia code (manual)

Only `Network` is required to build the `Network`. Note that the input keys are, singular,
CamelCase words to align with the data type names. For example a single phase, single time step
model looks like:
```yaml
Network:
  substation_bus: b1

Conductor:
  - name: cond1
    busses: 
      - b1
      - b2
    r1: 0.301  # impedance has units of ohm/per-unit-length
    x1: 0.627
    length: 100
  - busses:
      - b2
      - b3
    template: cond1  # <- reuse impedance of cond1
    length: 200

Load:
  - bus: b2
    p1: 
      - 5.6  # you can specify more loads at each bus to add time steps
    q1: 
      - 1.2
  - bus: b3
    p1: 
      - 5.6
    q1: 
      - 1.2
```
The [`Network(fp::String)`](@ref) constructor excepts a path to a yaml file.


## Battery
```@docs
CommonOPF.Battery
```


## Conductor
```@docs
CommonOPF.Conductor
```

## Generator
```@docs
CommonOPF.Generator
```

## Load
```@docs
CommonOPF.Load
Base.getindex(net::Network, bus::String, power_symbol::Symbol, phase::Int)
```

## Capacitor
```@docs
CommonOPF.Capacitor
```

## ShuntAdmittance
```@docs
CommonOPF.ShuntAdmittance
```

## Transformer
```@docs
CommonOPF.Transformer
```

## VoltageRegulator
```@docs
CommonOPF.VoltageRegulator
```
