OVERHEAD_LINE_IMPEDANCES_BY_KV = Dict(
    115 => Dict(
        :construction => "SCSR",
        :R_ohm_per_km => 0.03,
        :X_ohm_per_km => 0.30,
        :B_microS_per_km => 4.0,
    ),
    230 => Dict(
        :construction => "DCDA",
        :R_ohm_per_km => 0.050,
        :X_ohm_per_km => 0.488,
        :B_microS_per_km => 3.371,
    ),
    345 => Dict(
        :construction => "QUAD",
        :R_ohm_per_km => 0.037,
        :X_ohm_per_km => 0.367,
        :B_microS_per_km => 4.518,
    ),
    500 => Dict(
        :construction => "QUAD",
        :R_ohm_per_km => 0.028,
        :X_ohm_per_km => 0.325,
        :B_microS_per_km => 5.200,
    ),
    765 => Dict(
        :construction => "QUAD",
        :R_ohm_per_km => 0.012,
        :X_ohm_per_km => 0.329,
        :B_microS_per_km => 4.978,
    ),
    1100 => Dict(
        :construction => "QUAD",
        :R_ohm_per_km => 0.005,
        :X_ohm_per_km => 0.292,
        :B_microS_per_km => 5.544,
    ),
)


function _check_kv_class(kv_class::Int)::Bool
    if !(kv_class in keys(OVERHEAD_LINE_IMPEDANCES_BY_KV))
        @warn """kv_class $kv_class not available in OVERHEAD_LINE_IMPEDANCES_BY_KV.
Choose from $(collect(keys(OVERHEAD_LINE_IMPEDANCES_BY_KV)))"""
        return false
    end
    return true
end