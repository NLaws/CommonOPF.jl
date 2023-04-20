# CommonOPF.jl

Documentation for CommonOPF.jl a module of shared scaffolding and methods for:
- [BranchFlowModel](https://github.com/NLaws/BranchFlowModel.jl)
- [LinDistFlow](https://github.com/NLaws/LinDistFlow)
- [LinearPowerFlow](https://github.com/NLaws/LinearPowerFlow.jl)

The common methods and types are organized into categories by files:
1. io.jl contains methods for parsing OpenDSS models into `Inputs`
2. inputs.jl contains the `Inputs` constructor methods and the `Inputs` struct 
3. graphs.jl contains methods for making and analyzing directed graph models of the power systems
4. types.jl contains abstract types and concrete type templates
5. utils.jl contains supporting functions for building models from `Inputs`