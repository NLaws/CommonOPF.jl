# Input Formats
CommmonOPF provides three ways to construct the [Network Model](@ref) model:
1. YAML file(s)
2. JSON file(s)
3. Julia code (manual)

Only `Conductor`s are required to build the `Network`. Note that the input keys are, singular,
CamelCase words to align with the data type names.

## Conductor
```@docs
CommonOPF.Conductor
```

## Load
```@docs
CommonOPF.Load
Base.getindex(net::Network, bus::String, kws_kvars::Symbol, phase::Int)
```

## ShuntAdmittance
```@docs
CommonOPF.ShuntAdmittance
```

## ShuntImpedance
```@docs
CommonOPF.ShuntImpedance
```

## VoltageRegulator
```@docs
CommonOPF.VoltageRegulator
```
