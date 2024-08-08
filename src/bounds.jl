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
    s_upper_real::Union{Real, Missing}
    s_lower_real::Union{Real, Missing}
    s_upper_imag::Union{Real, Missing}
    s_lower_imag::Union{Real, Missing}
    
    v_upper_mag::Union{Real, Missing}
    v_lower_mag::Union{Real, Missing}

    i_upper_mag::Union{Real, Missing}
    i_lower_mag::Union{Real, Missing}
end


"""
    function VariableBounds(ntwk::Dict)

Check for the keys of the `VariableBounds` struct in the `ntwk` dictionary; otherwise fill in
default values as described in [`VariableBounds`](@ref).
"""
function VariableBounds(ntwk::Dict)
    s_upper_real = get(ntwk, :s_upper_real, missing)
    s_lower_real = get(ntwk, :s_lower_real, missing)
    s_upper_imag = get(ntwk, :s_upper_imag, missing)
    s_lower_imag = get(ntwk, :s_lower_imag, missing)

    v_upper_mag = get(ntwk, :v_upper_mag, missing)
    v_lower_mag = get(ntwk, :v_lower_mag, missing)

    i_upper_mag = get(ntwk, :i_upper_mag, missing)
    i_lower_mag = get(ntwk, :i_lower_mag, missing)

    return VariableBounds(
        s_upper_real,
        s_lower_real,
        s_upper_imag,
        s_lower_imag,

        v_upper_mag,
        v_lower_mag,

        i_upper_mag,
        i_lower_mag
    )
end