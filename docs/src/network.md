# Network Model
The `Network` model in CommonOPF is used to store all the inputs required to create power flow and
optimal power flow models. Underlying the Network model is a `MetaGraphsNext.MetaGraph` that stores
the edge and node data in the network. 

## Edges
The edges of the Network model include all power transfer elements, i.e. the devices in the power
system that move power from one place to another and therefore have two or more busses. Edges
include:
- [Conductors](@ref)

Within the network model edges are indexed via two-tuples of bus names (strings) like
```julia
using CommonOPF
# TODO code that runs using a test file
net = Network("yaml/filepath")
bus = collect(busses(net))[1]
net[bus]
```

## Nodes
The abstract node in the graph model is really an electrical bus. In single phase models a bus and a
node are synonymous. However, in multi-phase models we can think of each bus have multiple nodes, or
terminals, where each phase-wire connects. Busses are implicitly specified in the `busses` of the
edge specifications.

Nodes contain:
- [Loads](@ref)