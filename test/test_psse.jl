@testset "PSS/E adapter" begin
    fp = joinpath(@__DIR__, "data", "ieee118", "ieee118.RAW")
    lines = readlines(fp)
    bus_kv, source_bus = CommonOPF.psse_bus_data(lines)
    cds = CommonOPF.psse_branch_data(lines, bus_kv)
    trs = CommonOPF.psse_transformer_data(lines, bus_kv)
    @test length(cds) > 0
    @test length(trs) > 0
    first_cond = first(cds)
    @test isapprox(first_cond[:r1], 0.03030 * (138^2 / 100); atol=1e-6)
    @test isapprox(first_cond[:x1], 0.09990 * (138^2 / 100); atol=1e-6)
    first_tr = first(trs)
    @test isapprox(first_tr[:reactance], 0.02670 * (138^2 / 100); atol=1e-6)

    net = CommonOPF.psse_to_Network(fp; allow_parallel_conductor=true)
    @test net.substation_bus == "69"
    @test length(conductors(net)) == length(cds)
    @test net["1"][:Load].kws1 == [17000.0]
    @test net["1"][:Generator].mva_base == 100.0
    @test isapprox(net["5"][:ShuntAdmittance].b, -40e6 / (138e3^2); atol=1e-6)

    loads = CommonOPF.psse_load_data(lines)
    @test loads[1][:bus] == "1"
    @test loads[1][:kws1] == [17000.0]

    gens = CommonOPF.psse_generator_data(lines, bus_kv)
    @test gens[1][:bus] == "1"
    @test ismissing(gens[1][:reg_bus])
    @test gens[1][:mva_base] == 100.0
    shunts = CommonOPF.psse_shunt_data(lines, bus_kv)
    @test shunts[1][:bus] == "5"
    @test isapprox(shunts[1][:b], -40e6 / (138e3^2); atol=1e-6)

    # test that version != 33 throws error
    lines = readlines(fp)
    parts = split(lines[1], ",")
    parts[3] = " 34"
    lines[1] = join(parts, ",")
    @test_throws ArgumentError CommonOPF.psse_branch_data(lines, bus_kv)
end
