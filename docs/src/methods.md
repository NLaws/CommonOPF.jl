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
trim_tree!
trim_tree_once!
```

# Edge Impedances
```@docs
resistance
resistance_per_length
rij
rij_per_unit

xij
zij
```
