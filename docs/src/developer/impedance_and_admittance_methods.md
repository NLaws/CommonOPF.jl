# Impedance and Admittance Methods
CommonOPF exports edge impedance and admittance methods to support building optimal power flow
models (see [Edge Impedance and Admittance](@ref)). Internally, the exported methods are supported by methods that
dispatch on the edge types:
```@example
using CommonOPF # hide
import InteractiveUtils: subtypes # hide

subtypes(CommonOPF.AbstractEdge)
```
The internal methods began with those for `Conductor`:
```@docs
CommonOPF.resistance_per_length(c::CommonOPF.Conductor, phase_type::Type{T}) where {T <: CommonOPF.Phases}
```
Note that conductor resistance and reactance values are expected in per unit length values 
(since per unit length values are what one finds in engineering data sources).

Admittance values are derived using the inverse of the impedances:
```@docs
CommonOPF.conductance_per_length(c::CommonOPF.Conductor, phase_type::Type{T}) where {T <: CommonOPF.Phases}
```