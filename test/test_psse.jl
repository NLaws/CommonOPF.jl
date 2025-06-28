@testset "PSS/E adapter" begin
    fp = joinpath(@__DIR__, "data", "ieee118.RAW")
    cds, trs = CommonOPF.psse_to_network_dicts(fp)
    @test length(cds) > 0
    @test length(trs) > 0
    first_cond = first(cds)
    @test isapprox(first_cond[:r1], 0.03030 * (138^2 / 100); atol=1e-6)
    @test isapprox(first_cond[:x1], 0.09990 * (138^2 / 100); atol=1e-6)
    first_tr = first(trs)
    @test isapprox(first_tr[:reactance], 0.02670 * (138^2 / 100); atol=1e-6)

    loads = CommonOPF.ieee118_load_data(fp)
    @test loads[1][:bus] == "1"
    @test loads[1][:kws1] == [17000.0]

    gens = CommonOPF.ieee118_generator_data(fp)
    @test gens[1][:bus] == "1"
    @test gens[1][:mva_base] == 100.0

    lines = readlines(fp)
    parts = split(lines[1], ",")
    parts[3] = " 34"
    temp = tempname()
    open(temp, "w") do io
        println(io, join(parts, ","))
        for ln in lines[2:end]
            println(io, ln)
        end
    end
    @test_throws ArgumentError CommonOPF.psse_to_network_dicts(temp)
end
