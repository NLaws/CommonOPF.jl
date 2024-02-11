# CommonOPF Changelog

## dev
- add `VoltageRegulator` and `ShuntAdmittance` as a new bus inputs
- add `VariableContainer = Dict{Int, Dict{String, Any}}` and `VARIABLE_NAMES`
- add `Network.var_name_map` for parsing results

## v0.4.0
- change dependency MetaGraphs to MetaGraphsNext
- add `Network` (which will replace `Inputs` eventually)

## v0.3.8
- bug fix `reduce_tree!` with `Inputs{MultiPhase}`
    - mishandling of combined impedance matrices

## v0.3.7
- add `reduce_tree!` for `Inputs{MultiPhase}`

## v0.3.6
- add `remove_bus!` and `reduce_tree!` from BranchFlowModel (tested there)
- add `SinglePhase` `rij` and `xij` from BFM and LDF

## v0.3.5
- add `get_variable_values(var::Symbol, m::JuMP.AbstractModel, p::Inputs{SinglePhase}; digits=8)`
    - moved from BranchFlowModel and used in LinDistFlow v0.5

## v0.3.4
- `trim_tree!` compatible with Inputs (was only SinglePhase)

## v0.3.3
- add `leaf_busses` and `trim_tree!` (moved from BranchFlowModel)

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