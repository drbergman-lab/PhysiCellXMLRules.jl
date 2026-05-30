using PhysiCellXMLRules, Test
# Internal helpers (not part of the public API) pulled in for white-box tests:
using PhysiCellXMLRules: evaluateSignal, evaluateMediator, evaluateAggregator,
                         elementarySignals, rawSignalNames, suggestSignalRange

const _FIXTURE = joinpath(@__DIR__, "assets", "extended_cell_rules.xml")

@testset "evaluateSignal — elementary transformers" begin
    # PartialHill at half_max returns 1 (un-Hill-mapped).
    s = PhysiCellXMLRules.PartialHillSignal("x", 2.0, 3.0, false)
    @test evaluateSignal(s, 2.0) ≈ 1.0
    @test evaluateSignal(s, 0.0) ≈ 0.0
    @test evaluateSignal(s, 4.0) ≈ 2.0^3.0  # (4/2)^3

    # Hill at half_max returns 0.5.
    h = PhysiCellXMLRules.HillSignal("x", 2.0, 3.0, false)
    @test evaluateSignal(h, 2.0) ≈ 0.5
    @test evaluateSignal(h, 0.0) ≈ 0.0
    @test evaluateSignal(h, 1e6) > 0.999

    # Identity.
    @test evaluateSignal(PhysiCellXMLRules.IdentitySignal("x", false), 3.7) ≈ 3.7

    # Linear increasing.
    l = PhysiCellXMLRules.LinearSignal("x", 10.0, 20.0, false, "increasing")
    @test evaluateSignal(l, 10.0) ≈ 0.0
    @test evaluateSignal(l, 15.0) ≈ 0.5
    @test evaluateSignal(l, 20.0) ≈ 1.0
    @test evaluateSignal(l, 100.0) ≈ 1.0  # clamped
    @test evaluateSignal(l, -5.0) ≈ 0.0   # clamped

    # Linear decreasing.
    ld = PhysiCellXMLRules.LinearSignal("x", 10.0, 20.0, false, "decreasing")
    @test evaluateSignal(ld, 10.0) ≈ 1.0
    @test evaluateSignal(ld, 20.0) ≈ 0.0

    # Heaviside.
    hev = PhysiCellXMLRules.HeavisideSignal("x", 30.0, false, "increasing")
    @test evaluateSignal(hev, 29.9) == 0.0
    @test evaluateSignal(hev, 30.0) == 1.0
    @test evaluateSignal(hev, 30.1) == 1.0

    hevd = PhysiCellXMLRules.HeavisideSignal("x", 30.0, false, "decreasing")
    @test evaluateSignal(hevd, 29.9) == 1.0
    @test evaluateSignal(hevd, 30.1) == 0.0
end

@testset "evaluateSignal — reference shifts" begin
    # Increasing reference: input becomes max(raw - s0, 0), γ becomes γ - s0.
    ref = PhysiCellXMLRules.SignalReference(20.0, "increasing")
    s = PhysiCellXMLRules.PartialHillSignal("x", 30.0, 2.0, false, ref)
    @test evaluateSignal(s, 10.0) ≈ 0.0  # raw < ref → shifted to 0
    @test evaluateSignal(s, 30.0) ≈ 1.0  # at half_max
    @test evaluateSignal(s, 40.0) ≈ ((40-20)/(30-20))^2

    # Decreasing reference.
    refd = PhysiCellXMLRules.SignalReference(60.0, "decreasing")
    sd = PhysiCellXMLRules.PartialHillSignal("x", 30.0, 2.0, false, refd)
    @test evaluateSignal(sd, 70.0) ≈ 0.0
    @test evaluateSignal(sd, 30.0) ≈ 1.0  # at half_max
end

@testset "evaluateMediator — known formulas" begin
    # Use sum aggregator so single-signal Heaviside passes through cleanly.
    s_dec = PhysiCellXMLRules.HeavisideSignal("a", 0.5, false, "increasing")
    s_inc = PhysiCellXMLRules.HeavisideSignal("b", 0.5, false, "increasing")
    dec_agg = PhysiCellXMLRules.AggregatorSignal([s_dec], "sum")
    inc_agg = PhysiCellXMLRules.AggregatorSignal([s_inc], "sum")
    m = PhysiCellXMLRules.MediatorSignal(dec_agg, inc_agg, 0.0, 1.0, 5.0, "decreasing_dominant")
    # D=0, U=0: expect base=1.0
    @test evaluateMediator(m, Dict("a"=>0.0,"b"=>0.0)) ≈ 1.0
    # D=0, U=1: 0·0 + 1·(0·1 + 1·5) = 5
    @test evaluateMediator(m, Dict("a"=>0.0,"b"=>1.0)) ≈ 5.0
    # D=1, U=anything: 1·bm + 0·(…) = 0
    @test evaluateMediator(m, Dict("a"=>1.0,"b"=>1.0)) ≈ 0.0

    # Neutral: b0 + D·(bm - b0) + U·(bM - b0)
    mn = PhysiCellXMLRules.MediatorSignal(dec_agg, inc_agg, 0.0, 1.0, 5.0, "neutral")
    @test evaluateMediator(mn, Dict("a"=>1.0,"b"=>1.0)) ≈ 1.0 + 1.0*(0.0-1.0) + 1.0*(5.0-1.0)  # = 4.0
end

@testset "evaluateMediator — keyword overrides" begin
    s = PhysiCellXMLRules.HeavisideSignal("x", 0.5, false, "increasing")
    empty_dec = PhysiCellXMLRules.AggregatorSignal(PhysiCellXMLRules.AbstractSignal[], "sum")
    inc = PhysiCellXMLRules.AggregatorSignal([s], "sum")
    m = PhysiCellXMLRules.MediatorSignal(empty_dec, inc, nothing, nothing, 5.0)
    # D=0, U=1 (sum of [1]); decreasing_dominant with b0 default=1.0, b_max override=10 → 1·(0·1 + 1·10) = 10
    @test evaluateMediator(m, Dict("x"=>1.0); b_max=10.0) ≈ 10.0
end

@testset "evaluateBehavior — fixture rulesets" begin
    rulesets = parseRulesXML(_FIXTURE)
    by_name = Dict(rs.cell_type => rs for rs in rulesets)

    # increasing_partial_hill: at time=30 (half_max), partial_hill→1,
    # multivariate_hill agg→0.5, decreasing_dominant with D=0, U=0.5, b0=0, bM=1 → 0.5.
    b_inc = by_name["increasing_partial_hill"].behaviors[1]
    @test evaluateBehavior(b_inc, Dict("time"=>0.0); b_base=0.0) ≈ 0.0
    @test evaluateBehavior(b_inc, Dict("time"=>30.0); b_base=0.0) ≈ 0.5

    # heaviside ruleset: heaviside→{0,1}; sum agg passes it through; D=0, U∈{0,1}.
    b_hv = by_name["heaviside"].behaviors[1]
    @test evaluateBehavior(b_hv, Dict("time"=>29.9); b_base=0.0) ≈ 0.0
    @test evaluateBehavior(b_hv, Dict("time"=>30.0); b_base=0.0) ≈ 1.0

    # tent: at time=0 both branches give 0 → base. At t=20 inc=1, dec=0 → bM. At t=45,
    # inc=1 (clamped past 20), dec=linear(45,40→50,incr)=0.5; sum aggs both;
    # decreasing_dominant: 0.5·0 + 0.5·((1-1)·0 + 1·1) = 0.5.
    b_tent = by_name["tent"].behaviors[1]
    @test evaluateBehavior(b_tent, Dict("time"=>0.0);  b_base=0.0) ≈ 0.0
    @test evaluateBehavior(b_tent, Dict("time"=>20.0); b_base=0.0) ≈ 1.0
    @test evaluateBehavior(b_tent, Dict("time"=>45.0); b_base=0.0) ≈ 0.5
end

@testset "evaluateBehavior — missing signal raises" begin
    rulesets = parseRulesXML(_FIXTURE)
    b = rulesets[1].behaviors[1]
    @test_throws PhysiCellXMLRules.MissingSignalError evaluateBehavior(b, Dict("not_time"=>5.0))
end

@testset "evaluateMediator — custom raises UnsupportedRuleError" begin
    rulesets = parseRulesXML(_FIXTURE)
    by_name = Dict(rs.cell_type => rs for rs in rulesets)
    b_cm = by_name["custom_mediator"].behaviors[1]
    @test_throws PhysiCellXMLRules.UnsupportedRuleError evaluateBehavior(b_cm, Dict("time"=>5.0))

    b_ca = by_name["custom_aggregator"].behaviors[1]
    @test_throws PhysiCellXMLRules.UnsupportedRuleError evaluateBehavior(b_ca, Dict("time"=>5.0))
end

@testset "elementarySignals and suggestSignalRange" begin
    rulesets = parseRulesXML(_FIXTURE)
    by_name = Dict(rs.cell_type => rs for rs in rulesets)

    b_tent = by_name["tent"].behaviors[1]
    es = PhysiCellXMLRules.elementarySignals(b_tent)
    @test length(es) == 2
    @test all(s -> s.name == "time", es)

    s = es[1]
    lo, hi = PhysiCellXMLRules.suggestSignalRange(s)
    @test lo < hi
end
