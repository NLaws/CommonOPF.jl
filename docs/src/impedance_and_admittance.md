# Edge Impedance and Admittance
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