# CommonOPF Change log

## dev
- add `Ysparse` for bus admittance matrix from `Network`
    - use new `BusTerminal` and `EdgeTerminals` structs for building `Ysparse`
- change `Yij`: no longer return 3x3 matrix always: it returns only valid phases
- stop exporting `sj` method
- change `sj_per_unit(j::String, net::Network{MultiPhase})` to return complex values
- change `ConstraintInfo.set_type::MOI.AbstractSet` -> `ConstraintInfo.set_type::DataType`
- add `Units.RadiansUnit`

## v0.4.7
Changes to support documentation in BranchFlowModel.jl (eventually BusInjectionModel.jl too)
- add `print_var_info` using PrettyTables to show `VariableInfo` with `fieldnames` as the header
- refactor `VarInfo` -> `VariableInfo`
- add `ConstraintInfo` and `print_constraint_info`
- add `RealReactiveDimension`

## v0.4.6
- add fixed `Capacitor` model
- add `MissingEdge` type and use it for zero admittance and infinite impedance
- add `Network.var_info` for documenting model variables

## v0.4.5
- add `phases_out_of_bus` and `phases_connected_to_bus` methods
- add some model building support methods that are shared in BusInjectionModel and BranchFlowModel
    - such as `sj_per_unit` for `Network{MultiPhase}`
- support for multiphase BIM (with rectangular voltage)

## v0.4.4
- add `Generator <: AbstractBus` struct for P-V busses in BusInjectionModel.jl
- add `Yij_per_unit` and `Yij` admittance matrix getters
- add `sj(j, net)`, and `sj_per_unit` power getters
- add `connected_busses(n, net)`
- make it so `Network[(bus1, bus2)]` _and_ `Network[(bus2, bus1)]` return the edge struct

## v0.4.3
- fix OpenDSSDirect.jl at v0.9.9 because v0.9.8 has some issues

## v0.4.2 
- add src/edges/admittances.jl with `conductance`, `susceptance`, `bij`, `gij`, `yij`, and more methods.
- add `multiphase_variable_container` methods for bus and edge variables
    - make variable indexing order consistent across single and multiphase models (bus/edge, time,
      phase)
- rm `VariableContainer` and `Network.var_name_map`
- add `Network.var_names` and `opf_results`

## v0.4.1
- add codecov to ci
- more documentation, tests, and port some decomposition methods from BranchFlowModel.jl
- improve OpenDSS -> `Network` parsing
- expand `Network{MultiPhase}` support (for BranchFlowModel.jl)
- add `VariableBounds`
- add `VoltageRegulator`, `Capacitor`, and `ShuntAdmittance` as a new bus inputs
- add `VariableContainer = Dict{Int, Dict{String, Any}}` and `VARIABLE_NAMES`
- add `Network.var_name_map` for parsing results
- rm all `Inputs` associated stuff

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