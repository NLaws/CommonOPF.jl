# Edge Impedances and Admittances
CommonOPF exports methods to get the real-valued resistance and reactance of `Network` edges,
as well as the complex-valued impedance. If the `Network` is `SinglePhase` then scalar values are
returned; if the `Network` is `MultiPhase` then matrix values are returned. 

## Impedance
```@docs
rij
rij_per_unit

xij
xij_per_unit

zij
zij_per_unit
```


## Admittance
```@docs
gij
gij_per_unit

bij
bij_per_unit

yij
yij_per_unit
```

# Bus Admittance Matrix
The convention in CommonOPF is upper case `Y` for the bus admittance matrix methods:
```@docs
Yij
Yij_per_unit
Ysparse
```

# Shunt Admittance
Network specification yaml files can include bus admittance values like:
```yaml
ShuntAdmittance:
  - bus: 1
    g: 0
    b: 0.0011
```
The admittances will be stored in the `Network` bus data and can be retrieved using the `yj`
methods:
```@docs
yj
```