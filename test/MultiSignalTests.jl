using PhysiCellXMLRules, Test
using PhysiCellXMLRules: rawSignalNames, _doseResponse2D

const _MULTI_FIXTURE = joinpath(@__DIR__, "assets", "multi_signal_rules.xml")

@testset "multi_signal_rules.xml — parses + validates clean" begin
    rulesets = parseRulesXML(_MULTI_FIXTURE)
    @test length(rulesets) == 2
    by = Dict(rs.cell_type => rs for rs in rulesets)

    # First ruleset: two signals on the increasing branch.
    b1 = by["oxygen_and_low_pressure"].behaviors[1]
    @test rawSignalNames(b1) == ["oxygen", "pressure"]
    @test b1.signal.increasing_signal.aggregator == "product"

    # Second ruleset: one signal per branch.
    b2 = by["oxygen_up_damage_down"].behaviors[1]
    @test sort(rawSignalNames(b2)) == ["damage", "oxygen"]

    @test isvalid(validateRulesXML(_MULTI_FIXTURE))
end

@testset "_doseResponse2D — oxygen × pressure AND-logic" begin
    rulesets = parseRulesXML(_MULTI_FIXTURE)
    by = Dict(rs.cell_type => rs for rs in rulesets)
    b = by["oxygen_and_low_pressure"].behaviors[1]
    xs, ys, zs = _doseResponse2D(b; vary=("oxygen","pressure"),
                                 signal_ranges=Dict("oxygen"=>(0.0,40.0),
                                                    "pressure"=>(0.0,1.0)),
                                 n=21)
    @test size(zs) == (21, 21)
    # High oxygen, zero pressure → both Hill terms ≈ 1, product ≈ 1, mediator
    # decreasing_dominant with no decreasing branch: D=0, U≈1 → b_+ = 1.
    z_hi = zs[findfirst(==(0.0), ys), findfirst(==(40.0), xs)]
    @test z_hi > 0.9
    # High pressure (≥ ref=1.0) → pressure Hill → 0 → product = 0 → output base = 0.
    z_lo = zs[findfirst(==(1.0), ys), findfirst(==(40.0), xs)]
    @test z_lo ≈ 0.0 atol=1e-6
end

@testset "exportInteractiveHTML — multi-signal fixture" begin
    path = joinpath(@__DIR__, "multi_signal_explorer.html")
    exportInteractiveHTML(path, _MULTI_FIXTURE; force=true)
    html = read(path, String)
    @test occursin("oxygen_and_low_pressure", html)
    @test occursin("\"name\":\"oxygen\"", html)
    @test occursin("\"name\":\"pressure\"", html)
    @test occursin("\"name\":\"damage\"", html)
end
