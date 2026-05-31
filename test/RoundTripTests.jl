using PhysiCellXMLRules, Test

const _RT_FIXTURES = [
    joinpath(@__DIR__, "assets", "extended_cell_rules.xml"),
    joinpath(@__DIR__, "assets", "multi_signal_rules.xml"),
]

# Reasonably deep comparison: cell types, behavior shapes, mediator and
# aggregator names, elementary signal transformers and parameter values.
function _shape(rulesets)
    out = []
    for rs in rulesets
        bs = []
        for b in rs.behaviors
            m = b.signal
            push!(bs, (
                name = b.name,
                type = b.type,
                behavior_base = b.behavior_base,
                behavior_saturation = b.behavior_saturation,
                mediator = m.mediator,
                base = m.base,
                inc_max = m.max,
                dec_max = m.min,
                inc = _aggShape(m.increasing_signal),
                dec = _aggShape(m.decreasing_signal),
            ))
        end
        push!(out, (cell = rs.cell_type, behaviors = bs))
    end
    return out
end

function _aggShape(a::PhysiCellXMLRules.AggregatorSignal)
    return (
        aggregator = a.aggregator,
        signals = [_sigShape(s) for s in a.signals],
    )
end

function _sigShape(s::PhysiCellXMLRules.ElementarySignal)
    base = (name = s.name, transformer = PhysiCellXMLRules._transformerName(s),
            applies_to_dead = s.applies_to_dead)
    extra = PhysiCellXMLRules._signalParams(s)
    ref = s isa PhysiCellXMLRules.RelativeSignal && !isnothing(s.reference) ?
        (type = s.reference.type, value = s.reference.value) : nothing
    return (base..., params = extra, reference = ref)
end

@testset "writeXMLRules(rulesets) — parse → write → parse round-trip" begin
    for src in _RT_FIXTURES
        rulesets = parseRulesXML(src)
        out = joinpath(@__DIR__, "roundtrip_$(basename(src))")
        writeXMLRules(out, rulesets; force=true)
        round = parseRulesXML(out)
        @test _shape(round) == _shape(rulesets)
    end
end

@testset "id attributes — auto-assigned on sibling collision" begin
    # mean_aggregator carries four same-named "time" Heaviside signals.
    # On write, the writer must auto-assign ids 1..4 so the XML is
    # unambiguous and re-parses to four distinct signals.
    src = joinpath(@__DIR__, "assets", "extended_cell_rules.xml")
    rulesets = parseRulesXML(src)
    out = joinpath(@__DIR__, "roundtrip_ids_extended.xml")
    writeXMLRules(out, rulesets; force=true)

    xml_text = read(out, String)
    @test occursin("id=\"1\"", xml_text)
    @test occursin("id=\"4\"", xml_text)

    # First-occurrence Hill signals (unique by name within their parent)
    # should NOT carry an id.
    round = parseRulesXML(out)
    by = Dict(rs.cell_type => rs for rs in round)
    inc_unique = by["increasing_partial_hill"].behaviors[1].signal.increasing_signal.signals
    @test all(s -> isnothing(s.id), inc_unique)

    # The four mean_aggregator time signals should carry ids 1..4.
    means = by["mean_aggregator"].behaviors[1].signal.increasing_signal.signals
    @test sort([s.id for s in means]) == [1, 2, 3, 4]
end

@testset "id attributes — explicit ids round-trip verbatim" begin
    # Hand-build a tree with explicit ids 7 and 12; round-trip and confirm
    # the writer preserves them rather than re-numbering.
    s1 = PhysiCellXMLRules.HeavisideSignal("time", 10.0, false, "increasing"; id=7)
    s2 = PhysiCellXMLRules.HeavisideSignal("time", 20.0, false, "increasing"; id=12)
    agg = PhysiCellXMLRules.AggregatorSignal(PhysiCellXMLRules.AbstractSignal[s1, s2], "sum")
    m = PhysiCellXMLRules.MediatorSignal(
        PhysiCellXMLRules.AggregatorSignal(PhysiCellXMLRules.AbstractSignal[], "sum"),
        agg, nothing, 0.0, 1.0,
    )
    b = PhysiCellXMLRules.Behavior("custom:sample", m)
    rulesets = [BehaviorRuleset("custom_cell", [b])]
    out = joinpath(@__DIR__, "roundtrip_explicit_ids.xml")
    writeXMLRules(out, rulesets; force=true)

    xml_text = read(out, String)
    @test occursin("id=\"7\"", xml_text)
    @test occursin("id=\"12\"", xml_text)
    @test !occursin("id=\"1\"", xml_text)  # writer should NOT re-number

    round = parseRulesXML(out)
    sigs = round[1].behaviors[1].signal.increasing_signal.signals
    @test sort([s.id for s in sigs]) == [7, 12]
end
