# Inputs
CommmonOPF provides three ways to construct the [Network Model](@ref) model:
1. YAML file(s)
2. JSON file(s)
3. Julia code (manual)

Only `conductors` are required to build the `Network`

## Conductors
```@docs
CommonOPF.Conductor
```
## Loads
```@docs
CommonOPF.Load
Base.getindex(net::Network, bus::String, kws_kvars::Symbol, phase::Int)
```

## Voltage Regulators
```@docs
CommonOPF.VoltageRegulator
```

