# Network Model
```@docs
Network
Network(fp::String)
Network(d::Dict)
```

## Edges
The edges of the Network model include all power transfer elements, i.e. the devices in the power
system that move power from one place to another and therefore have two or more busses. Edges
include:
- [Conductor](@ref)
- [VoltageRegulator](@ref)
- [Transformer](@ref)

Within the network model edges are indexed via two-tuples of bus names like so:
```@example
using CommonOPF
net = Network_IEEE13_SinglePhase()
net[("650", "632")]
```

## Nodes
The abstract node in the graph model is really an electrical bus. In single phase models a bus and a
node are synonymous. However, in multi-phase models we can think of each bus have multiple nodes, or
terminals, where each phase-wire connects. Busses are implicitly specified in the `busses` of the
edge specifications.

Nodes contain:
- [Load](@ref)
- [Capacitor](@ref)
- [ShuntAdmittance](@ref)

Within the network model busses are indexed via bus names like so:
```@example
using CommonOPF
net = Network_IEEE13_SinglePhase()
net["675"]
```

## Network Reduction
A few convenience methods are provided in `CommonOPF` for reducing network complexity by removing
intermediate busses and trimming branches that will not typically impact OPF results.
```@docs
remove_bus!(j::String, net::Network{SinglePhase})
reduce_tree!(net::Network{SinglePhase})
trim_tree!
trim_tree_once!
```