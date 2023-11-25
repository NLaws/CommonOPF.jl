# Pattern for Edge and Bus models
1. make a `mutable struct` using `with_kw` (for ease of parameter validation) for `YourType`
    - subtype either `AbstractEdge` or `AbstractBus`
    - any required fields should have no default
    - any optional fields should have default of `missing`
2. Define a constructor `function build_{your_types}` for your new edge or bus that takes a `dict`
   as the only argument
    - the `dict` is parsed from `yaml` or `json` file(s). For example, the `build_loads` function
      requires a `:loads` key in the `dict`
    - replace any `missing` fields that must be derived from user inputs (i.e. things needed in the
      power flow model)
        - for example, in a `Load` the reactive power can be derived using the `q_to_p` value
    - the constructor function must return a subtype of `AbstractVector{YourType}`
3. Ensure commptibilty with the `MetaGraph`
    - If you subtyped `AbstractEdge` make sure the `AbstractVector{YourType}` returned from your
   constructor is compatible with `fill_edge_attributes!`. 
    - If you subtyped `AbstractBus` make sure the `AbstractVector{YourType}` returned from your
   constructor is compatible with `fill_node_attributes!`.

The `fill_{edge,node}_attributes!` methods are used in the `Network` builder to store all the
attributes of `YourType` in the `Network.graph`.  The `Network.graph` is used to build the power
flow models -- so you also will probably need to modify `BranchFlowModel.jl` to account for your new
type. (But in the future we might be able to handle abstract edge or bus models that implement a
certain set of attributes).

You might also want to extend the `Network` interface for your type. For example, when adding the
`Load` type we added:
```julia
load_busses(net::AbstractNetwork) = (b for b in busses(net) if haskey(net[b], :Load))
```