# Graphs
Methods for using/analyzing the network model as a graph
```@docs
make_graph
leaf_busses
```
# IO methods


# Inputs
```@docs
remove_bus!(j::String, p::Inputs{SinglePhase})
remove_bus!(j::String, p::Inputs{MultiPhase})
reduce_tree!(p::Inputs{SinglePhase})
reduce_tree!(p::Inputs{MultiPhase})
```

# Types


# Utils
```@docs
trim_tree!
trim_tree_once!
rij(i::AbstractString, j::AbstractString, p::Inputs{SinglePhase})
xij(i::AbstractString, j::AbstractString, p::Inputs{SinglePhase})
zij
```