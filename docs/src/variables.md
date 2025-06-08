# Variables for Mathematical Programs
CommonOPF provides standard variables names so that the packages that build upon CommonOPF can
leverage common results getters and `VariableBounds`.

## Variable Containers
CommonOPF provides variable containers to standardize indexing across OPF models. The order of
indexing is: 
1. `var_symbol` like `:v`
2. `bus_or_edge`
3. `time_step`
4. phase in `[1, 2, 3]` (if `MultiPhase` model)

### Single phase models
```@docs
add_time_vector_variables!
```

### Multiphase models
```@docs
multiphase_bus_variable_container
multiphase_edge_variable_container
```


## Variable Bounds
```@docs
CommonOPF.VariableBounds
CommonOPF.VariableBounds(::Dict)
```

## Documenting Variables
CommonOPF provides a way to document model variables within the [`Network`](@ref) struct. See the
[`CommonOPF.VariableInfo`](@ref) struct and the [`CommonOPF.print_var_info`](@ref) method below for
details. As an example (and test) of the `print_var_info` method:
```@setup print_var_info
using CommonOPF

net = Network(Dict(
    :Network => Dict(
        :substation_bus => "source"
    ),
    :Conductor => [Dict(
        :busses => ("source", "b1"),
        :phases => [1,2,3]
    )]
))

net.var_info[:vsqrd] = CommonOPF.VariableInfo(
    :vsqrd,
    "voltage magnitude squared",
    CommonOPF.VoltUnit,
    (CommonOPF.BusDimension, CommonOPF.TimeDimension, CommonOPF.PhaseDimension)
)

net.var_info[:pj] = CommonOPF.VariableInfo(
    :pj,
    "net bus injection real power on bus j",
    CommonOPF.RealPowerUnit,
    (CommonOPF.BusDimension, CommonOPF.TimeDimension, CommonOPF.PhaseDimension)
)

net.var_info[:qj] = CommonOPF.VariableInfo(
    :qj,
    "net bus injection reactive power on bus j",
    CommonOPF.ReactivePowerUnit,
    (CommonOPF.BusDimension, CommonOPF.TimeDimension, CommonOPF.PhaseDimension)
)

net.var_info[:pij] = CommonOPF.VariableInfo(
    :pij,
    "sending end real power from bus i to j",
    CommonOPF.RealPowerUnit,
    (CommonOPF.EdgeDimension, CommonOPF.TimeDimension, CommonOPF.PhaseDimension)
)

net.var_info[:qij] = CommonOPF.VariableInfo(
    :qij,
    "sending end ReactivePowerUnit power from bus i to j",
    CommonOPF.RealPowerUnit,
    (CommonOPF.EdgeDimension, CommonOPF.TimeDimension, CommonOPF.PhaseDimension)
)
```
```@example print_var_info
CommonOPF.print_var_info(net)
```

```@docs
CommonOPF.VariableInfo
CommonOPF.Units
CommonOPF.Dimensions
CommonOPF.print_var_info
```