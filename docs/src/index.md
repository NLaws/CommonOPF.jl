# CommonOPF.jl

Documentation for CommonOPF.jl a module of shared scaffolding and methods for:
- [BranchFlowModel](https://github.com/NLaws/BranchFlowModel.jl)
- [LinDistFlow](https://github.com/NLaws/LinDistFlow)
- [LinearPowerFlow](https://github.com/NLaws/LinearPowerFlow.jl)

In most cases you will not need to use CommonOPF because the libraries above will export the
CommonOPF things that you need to use them. The most import part of CommonOPF is the [Network Model](@ref)
and how to specify inputs to all of the above libraries. See [Input Formats](@ref) for more.