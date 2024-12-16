"""
    dss_voltages_pu()

return a dict with bus-name keys and per-unit voltages for each phase at each bus.
"""
function dss_voltages_pu()::Dict
    d = Dict()
    for b in OpenDSS.Circuit.AllBusNames() 
        OpenDSS.Circuit.SetActiveBus(b)
        d[b] = OpenDSS.Bus.puVmagAngle()[1:2:end]
    end
    return d
end


"""
    check_opendss_powers(;tol=1e-6)

Return bool for whether or not the load powers match the solution powers In other words, confirm hat the
constant power model was used in the solution. OpenDSS will automatically (and silently) change the
load models when solving if voltages go outside of bounds (that can be set on the Load objects).
"""
function check_opendss_powers(;tol=1e-6)::bool

    elements = OpenDSS.Circuit.AllElementNames()

    for element in elements
        # Set the active element
        if !startswith(element, "Load")
            continue
        end
        OpenDSS.Circuit.SetActiveElement(element)
        
        # Get the bus name where the element is connected
        bus_name = OpenDSS.CktElement.BusNames()[1]  # Get the first bus name
        
        # Get the power in kW and kvar
        power = OpenDSS.CktElement.TotalPowers()  # Returns power in kW and kvar for each phase

        load_name = string(split(element, ".")[2])
        OpenDSS.Loads.Name(load_name)
        
        p_mismatch = real(power)[1] - OpenDSS.Loads.kW()
        q_mismatch = imag(power)[1] - OpenDSS.Loads.kvar()

        if abs(p_mismatch) > tol
            return false
        end
        if abs(q_mismatch) > tol
            return false
        end
    end

    return true
end