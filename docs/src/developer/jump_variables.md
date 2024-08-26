# JuMP Model Variables
CommonOPF provides some patterns for storing variables so that we can provide common functionality
across power flow models. Currently the main functionality that relies on variable access-patterns
is `Results`. Note that you do not have to use the CommonOPF variable access patterns to use the
`Network` model and other methods like the graph analysis stuff.


### Variable Containers
CommonOPF provides a variable container pattern for the `JuMP.Model`s built in the CommonOPF
dependencies so that we can support common functionality, especially for retrieving results from
solved models. The pattern is a `Dict{String, Dict{Int, Any}}` that has:
1. bus or edge labels first
2. and integer time step keys second.
For example, a single-phase model that stores the `"net_real_power_injection"` variable in
`model[:p]` will store the real power variable for bus "b1" in `model[:p]["b1"][1]`. 