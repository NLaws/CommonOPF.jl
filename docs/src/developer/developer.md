# Creating a `Network`
The `Network` struct is used to build models in BranchFlowModel.jl, LoadFlow.jl, and LinDistFlow.jl.
CommonOPF.jl parses input files into a `Dict{Symbol, Vector{Dict}}` for each input type. Input types
all subtype either `CommonOPF.AbstractEdge` or `CommonOPF.AbstractBus`. Concrete edge and bus
models/structs get stored in `Network.graph`, which is a subtype of `MetaGraphsNext.AbstractGraph`.
One can then easily extend `MetaGraphsNext` and `Graphs` methods using the `Network.graph` like so:
```julia
Graphs.edges(net::AbstractNetwork) = MetaGraphsNext.edge_labels(net.graph)
```

Each edge of the `Network.graph` stores one concrete subtype of `AbstractEdge`. The busses can store
multiple subtypes of `AbstractBus` using symbol keys. For example an edge in the Network is accessed via a two-tuple of bus strings like
```julia
network[("bus1", "bus2")]
```
which will return an instance of a subtype of `AbstractEdge` (which are listed in [Adding an Edge device](@ref)). A bus is accessed in the network via:
```julia
network["bus2"]
```
which will return a `Dict{Symbol, Any}`. The `Symbol`s can be any of the names of the `AbstractBus` subtypes (which are listed in [Adding a Bus device](@ref))

### Adding a Bus device
The current Bus devices are:
```@example
using CommonOPF # hide
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
    - `check_busses!` is used in the `Network` builder after unpacking user input dicts into `YourType` constructor
3. Ensure compatibility with the `MetaGraph`
    - make sure the `AbstractVector{YourType}` returned from your constructor is compatible with [`CommonOPF.fill_node_attributes!`](@ref).

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

### Adding an Edge device
The current Edge devices are:
```@example
using CommonOPF # hide
import InteractiveUtils: subtypes # hide

subtypes(CommonOPF.AbstractEdge)
```
`ParallelConductor` is used internally when multiple `Conductor` specifications
share the same pair of busses. The impedance and admittance methods operate on a
`ParallelConductor` just like a single `Conductor`.
To add a new Edge device:
1. create `YourType` that has at a minimum:
    ```julia
    @with_kw mutable struct YourType <: AbstractEdge
        busses::Tuple{String, String}
        phases::Union{Vector{Int}, Missing} = missing
        rmatrix::Union{AbstractArray, Missing} = missing
        xmatrix::Union{AbstractArray, Missing} = missing
    end
    ```
    For multiphase models each subtype of `AbstractEdge` must have `rmatrix` and `xmatrix`
    properties. If you also specify `resistance` and `reactance` fields then you can take advantage
    of the default `validate_multiphase_edges!`. You can also implement your own
    `validate_multiphase_edges!` that dispatches on your type. See for example
    `validate_multiphase_edges!(conds::AbstractVector{Conductor})`. Note that 
2. define methods that dispatch on your type like
    - `resistance(your_edge::YourType)`
    - `reactance(your_edge::YourType)`
3. OPTIONALLY define a `check_edges!(edges::AbstractVector{YourType})` method
    - `check_edges!` is used in the `Network` builder after unpacking user input dicts into
      `YourType` constructor. `check_edges!` is where you can use the default
      `validate_multiphase_edges!` for example.
