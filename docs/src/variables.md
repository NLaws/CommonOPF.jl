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