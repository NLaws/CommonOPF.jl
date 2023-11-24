# Network Model
The `Network` struct in CommonOPF is used to abstract the power system network into the components
required to create power flow and optimal power flow models. Underlying the Network model is a
`MetaGraphsNext.MetaGraph` that stores the edge and node data in the network. 

## Edges
The edges of the Network model include all power transfer elements, i.e. the devices in the power 
system that move power from one place to another and therefore have two or more busses.
Edges include:
- conductors

Within the network model edges are indexed via two-tuples of bus names (strings) like
```julia
using CommonOPF
# TODO code that runs using a test file
net = Network("yaml/filepath")
bus = collect(busses(net))[1]
net[bus]
```

### Conductors
Conductors are specified via two busses, the **impedance in ohms per-unit length**, and a length value.
```yaml
conductors:
  - busses: 
    - b1
    - b2
    r0: 0.1
    x0: 0.1
    length: 100
```
A conductor can also leverage a `template`, i.e. another conductor with a `name` that matches the `template` value so that we can re-use the impedance values:
```yaml
conductors:
  - name: cond1
    busses: 
    - b1
    - b2
    r0: 0.1
    x0: 0.1
    length: 100
  - busses:
    - b2
    - b3
    template: cond1
    length: 200
```
The second conductor in the `conductors` above will use the `r0` and `x0` values from `cond1`, scaled by the `length` of 200 and normalized by `Zbase`.

!!! note
    The `name` field is optional unless a `conductor.name` is also the `template` of another conductor.


## Graph Nodes
The abstract node in the graph model is really an electrical bus. In single phase models a bus and a node
are synonymous. However, in multi-phase models we can think of each bus have multiple nodes, or terminals,
where each phase-wire connects. Busses are implicitly specified in the `busses` of the edge specifications.