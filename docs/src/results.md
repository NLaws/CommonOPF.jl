# Results
If a sub-library uses the `CommonOPF.VARIABLE_NAMES` then `CommonOPF.Results` can be used to get all
the variable values from a solved `JuMP.Model`. The `VARIABLE_NAMES` are:
```@example
using CommonOPF
for var_name in CommonOPF.VARIABLE_NAMES
    println(var_name)
end
```

TODO examples