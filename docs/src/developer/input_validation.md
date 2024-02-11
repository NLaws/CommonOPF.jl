# Input validators and Network builders
```@docs
CommonOPF.format_input_dict
```

### Subtypes of `AbstractBus`
```@docs
CommonOPF.check_busses!
CommonOPF.fill_node_attributes!
```

### Subtypes of `AbstractEdge`
```@docs
CommonOPF.build_edges
CommonOPF.check_edges!
CommonOPF.fill_edges!
CommonOPF.fill_impedance_matrices!
CommonOPF.unpack_input_matrices!
CommonOPF.validate_multiphase_edges!
CommonOPF.warn_singlephase_conductors_and_copy_templates
```
