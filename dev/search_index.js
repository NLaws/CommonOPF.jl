var documenterSearchIndex = {"docs":
[{"location":"results/#Results","page":"Results","title":"Results","text":"","category":"section"},{"location":"results/","page":"Results","title":"Results","text":"If a sub-library uses the CommonOPF.VARIABLE_NAMES then CommonOPF.Results can be used to get all the variable values from a solved JuMP.Model. The VARIABLE_NAMES are:","category":"page"},{"location":"results/","page":"Results","title":"Results","text":"using CommonOPF\nfor var_name in CommonOPF.VARIABLE_NAMES\n    println(var_name)\nend","category":"page"},{"location":"results/","page":"Results","title":"Results","text":"TODO examples","category":"page"},{"location":"impedances/#Edge-Impedances","page":"Edge Impedances","title":"Edge Impedances","text":"","category":"section"},{"location":"impedances/","page":"Edge Impedances","title":"Edge Impedances","text":"resistance\nresistance_per_length\nrij\nrij_per_unit\n\nxij\nxij_per_unit\n\nzij","category":"page"},{"location":"impedances/#CommonOPF.resistance","page":"Edge Impedances","title":"CommonOPF.resistance","text":"resistance(e::AbstractEdge) = 0.0\n\n\n\n\n\nresistance(c::Conductor)\n\nresistance_per_length(c) * c.length\n\nThe absolute resistance of the conductor (in the units provided by the user)\n\n\n\n\n\nresistance(vr::VoltageRegulator)\n\nvr.resistance\n\n\n\n\n\n","category":"function"},{"location":"impedances/#CommonOPF.resistance_per_length","page":"Edge Impedances","title":"CommonOPF.resistance_per_length","text":"resistance_per_length(e::AbstractEdge) = 0.0\n\n\n\n\n\nresistance_per_length(c::Conductor)\n\nif ismissing(c.phases)  # single phase\n    return c.r1\nend\nreturn c.rmatrix\n\n\n\n\n\n","category":"function"},{"location":"impedances/#CommonOPF.rij","page":"Edge Impedances","title":"CommonOPF.rij","text":"rij(i::AbstractString, j::AbstractString, net::Network)\n\nresistance(net[(i,j)])\n\nResistance of edge i-j\n\n\n\n\n\n","category":"function"},{"location":"impedances/#CommonOPF.rij_per_unit","page":"Edge Impedances","title":"CommonOPF.rij_per_unit","text":"rij_per_unit(i::AbstractString, j::AbstractString, net::Network)\n\nresistance(net[(i,j)]) / net.Zbase\n\nResistance of edge i-j normalized by net.Zbase\n\n\n\n\n\n","category":"function"},{"location":"impedances/#CommonOPF.xij","page":"Edge Impedances","title":"CommonOPF.xij","text":"xij(i::AbstractString, j::AbstractString, net::Network)\n\nReactance of edge i-j\n\n\n\n\n\n","category":"function"},{"location":"impedances/#CommonOPF.xij_per_unit","page":"Edge Impedances","title":"CommonOPF.xij_per_unit","text":"xij_per_unit(i::AbstractString, j::AbstractString, net::Network)\n\nReactance of edge i-j normalized by net.Zbase\n\n\n\n\n\n","category":"function"},{"location":"impedances/#CommonOPF.zij","page":"Edge Impedances","title":"CommonOPF.zij","text":"function zij(i::AbstractString, j::AbstractString, net::Network{SinglePhase})::Tuple{Real, Real}\n\nImpedance for single phase models. \n\nReturns (r1, x1) * length / net.Zbase for the Conductor at net[(i, j)].\n\nTODO convert impedance methods to dispatch on edge type TODO MultiPhase\n\n\n\n\n\n","category":"function"},{"location":"developer/#Creating-a-Network","page":"Developer","title":"Creating a Network","text":"","category":"section"},{"location":"developer/","page":"Developer","title":"Developer","text":"The Network struct is used to build models in BranchFlowModel.jl, LoadFlow.jl, and LinDistFlow.jl. CommonOPF.jl parses input files into a Dict{Symbol, Vector{Dict}} for each input type. Input types all subtype either CommonOPF.AbstractEdge or CommonOPF.AbstractBus. Concrete edge and bus models/structs get stored in Network.graph, which is a subtype of MetaGraphsNext.AbstractGraph. One can then easily extend MetaGraphsNext and Graphs methods using the Network.graph like so:","category":"page"},{"location":"developer/","page":"Developer","title":"Developer","text":"Graphs.edges(net::AbstractNetwork) = MetaGraphsNext.edge_labels(net.graph)","category":"page"},{"location":"developer/","page":"Developer","title":"Developer","text":"Each edge of the Network.graph stores one concrete subtype of AbstractEdge. The busses can store multiple subtypes of AbstractBus. ","category":"page"},{"location":"developer/#Adding-a-Bus-device","page":"Developer","title":"Adding a Bus device","text":"","category":"section"},{"location":"developer/","page":"Developer","title":"Developer","text":"The current Bus devices are:","category":"page"},{"location":"developer/","page":"Developer","title":"Developer","text":"using CommonOPF # hide\nimport InteractiveUtils: subtypes\n\nsubtypes(CommonOPF.AbstractBus)","category":"page"},{"location":"developer/","page":"Developer","title":"Developer","text":"To add a new Bus device:","category":"page"},{"location":"developer/","page":"Developer","title":"Developer","text":"create YourType that has at a minimum:  julia  @with_kw struct YourType <: AbstractBus      bus::String  end\nany required fields should have no default\nany optional fields should have default of missing\nOPTIONALLY define a check_busses!(busses::AbstractVector{YourType}) method\ncheck_busses! is used in the Network builder after unpacking user input dicts into YourType constructor","category":"page"},{"location":"developer/","page":"Developer","title":"Developer","text":"CommonOPF.check_busses!","category":"page"},{"location":"developer/#CommonOPF.check_busses!","page":"Developer","title":"CommonOPF.check_busses!","text":"check_busses!(busses::AbstractVector{<:AbstractBus}) = nothing\n\nThe default action after build_busses.\n\n\n\n\n\ncheck_busses!(loads::AbstractVector{Load})\n\nRemove (and warn about it) if any Load have no way to define the loads\n\n\n\n\n\n","category":"function"},{"location":"developer/","page":"Developer","title":"Developer","text":"Ensure compatibility with the MetaGraph\nmake sure the AbstractVector{YourType} returned from your constructor is compatible with fill_node_attributes!.","category":"page"},{"location":"developer/","page":"Developer","title":"Developer","text":"CommonOPF.fill_node_attributes!","category":"page"},{"location":"developer/#CommonOPF.fill_node_attributes!","page":"Developer","title":"CommonOPF.fill_node_attributes!","text":"fill_node_attributes!(g::MetaGraphsNext.AbstractGraph, vals::AbstractVector{<:AbstractBus})\n\nFor each concrete bus in vals store a dict of key,val pairs for the bus attributes in a symbol key like :Load for CommonOPF.Load TODO just store the type\n\n\n\n\n\n","category":"function"},{"location":"developer/","page":"Developer","title":"Developer","text":"The fill_{edge,node}_attributes! methods are used in the Network builder to store all the attributes of YourType in the Network.graph.  The Network.graph is used to build the power flow models – so you also will probably need to modify BranchFlowModel.jl to account for your new type. (But in the future we might be able to handle abstract edge or bus models that implement a certain set of attributes).","category":"page"},{"location":"developer/","page":"Developer","title":"Developer","text":"You might also want to extend the Network interface for your type. For example, when adding the Load type we added a load buss getter like so:","category":"page"},{"location":"developer/","page":"Developer","title":"Developer","text":"load_busses(net::AbstractNetwork) = (b for b in busses(net) if haskey(net[b], :Load))","category":"page"},{"location":"developer/#Adding-an-Edge-device","page":"Developer","title":"Adding an Edge device","text":"","category":"section"},{"location":"developer/","page":"Developer","title":"Developer","text":"The current Edge devices are:","category":"page"},{"location":"developer/","page":"Developer","title":"Developer","text":"using CommonOPF # hide\nimport InteractiveUtils: subtypes # hide\n\nsubtypes(CommonOPF.AbstractEdge)","category":"page"},{"location":"developer/","page":"Developer","title":"Developer","text":"To add a new Edge device:","category":"page"},{"location":"developer/","page":"Developer","title":"Developer","text":"create YourType that has at a minimum:  julia  @with_kw mutable struct YourType <: AbstractEdge      busses::Tuple{String, String}      phases::Union{Vector{Int}, Missing} = missing      rmatrix::Union{AbstractArray, Missing} = missing      xmatrix::Union{AbstractArray, Missing} = missing  end  For multiphase models each subtype of AbstractEdge must have rmatrix and xmatrix  properties. If you also specify resistance and reactance fields then you can take advantage  of validate_multiphase_edges! for your type. (Note that Conductor is a special case because  we permit specification of the sequence impedances.)\ndefine methods that dispatch on your type like\nresistance(your_edge::YourType)\nreactance(your_edge::YourType)\nOPTIONALLY define a check_edges!(edges::AbstractVector{YourType}) method\ncheck_edges! is used in the Network builder after unpacking user input dicts into YourType constructor","category":"page"},{"location":"developer/","page":"Developer","title":"Developer","text":"CommonOPF.check_edges!","category":"page"},{"location":"developer/#CommonOPF.check_edges!","page":"Developer","title":"CommonOPF.check_edges!","text":"check_edges!(edges::AbstractVector{<:AbstractEdge}) = nothing\n\nThe default action after build_edges.\n\n\n\n\n\ncheck_edges!(conductors::AbstractVector{Conductor})\n\nif all phases are missing then     - warn_singlephase_conductors_and_copy_templates(conductors) else     - validate_multiphase_edges!(conductors)\n\n\n\n\n\ncheck_edges!(transformers::AbstractVector{Transformer})\n\nfill in rmatrix and xmatrix if phases is not missing. For now assuming zero mutual impedances.\n\n\n\n\n\ncheck_edges!(regulators::AbstractVector{VoltageRegulator})\n\nWarn if not missing both vregpu and turnratio and call validatemultiphaseedges! if any phases are not missing.\n\n\n\n\n\n","category":"function"},{"location":"developer/#JuMP-Model-Variables","page":"Developer","title":"JuMP Model Variables","text":"","category":"section"},{"location":"developer/","page":"Developer","title":"Developer","text":"CommonOPF provides some patterns for storing variables so that we can provide common functionality across power flow models. Currently the main functionality that relies on variable access-patterns is Results. Note that you do not have to use the CommonOPF variable access patterns to use the Network model and other methods like the graph analysis stuff.","category":"page"},{"location":"developer/#Variable-Names","page":"Developer","title":"Variable Names","text":"","category":"section"},{"location":"developer/","page":"Developer","title":"Developer","text":"The CommonOPF variable names are stored as strings in VARIABLE_NAMES:","category":"page"},{"location":"developer/","page":"Developer","title":"Developer","text":"using CommonOPF\nfor var_name in CommonOPF.VARIABLE_NAMES\n    println(var_name)\nend","category":"page"},{"location":"developer/","page":"Developer","title":"Developer","text":"By default the VARIABLE_NAMES are used to check for model variable values. Alternatively, one can fill in the Network.var_name_map to use custom variable names in the JuMP.Model. The var_name_map is keyed on the VARIABLE_NAMES and any value provided will be used to check for model variable values. For example:","category":"page"},{"location":"developer/","page":"Developer","title":"Developer","text":"my_network.var_name_map = Dict(\"voltage_magnitude_squared\" => :w)","category":"page"},{"location":"developer/","page":"Developer","title":"Developer","text":"will indicate to the CommonOPF.Results method to look in model[:w] for the \"voltage_magnitude_squared\" values.","category":"page"},{"location":"developer/#Variable-Containers","page":"Developer","title":"Variable Containers","text":"","category":"section"},{"location":"developer/","page":"Developer","title":"Developer","text":"CommonOPF provides a variable container pattern for the JuMP.Models built in the CommonOPF dependencies so that we can support common functionality, especially for retrieving results from solved models. The pattern is a Dict{String, Dict{Int, Any}} that has:","category":"page"},{"location":"developer/","page":"Developer","title":"Developer","text":"bus or edge labels first\nand integer time step keys second.","category":"page"},{"location":"developer/","page":"Developer","title":"Developer","text":"For example, a single-phase model that stores the \"net_real_power_injection\" variable in model[:p] will store the real power variable for bus \"b1\" in model[:p][\"b1\"][1]. ","category":"page"},{"location":"graph_methods/#Graphs","page":"Graphs","title":"Graphs","text":"","category":"section"},{"location":"graph_methods/","page":"Graphs","title":"Graphs","text":"Methods for using/analyzing the network model as a graph","category":"page"},{"location":"graph_methods/","page":"Graphs","title":"Graphs","text":"make_graph\nall_inneighbors\nall_outneighbors\nbusses_from_deepest_to_source\nbusses_with_multiple_inneighbors\nleaf_busses\nnext_bus_above_with_outdegree_more_than_one\npaths_between\ntrim_above_bus!\nvertices_from_deepest_to_source","category":"page"},{"location":"graph_methods/#CommonOPF.make_graph","page":"Graphs","title":"CommonOPF.make_graph","text":"make_graph(edges::AbstractVector{<:AbstractEdge};  directed::Union{Bool,Missing}=missing)\n\nreturn MetaGraph made up of the edges\n\nAlso the graph[:intbusmap] is created with the dicts for bus => int and int => bus (because Graphs.jl only works with integer nodes)\n\njulia> g[\"13\", :bus]\n10\n\njulia> g[13, :bus]\n\"24\"\n\njulia> get_prop(g, :int_bus_map)[13]\n\"24\"\n\n\n\n\n\n","category":"function"},{"location":"graph_methods/#CommonOPF.all_inneighbors","page":"Graphs","title":"CommonOPF.all_inneighbors","text":"all_inneighbors(g::MetaGraphsNext.MetaGraph, j::String, innies::Vector{String})\n\nA recursive function for finding all of the busses above bus j. Use like:\n\nbusses_above_j = all_inneighbors(g, j, Vector{String}())\n\n\n\n\n\n","category":"function"},{"location":"graph_methods/#CommonOPF.all_outneighbors","page":"Graphs","title":"CommonOPF.all_outneighbors","text":"all_outneighbors(g::MetaGraphsNext.MetaGraph, j::String, outies::Vector{String})\n\nA recursive function for finding all of the busses below bus j. Use like:\n\nbusses_above_j = all_outneighbors(g, j, Vector{String}())\n\n\n\n\n\n","category":"function"},{"location":"graph_methods/#CommonOPF.busses_from_deepest_to_source","page":"Graphs","title":"CommonOPF.busses_from_deepest_to_source","text":"busses_from_deepest_to_source(g::MetaGraphsNext.MetaGraph, source::String)\n\nreturn the busses and their integer depths in order from deepest from shallowest\n\n\n\n\n\n","category":"function"},{"location":"graph_methods/#CommonOPF.busses_with_multiple_inneighbors","page":"Graphs","title":"CommonOPF.busses_with_multiple_inneighbors","text":"busses_with_multiple_inneighbors(g::MetaGraphsNext.MetaGraph)\n\nFind all the busses in g with indegree > 1\n\n\n\n\n\n","category":"function"},{"location":"graph_methods/#CommonOPF.leaf_busses","page":"Graphs","title":"CommonOPF.leaf_busses","text":"leaf_busses(net::Network)\n\nreturns Vector{String} containing all of the leaf busses in net.graph\n\n\n\n\n\n","category":"function"},{"location":"graph_methods/#CommonOPF.next_bus_above_with_outdegree_more_than_one","page":"Graphs","title":"CommonOPF.next_bus_above_with_outdegree_more_than_one","text":"next_bus_above_with_outdegree_more_than_one(g::MetaGraphsNext.MetaGraph, b::String)\n\nFind the next bus above b with outdegree more than one. If none are found than nothing is returned. Throws an error if a bus with indegree > 1 is found above b.\n\n\n\n\n\n","category":"function"},{"location":"graph_methods/#CommonOPF.paths_between","page":"Graphs","title":"CommonOPF.paths_between","text":"paths_between(g::MetaGraphsNext.MetaGraph, b1::String, b2::String)::Vector{Vector{String}}\n\nReturns all the paths (as vectors of bus strings) between b1 and b2\n\n\n\n\n\n","category":"function"},{"location":"graph_methods/#CommonOPF.trim_above_bus!","page":"Graphs","title":"CommonOPF.trim_above_bus!","text":"trim_above_bus!(g::MetaGraphsNext.MetaGraph, bus::String)\n\nRemove all the busses and edges that are inneighbors (recursively) of bus\n\n\n\n\n\n","category":"function"},{"location":"graph_methods/#CommonOPF.vertices_from_deepest_to_source","page":"Graphs","title":"CommonOPF.vertices_from_deepest_to_source","text":"vertices_from_deepest_to_source(g::Graphs.AbstractGraph, source::Int64)\n\nreturns the integer vertices of g and their depths from the leafs to source\n\n\n\n\n\n","category":"function"},{"location":"inputs/#Input-Formats","page":"Inputs","title":"Input Formats","text":"","category":"section"},{"location":"inputs/","page":"Inputs","title":"Inputs","text":"CommmonOPF provides three ways to construct the Network Model model:","category":"page"},{"location":"inputs/","page":"Inputs","title":"Inputs","text":"YAML file(s)\nJSON file(s)\nJulia code (manual)","category":"page"},{"location":"inputs/","page":"Inputs","title":"Inputs","text":"Only Network and Conductor are required to build the Network. Note that the input keys are, singular, CamelCase words to align with the data type names. For example a single phase, single time step model looks like:","category":"page"},{"location":"inputs/","page":"Inputs","title":"Inputs","text":"Network:\n  substation_bus: b1\n\nConductor:\n  - name: cond1\n    busses: \n      - b1\n      - b2\n    r1: 0.301  # impedance has units of ohm/per-unit-length\n    x1: 0.627\n    length: 100\n  - busses:\n      - b2\n      - b3\n    template: cond1  # <- reuse impedance of cond1\n    length: 200\n\nLoad:\n  - bus: b2\n    kws1: \n      - 5.6  # you can specify more loads at each bus to add time steps\n    kvars1: \n      - 1.2\n  - bus: b3\n    kws1: \n      - 5.6\n    kvars1: \n      - 1.2","category":"page"},{"location":"inputs/#Conductor","page":"Inputs","title":"Conductor","text":"","category":"section"},{"location":"inputs/","page":"Inputs","title":"Inputs","text":"CommonOPF.Conductor","category":"page"},{"location":"inputs/#CommonOPF.Conductor","page":"Inputs","title":"CommonOPF.Conductor","text":"struct Conductor <: AbstractEdge\n\nInterface for conductors in a Network. Fieldnames can be provided via a YAML file, JSON file, or     populated manually. Conductors are specified via two busses, the impedance in ohms per-unit     length, and a length value. \n\nSingle phase models\n\nThe minimum inputs for a single phase conductor look like:\n\nConductor:\n  - busses: \n      - b1\n      - b2\n    r1: 0.1\n    x1: 0.1\n    length: 100\n\nNote that the order of the items in the YAML file does not matter.\n\nA conductor can also leverage a template, i.e. another conductor with a name that matches the template value so that we can re-use the impedance values:\n\nConductor:\n  - name: cond1\n    busses: \n      - b1\n      - b2\n    r1: 0.1\n    x1: 0.1\n    length: 100\n  - busses:\n      - b2\n      - b3\n    template: cond1\n    length: 200\n\nThe second conductor in the conductors above will use the r0 and x0 values from cond1, scaled by the length of 200 and normalized by Zbase.\n\nnote: Note\nThe name field is optional unless a conductor.name is also the template of another conductor.\n\nwarning: Warning\nIf any phases properties are set in the conductors then it is assumed that the model is  multi-phase.\n\nMulti-phase models\n\nMulti-phase conductors can be modeled as symmetrical or asymmetrical components. Similar to OpenDSS, line impedances can be specified via the zero and positive sequence impedances, (r0, x0) and (r1, x1) respectively; or via the lower-diagaonal portion of the phase-impedance matrix. \n\nUsing the Multi-phase models require specifing phases (and the zero and positive sequence impedances) like:\n\nConductor:\n  - busses: \n      - b1\n      - b2\n    phases:\n      - 2\n      - 3\n    r0: 0.766\n    x0: 1.944\n    r1: 0.301\n    x1: 0.627\n    length: 100\n\nWhen the sequence impedances are provided the phase-impedance matrix is determined using the math in Symmetrical Mutliphase Conductors.\n\nAlternatively one can specify the rmatrix and xmatrix like:\n\nConductor:\n  - busses: \n      - b1\n      - b2\n    phases:\n      - 1\n      - 3\n    rmatrix: \n      - [0.31]\n      - [0.15, 0.32]\n    xmatrix:\n      - [1.01]\n      - [0.5, 1.05]\n    length: 100\n\nwarning: Warning\nThe order of the phases is assumed to match the order of the rmatrix and xmatrix. For example using the example just above the 3x3 rmatrix looks like  031 0 015 0 0 0 015 0 032\n\n\n\n\n\n","category":"type"},{"location":"inputs/#Load","page":"Inputs","title":"Load","text":"","category":"section"},{"location":"inputs/","page":"Inputs","title":"Inputs","text":"CommonOPF.Load\nBase.getindex(net::Network, bus::String, kws_kvars::Symbol, phase::Int)","category":"page"},{"location":"inputs/#CommonOPF.Load","page":"Inputs","title":"CommonOPF.Load","text":"struct Load <: AbstractBus\n\nA Load input specifier, mapped from YAML, JSON, or manually populated.\n\nThe minimum required inputs include several options. All require a bus to place the load. For single phase models provide one of the following sets of values:\n\nbus, kws1\nbus, kws1, kvars1\nbus, kws1, q_to_p\nbus, csv \n\nwhere csv is a path to a two column CSV file with a single line header like \"kws1,kvars1\". If only bus and kws1 are provided then the reactive load will be zero in the power flow model.\n\nFor unbalanced multiphase models one must provide one of:\n\nbus, [kws1, kvars1], [kws2, kvars2], [kws3, kvars3] <– brackets imply optional pairs, depending on the phases at the load bus\nbus, csv\n\nwhere the csv has 2, 4, or 6 columns with a single line header like \"kws1,kvars1,kws2,kvars2,kws3,kvars3\" or \"kws2,kvars2,kws3,kvars3\".\n\nnote: Note\nThe kws and kvars inputs are plural because we always put the loads in vectors, even with one timestep. We do this so that the modeling packages that build on CommonOPF do not have to account for both scalar values and vector values.\n\nOnce the net::Network is defined a load can be accessed like:\n\nld_busses = collect(load_busses(net))\nlb = ld_busses[1]  # bus keys are strings in the network\nnet[lb, :kws, 1]  # last index is phase integer\n\n\n\n\n\n","category":"type"},{"location":"inputs/#Base.getindex-Tuple{Network, String, Symbol, Int64}","page":"Inputs","title":"Base.getindex","text":"function Base.getindex(net::Network, bus::String, kws_kvars::Symbol, phase::Int)\n\nLoad getter for Network. Use like:\n\nnet[\"busname\", :kws, 2]\n\nnet[\"busname\", :kvars, 3]\n\nThe second argument must be one of :kws or :kvars. The third arbument must be one of [1,2,3]. If the \"busname\" exists and has a :Load dict, but the load (e.g. :kvars2) is not defined then zeros(net.Ntimesteps) is returned.\n\n\n\n\n\n","category":"method"},{"location":"inputs/#ShuntAdmittance","page":"Inputs","title":"ShuntAdmittance","text":"","category":"section"},{"location":"inputs/","page":"Inputs","title":"Inputs","text":"CommonOPF.ShuntAdmittance","category":"page"},{"location":"inputs/#CommonOPF.ShuntAdmittance","page":"Inputs","title":"CommonOPF.ShuntAdmittance","text":"struct ShuntAdmittance <: AbstractBus\n\nRequired fields:\n\nbus::String\ng::Real conductance in siemens\nb::Real susceptance in siemens\n\n\n\n\n\n","category":"type"},{"location":"inputs/#Transformer","page":"Inputs","title":"Transformer","text":"","category":"section"},{"location":"inputs/","page":"Inputs","title":"Inputs","text":"CommonOPF.Transformer","category":"page"},{"location":"inputs/#CommonOPF.Transformer","page":"Inputs","title":"CommonOPF.Transformer","text":"@with_kw mutable struct Transformer <: AbstractEdge\n    # required values\n    busses::Tuple{String, String}\n    # optional values\n    high_kv::Real = 1.0\n    low_kv::Real = 1.0\n    phases::Union{Vector{Int}, Missing} = missing\n    reactance::Real = 0.0\n    resistance::Real = 0.0\nend\n\nnote: Note\nFor now the high_kv and low_kv values are only for reference. Throughout the modules that use CommonOPF we model in per-unit voltage. In the future we may add capability for scaling to absolute voltage in the future (in Results for example).\n\nWhen phases are not provided the model is assumed to be single phase.\n\nSeries impedance defaults to zero.\n\n\n\n\n\n","category":"type"},{"location":"inputs/#VoltageRegulator","page":"Inputs","title":"VoltageRegulator","text":"","category":"section"},{"location":"inputs/","page":"Inputs","title":"Inputs","text":"CommonOPF.VoltageRegulator","category":"page"},{"location":"inputs/#CommonOPF.VoltageRegulator","page":"Inputs","title":"CommonOPF.VoltageRegulator","text":"struct VoltageRegulator <: AbstractEdge\n    # required values\n    busses::Tuple{String, String}\n    # optional values\n    high_kv::Real = 1.0\n    low_kv::Real = 1.0\n    phases::Union{Vector{Int}, Missing} = missing\n    reactance::Real = 0.0\n    resistance::Real = 0.0\n    vreg_pu::Union{Real, Missing} = missing\n    turn_ratio::Union{Real, Missing} = missing\nend\n\nRequired fields:\n\nbusses::Tuple{String, String}\neither vreg_pu::Real or turn_ratio::Real\n\nIf vreg_pu is specified then the regulator is \"perfect\" and the second bus in busses is fixed to the value provided for vreg_pu.\n\nIf turn_ratio is provided then the voltage across the regulator is scaled by the turn_ratio.\n\nExamples:\n\nJulia Dict\n\nnetdict = Dict(\n    :network => Dict(:substation_bus => \"1\", :Sbase => 1),\n    :conductors => [\n        ...\n    ],\n    :voltage_regulators => [\n        Dict(\n            :busses => (\"2\", \"3\")\n            :vreg_pu => 1.05\n        )\n    ]\n)\n\nYAML file\n\nNetwork:\n  substation_bus: 0\n  Sbase: 1\n\nConductor:\n    ...\n\nVoltageRegulator:\n  busses: \n    - 2\n    - 3\n  vreg_pu: 1.05\n\n\n\n\n\n","category":"type"},{"location":"#CommonOPF.jl","page":"User Documentation","title":"CommonOPF.jl","text":"","category":"section"},{"location":"","page":"User Documentation","title":"User Documentation","text":"Documentation for CommonOPF.jl a module of shared scaffolding and methods for:","category":"page"},{"location":"","page":"User Documentation","title":"User Documentation","text":"BranchFlowModel\nLinDistFlow\nLinearPowerFlow","category":"page"},{"location":"","page":"User Documentation","title":"User Documentation","text":"In most cases you will not need to use CommonOPF because the libraries above will export the CommonOPF things that you need to use them. The most import part of CommonOPF is the Network Model and how to specify inputs to all of the above libraries. See Input Formats for more.","category":"page"},{"location":"","page":"User Documentation","title":"User Documentation","text":"The primary work flow for CommonOPF is:","category":"page"},{"location":"","page":"User Documentation","title":"User Documentation","text":"User inputs (in JSON, YAML, or Dict) or passed to a Network builder.\nThe Network is used to build a power flow model in JuMP, using methods like busses(net::Network)\nThe JuMP model is solved\nThe model and network are passed to CommonOPF.Results to produce a consistent results struct across the modeling libraries","category":"page"},{"location":"math/#Symmetrical-Mutliphase-Conductors","page":"Math","title":"Symmetrical Mutliphase Conductors","text":"","category":"section"},{"location":"math/","page":"Math","title":"Math","text":"Often we only have the zero and positive sequence impedances of conductors. In these cases we construct the phase impedance matrix as:","category":"page"},{"location":"math/","page":"Math","title":"Math","text":"z_abc = beginbmatrix \n        z_s    z_m   z_m \n        z_m    z_s   z_m \n        z_m    z_m   z_s  \nendbmatrix","category":"page"},{"location":"math/","page":"Math","title":"Math","text":"where","category":"page"},{"location":"math/","page":"Math","title":"Math","text":"beginaligned\nz_s = frac13 z_0 + frac23 z_1 \n\nz_m = frac13 (z_0- z_1)\nendaligned  ","category":"page"},{"location":"network/#Network-Model","page":"The Network Model","title":"Network Model","text":"","category":"section"},{"location":"network/","page":"The Network Model","title":"The Network Model","text":"Network\nNetwork(fp::String)\nNetwork(d::Dict)","category":"page"},{"location":"network/#CommonOPF.Network","page":"The Network Model","title":"CommonOPF.Network","text":"struct Network <: AbstractNetwork\n    graph::MetaGraphsNext.AbstractGraph\n    substation_bus::String\n    Sbase::Real\n    Vbase::Real\n    Zbase::Real\n    v0::Union{Real, AbstractVecOrMat{<:Number}}\n    Ntimesteps::Int\n    v_lolim::Real\n    v_uplim::Real\n    var_name_map::Dict{String, Any}\nend\n\nThe Network model is used to store all the inputs required to create power flow and optimal power flow models. Underlying the Network model is a MetaGraphsNext.MetaGraph that stores the edge and node data in the network. \n\nWe leverage the AbstractNetwork type to make an intuitive interface for the Network model. For example, edges(network) returns an iterator of edge tuples with bus name values; (but if we used Graphs.edges(MetaGraph) we would get an iterator of Graphs.SimpleGraphs.SimpleEdge with integer values).\n\nA Network can be created directly, via a Dict, or a filepath. The minimum inputs must have a vector of Conductor specifications and a Network key containing at least the substation_bus. See Input Formats for more details.\n\n\n\n\n\n","category":"type"},{"location":"network/#CommonOPF.Network-Tuple{String}","page":"The Network Model","title":"CommonOPF.Network","text":"function Network(fp::String)\n\nConstruct a Network from a yaml at the file path fp.\n\n\n\n\n\n","category":"method"},{"location":"network/#CommonOPF.Network-Tuple{Dict}","page":"The Network Model","title":"CommonOPF.Network","text":"function Network(d::Dict)\n\nConstruct a Network from a dictionary that has at least keys for:\n\n:Conductor, a vector of dicts with Conductor specs\n:Network, a dict with at least :substation_bus\n\n\n\n\n\n","category":"method"},{"location":"network/#Edges","page":"The Network Model","title":"Edges","text":"","category":"section"},{"location":"network/","page":"The Network Model","title":"The Network Model","text":"The edges of the Network model include all power transfer elements, i.e. the devices in the power system that move power from one place to another and therefore have two or more busses. Edges include:","category":"page"},{"location":"network/","page":"The Network Model","title":"The Network Model","text":"Conductor\nVoltageRegulator\nTransformer","category":"page"},{"location":"network/","page":"The Network Model","title":"The Network Model","text":"Within the network model edges are indexed via two-tuples of bus names like so:","category":"page"},{"location":"network/","page":"The Network Model","title":"The Network Model","text":"using CommonOPF\nnet = Network_IEEE13_SinglePhase()\nnet[(\"650\", \"632\")]","category":"page"},{"location":"network/#Nodes","page":"The Network Model","title":"Nodes","text":"","category":"section"},{"location":"network/","page":"The Network Model","title":"The Network Model","text":"The abstract node in the graph model is really an electrical bus. In single phase models a bus and a node are synonymous. However, in multi-phase models we can think of each bus have multiple nodes, or terminals, where each phase-wire connects. Busses are implicitly specified in the busses of the edge specifications.","category":"page"},{"location":"network/","page":"The Network Model","title":"The Network Model","text":"Nodes contain:","category":"page"},{"location":"network/","page":"The Network Model","title":"The Network Model","text":"Load\nShuntAdmittance\nVoltageRegulator","category":"page"},{"location":"network/","page":"The Network Model","title":"The Network Model","text":"Within the network model busses are indexed via bus names like so:","category":"page"},{"location":"network/","page":"The Network Model","title":"The Network Model","text":"using CommonOPF\nnet = Network_IEEE13_SinglePhase()\nnet[\"670\"]","category":"page"},{"location":"network/#Network-Reduction","page":"The Network Model","title":"Network Reduction","text":"","category":"section"},{"location":"network/","page":"The Network Model","title":"The Network Model","text":"A few convenience methods are provided in CommonOPF for reducing network complexity by removing intermediate busses and trimming branches that will not typically impact OPF results.","category":"page"},{"location":"network/","page":"The Network Model","title":"The Network Model","text":"remove_bus!(j::String, net::Network{SinglePhase})\nreduce_tree!(net::Network{SinglePhase})\ntrim_tree!\ntrim_tree_once!","category":"page"},{"location":"network/#CommonOPF.remove_bus!-Tuple{String, Network{SinglePhase}}","page":"The Network Model","title":"CommonOPF.remove_bus!","text":"remove_bus!(j::String, net::Network{SinglePhase})\n\nRemove bus j in the line i->j->k from the model by making an equivalent line from busses i->k\n\n\n\n\n\n","category":"method"},{"location":"network/#CommonOPF.reduce_tree!-Tuple{Network{SinglePhase}}","page":"The Network Model","title":"CommonOPF.reduce_tree!","text":"reduce_tree!(net::Network{SinglePhase})\n\ncombine any line sets with intermediate busses that have indegree == outdegree == 1 and is not a load bus into a single line\n\nSee remove_bus! for how the two lines are combined.\n\n\n\n\n\n","category":"method"},{"location":"network/#CommonOPF.trim_tree!","page":"The Network Model","title":"CommonOPF.trim_tree!","text":"trim_tree!(net::Network)\n\nTrim any branches that have empty busses, i.e. remove the branches that have no loads or DER.\n\n\n\n\n\n","category":"function"},{"location":"network/#CommonOPF.trim_tree_once!","page":"The Network Model","title":"CommonOPF.trim_tree_once!","text":"trim_tree_once!(net::Network)\n\nA support function for trim_tree!, trim_tree_once! removes all the empty leaf busses. When trimming the tree sometimes new leafs are created. So trim_tree! loops over trim_tree_once!.\n\n\n\n\n\n","category":"function"}]
}
