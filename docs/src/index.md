# CommonOPF.jl

Documentation for CommonOPF.jl a module of shared scaffolding and methods for:
- [BranchFlowModel](https://github.com/NLaws/BranchFlowModel.jl)
- [LinDistFlow](https://github.com/NLaws/LinDistFlow)
- [LinearPowerFlow](https://github.com/NLaws/LinearPowerFlow.jl)

In most cases you will not need to use CommonOPF because the libraries above will export the
CommonOPF things that you need to use them. The most import part of CommonOPF is the [Network Model](@ref)
and how to specify inputs to all of the above libraries. See [Input Formats](@ref) for more.

The primary work flow for CommonOPF is:
1. User inputs (in JSON, YAML, or Dict) or passed to a `Network` builder.
2. The `Network` is used to build a power flow model in JuMP, using methods like `busses(net::Network)`
3. The JuMP model is solved
4. The model and network are passed to `opf_results` to get results in a dictionary like the
   variable containers in the JuMP model