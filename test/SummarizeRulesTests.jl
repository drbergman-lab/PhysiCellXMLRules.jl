using PhysiCellXMLRules, Test

const _FIXTURE = joinpath(@__DIR__, "assets", "extended_cell_rules.xml")

@testset "summarizeRulesXML — fixture renders" begin
    io = IOBuffer()
    summarizeRulesXML(io, _FIXTURE)
    s = String(take!(io))
    @test occursin("cell_type: increasing_partial_hill", s)
    @test occursin("cell_type: accumulator", s)
    @test occursin("PartialHill(half_max=30.0", s)
    @test occursin("Linear(increasing", s)
    @test occursin("Heaviside(decreasing", s)
    @test occursin("mediator: custom", s)
    @test occursin("aggregator=custom", s)
    @test occursin("reference=decreasing from 60.0", s)
    @test occursin("accumulator", s)
    @test occursin("behavior_saturation=1.0", s)
end

@testset "summarizeRules — accepts pre-parsed input" begin
    rulesets = parseRulesXML(_FIXTURE)
    io = IOBuffer()
    summarizeRules(io, rulesets)
    @test !isempty(String(take!(io)))
end
