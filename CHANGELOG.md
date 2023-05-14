# CommonOPF Changelog

## v0.3.2
- add `Inputs.shunt_susceptance` dict with defaults of zero for all busses

## v0.3.1
- fix regulators for single phase openDSS models

## v0.3.0
-  `delete!(p.phases_into_bus, j)` in `delete_bus_j!`
- add phase index to regulators turn_ratio

## v0.2.2
- add `MultiPhaseVariableContainerType`
- add `reg_busses`, `turn_ratio`, `has_vreg`, `vreg`

## v0.2.1 
- fix `singlephase38linesInputs`
- add `trim_above_substation_bus=true` to `Inputs`