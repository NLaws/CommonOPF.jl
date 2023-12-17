# Creating a `Network`
The `Network` struct is used to build models in BranchFlowModel.jl, LoadFlow.jl, and LinDistFlow.jl.
CommonOPF.jl parses input files into a `Dict{Symbol, Vector{Dict}}` for each input type. Input types
all subtype either `CommonOPF.AbstractEdge` or `CommonOPF.AbstractBus`. Concrete edge and bus
models/structs get stored in `Network.graph`, which is a subtype of `MetaGraphsNext.AbstractGraph`.
One can then easily extend `MetaGraphsNext` and `Graphs` methods using the `Network.graph` like so:
```julia
Graphs.edges(net::AbstractNetwork) = MetaGraphsNext.edge_labels(net.graph)
```

# Adding a Bus device
The current Bus devices are:
```@eval
using CommonOPF
import InteractiveUtils: subtypes

subtypes(CommonOPF.AbstractBus)
```
To add a new Bus device:
1. create `YourType` that has at a minimum:
    ```julia
    @with_kw struct YourType <: AbstractBus
        bus::String
    end
    ```
    - any required fields should have no default
    - any optional fields should have default of `missing`
2. OPTIONALLY define a `check_busses!(busses::AbstractVector{YourType})` method
    - `check_busses!` is used in the `Network` builder after unpacking user input dicts into `YourType`
    constructor
3. Ensure compatibility with the `MetaGraph`
    - make sure the `AbstractVector{YourType}` returned from your
   constructor is compatible with `fill_node_attributes!`.

The `fill_{edge,node}_attributes!` methods are used in the `Network` builder to store all the
attributes of `YourType` in the `Network.graph`.  The `Network.graph` is used to build the power
flow models -- so you also will probably need to modify `BranchFlowModel.jl` to account for your new
type. (But in the future we might be able to handle abstract edge or bus models that implement a
certain set of attributes).

You might also want to extend the `Network` interface for your type. For example, when adding the
`Load` type we added a load buss getter like so:
```julia
load_busses(net::AbstractNetwork) = (b for b in busses(net) if haskey(net[b], :Load))
```

# Adding an Edge device
The current Edge devices are:
```@eval
using CommonOPF
import InteractiveUtils: subtypes

subtypes(CommonOPF.AbstractEdge)
```
To add a new Edge device:
1. create `YourType` that has at a minimum:
    ```julia
    @with_kw mutable struct YourType <: AbstractEdge
        busses::Tuple{String, String}
        phases::Union{Vector{Int}, Missing} = missing
    end
    ```
2. OPTIONALLY define a `check_edges!(edges::AbstractVector{YourType})` method
    - `check_edges!` is used in the `Network` builder after unpacking user input dicts into `YourType`
    constructor
3. Ensure compatibility with the `MetaGraph`
    - make sure the `AbstractVector{YourType}` returned from your
   constructor is compatible with `fill_edge_attributes!`. 


# JuMP Model Variables
CommonOPF provides some patterns for storing variables so that we can provide common functionality
across power flow models. Currently the main functionality that relies on variable access-patterns
is `Results`. Note that you do not have to use the CommonOPF variable access patterns to use the
`Network` model and other methods like the graph analysis stuff.

## Variable Names
The CommonOPF variable names are stored as strings in `VARIABLE_NAMES`:
```@example
using CommonOPF
for var_name in CommonOPF.VARIABLE_NAMES
    println(var_name)
end
```
By default the `VARIABLE_NAMES` are used to check for model variable values. Alternatively, one can
fill in the `Network.var_name_map` to use custom variable names in the `JuMP.Model`. The
`var_name_map` is keyed on the `VARIABLE_NAMES` and any value provided will be used to heck for
model variable values.

## Variable Containers
CommonOPF provides a variable container pattern for the `JuMP.Model`s built in the CommonOPF
dependencies so that we can support common functionality, especially for retrieving results from
solved models. The pattern is a `Dict{Int, Dict{String, Any}}` that has:
1. integer time step keys first
2. and bus or edge labels second.
For example, a single-phase model that stores the `"net_real_power_injection"` variable in
`model[:p]` will store the real power variable for bus "b1" in `model[:p][1]["b1"]`. 