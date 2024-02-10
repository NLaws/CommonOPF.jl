# Graphs
Methods for using/analyzing the network model as a graph
```@docs
make_graph
leaf_busses
```
# IO methods


# Network
```@docs
remove_bus!(j::String, net::Network{SinglePhase})
reduce_tree!(net::Network{SinglePhase})
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