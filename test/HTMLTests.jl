using PhysiCellXMLRules, Test

const _FIXTURE = joinpath(@__DIR__, "assets", "extended_cell_rules.xml")

@testset "exportInteractiveHTML — produces a file" begin
    path = joinpath(@__DIR__, "explorer_out.html")
    isfile(path) && rm(path)
    exportInteractiveHTML(path, _FIXTURE)
    @test isfile(path)
    html = read(path, String)
    # Header / template substitutions
    @test occursin("PhysiCell rule explorer", html)
    @test occursin("extended_cell_rules.xml", html)
    # CDN script
    @test occursin("cdn.plot.ly/plotly", html)
    # Each cell_type in the fixture should appear in the JSON dump
    for ct in ("increasing_partial_hill", "tent", "accumulator", "custom_mediator")
        @test occursin("\"cell_type\":\"$ct\"", html)
    end
    # Transformer + reference round-trip into JSON
    @test occursin("\"transformer\":\"partial_hill\"", html)
    @test occursin("\"reference\":{", html)
    # Custom mediator/aggregator survive into JSON
    @test occursin("\"name\":\"custom\"", html) ||
          occursin("\"aggregator\":\"custom\"", html)
    # No placeholders should remain unsubstituted
    @test !occursin("{{TITLE}}", html)
    @test !occursin("{{RULES_JSON}}", html)
end

@testset "exportInteractiveHTML — accepts a pre-parsed Vector{BehaviorRuleset}" begin
    rulesets = parseRulesXML(_FIXTURE)
    path = joinpath(@__DIR__, "explorer_out2.html")
    isfile(path) && rm(path)
    exportInteractiveHTML(path, rulesets; title="my explorer")
    @test isfile(path)
    html = read(path, String)
    @test occursin("my explorer", html)
end

@testset "exportInteractiveHTML — refuses to clobber without force" begin
    path = joinpath(@__DIR__, "explorer_out.html")
    @test isfile(path)
    @test_throws AssertionError exportInteractiveHTML(path, _FIXTURE)
    exportInteractiveHTML(path, _FIXTURE; force=true)
    @test isfile(path)
end

@testset "exportInteractiveHTML — bad path extension" begin
    @test_throws AssertionError exportInteractiveHTML(
        joinpath(@__DIR__, "bad.txt"), _FIXTURE)
end

@testset "exportInteractiveHTML — Save XML plumbing present" begin
    path = joinpath(@__DIR__, "explorer_save_test.html")
    exportInteractiveHTML(path, _FIXTURE; force=true)
    html = read(path, String)
    @test occursin("id=\"save-btn\"", html)
    @test occursin("rulesToXML", html)
    @test occursin("downloadXML", html)
end
