# JuMP Model Variables
CommonOPF provides some patterns for storing variables so that we can provide common functionality
across power flow models. Currently the main functionality that relies on variable access-patterns
is `Results`. Note that you do not have to use the CommonOPF variable access patterns to use the
`Network` model and other methods like the graph analysis stuff.

### Variable Names
The CommonOPF variable names are stored as strings in `VARIABLE_NAMES`:
```@example
using CommonOPF
for var_name in CommonOPF.VARIABLE_NAMES
    println(var_name)
end
```
By default the `VARIABLE_NAMES` are used to check for model variable values. Alternatively, one can
fill in the `Network.var_name_map` to use custom variable names in the `JuMP.Model`. The
`var_name_map` is keyed on the `VARIABLE_NAMES` and any value provided will be used to check for
model variable values. For example:
```julia
my_network.var_name_map = Dict("voltage_magnitude_squared" => :w)
```
will indicate to the `CommonOPF.Results` method to look in `model[:w]` for the
`"voltage_magnitude_squared"` values.

### Variable Containers
CommonOPF provides a variable container pattern for the `JuMP.Model`s built in the CommonOPF
dependencies so that we can support common functionality, especially for retrieving results from
solved models. The pattern is a `Dict{String, Dict{Int, Any}}` that has:
1. bus or edge labels first
2. and integer time step keys second.
For example, a single-phase model that stores the `"net_real_power_injection"` variable in
`model[:p]` will store the real power variable for bus "b1" in `model[:p]["b1"][1]`. 