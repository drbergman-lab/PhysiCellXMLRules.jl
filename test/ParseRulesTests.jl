using PhysiCellXMLRules, Test

const _FIXTURE = joinpath(@__DIR__, "assets", "extended_cell_rules.xml")

@testset "parseRulesXML — extended_cell_rules.xml" begin
    rulesets = parseRulesXML(_FIXTURE)
    @test length(rulesets) > 0
    @test all(rs -> rs isa BehaviorRuleset, rulesets)

    # All behaviors in the fixture target "custom:sample".
    @test all(rs -> all(b -> b.name == "custom:sample", rs.behaviors), rulesets)

    by_cell = Dict(rs.cell_type => rs.behaviors[1] for rs in rulesets)
    @test haskey(by_cell, "increasing_partial_hill")
    @test haskey(by_cell, "accumulator")
    @test haskey(by_cell, "custom_mediator")

    # Accumulator carries behavior_saturation / behavior_base on the Behavior,
    # base_value on the MediatorSignal.
    acc = by_cell["accumulator"]
    @test acc.type == "accumulator"
    @test acc.behavior_saturation == 1.0
    @test acc.signal.base == -0.05

    # Custom mediator survives parsing.
    cm = by_cell["custom_mediator"]
    @test cm.signal.mediator == "custom"

    # Custom aggregator survives parsing.
    ca = by_cell["custom_aggregator"]
    @test ca.signal.increasing_signal.aggregator == "custom"

    # PartialHill reference round-trips.
    dec = by_cell["decreasing_partial_hill"]
    sig = dec.signal.increasing_signal.signals[1]
    @test sig isa PhysiCellXMLRules.PartialHillSignal
    @test sig.reference !== nothing
    @test sig.reference.type == "decreasing"
    @test sig.reference.value == 60.0
end

@testset "parseRulesXML — name normalisation" begin
    # CamelCase, snake_case, and space-separated names should all parse.
    mktemp() do path, io
        write(io, """
        <?xml version="1.0" encoding="UTF-8"?>
        <behavior_rulesets>
          <behavior_ruleset name="cell">
            <behavior name="b">
              <mediator>Decreasing Dominant</mediator>
              <increasing_signals>
                <aggregator>multivariate hill</aggregator>
                <max_response>1.0</max_response>
                <signal name="oxygen" type="PartialHill">
                  <half_max>0.5</half_max>
                  <hill_power>2</hill_power>
                  <applies_to_dead>0</applies_to_dead>
                </signal>
              </increasing_signals>
            </behavior>
          </behavior_ruleset>
        </behavior_rulesets>
        """)
        close(io)
        rulesets = parseRulesXML(path)
        @test rulesets[1].behaviors[1].signal.mediator == "decreasing_dominant"
        @test rulesets[1].behaviors[1].signal.increasing_signal.aggregator == "multivariate_hill"
    end
end

@testset "parseRulesXML — errors" begin
    # Unknown signal type
    mktemp() do path, io
        write(io, """
        <behavior_rulesets><behavior_ruleset name="c"><behavior name="b">
        <increasing_signals><signal name="x" type="bogus">
        <applies_to_dead>0</applies_to_dead></signal></increasing_signals>
        </behavior></behavior_ruleset></behavior_rulesets>
        """)
        close(io)
        @test_throws ArgumentError parseRulesXML(path)
    end

    # Missing required half_max
    mktemp() do path, io
        write(io, """
        <behavior_rulesets><behavior_ruleset name="c"><behavior name="b">
        <increasing_signals><signal name="x" type="partial_hill">
        <hill_power>2</hill_power>
        <applies_to_dead>0</applies_to_dead></signal></increasing_signals>
        </behavior></behavior_ruleset></behavior_rulesets>
        """)
        close(io)
        @test_throws ArgumentError parseRulesXML(path)
    end
end
