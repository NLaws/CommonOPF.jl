"""
    struct VariableBounds

Limits for decision variables in mathematical programs. Upper and lower values can be specified for
power, current, and voltage variables. The `VariableBounds` struct is attached to `Network.bounds`
upon creation of the `Network`. Default values are set using `Sbase` and `Vbase` as follows:
```julia
v_upper = 2.0 * Vbase
v_lower = 0.0

s_upper =  1.1 * Sbase
s_lower = -1.1 * Sbase

i_upper =  1.5 * Sbase / Vbase
i_lower = -1.5 * Sbase / Vbase
```
"""
mutable struct VariableBounds
    s_upper::Real
    s_lower::Real
    v_upper::Real
    v_lower::Real
    i_upper::Real
    i_lower::Real
end


"""
    function VariableBounds(ntwk::Dict)

Check for the keys of the `VariableBounds` struct in the `ntwk` dictionary; otherwise fill in
default values as described in [`VariableBounds`](@ref).
"""
function VariableBounds(ntwk::Dict)
    Sbase = get(ntwk, :Sbase, SBASE_DEFAULT)
    Vbase = get(ntwk, :Vbase, VBASE_DEFAULT)

    s_upper = get(ntwk, :s_upper,  1.1 * Sbase)
    s_lower = get(ntwk, :s_lower, -1.1 * Sbase)
    v_upper = get(ntwk, :v_upper,  1.1 * Vbase)
    v_lower = get(ntwk, :v_lower, -1.1 * Vbase)
    i_upper = get(ntwk, :i_upper,  1.5 * Sbase / Vbase)
    i_lower = get(ntwk, :i_lower, -1.5 * Sbase / Vbase)

    return VariableBounds(
        s_upper,
        s_lower,
        v_upper,
        v_lower,
        i_upper,
        i_lower
    )
end