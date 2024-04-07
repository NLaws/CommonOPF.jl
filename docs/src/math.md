
# Symmetrical Mutliphase Conductors
Often we only have the zero and positive sequence impedances of conductors. In these cases we
construct the phase impedance matrix as:
```math
z_{abc} = \begin{bmatrix} 
        z_s   & z_m  & z_m \\
        z_m   & z_s  & z_m \\
        z_m   & z_m  & z_s  
\end{bmatrix}
```
where
```math
\begin{aligned}
z_s &= \frac{1}{3} z_0 + \frac{2}{3} z_1 
\\
z_m &= \frac{1}{3} (z_0- z_1)
\end{aligned}  
```

# Kron Reduction
```@docs
kron_reduce
```