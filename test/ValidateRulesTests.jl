using PhysiCellXMLRules, Test

const _FIXTURE = joinpath(@__DIR__, "assets", "extended_cell_rules.xml")

@testset "validateRulesXML — fixture is valid" begin
    report = validateRulesXML(_FIXTURE)
    @test isvalid(report)
end

@testset "validateRulesXML — missing file" begin
    report = validateRulesXML("does_not_exist.xml")
    @test !isvalid(report)
    @test occursin("not found", report.issues[1].message)
end

@testset "validateRulesXML — bad XML" begin
    mktemp() do path, io
        write(io, "<unfinished>")
        close(io)
        report = validateRulesXML(path)
        @test !isvalid(report)
    end
end

@testset "validateRulesXML — wrong root" begin
    mktemp() do path, io
        write(io, "<?xml version=\"1.0\"?><wrong/>")
        close(io)
        report = validateRulesXML(path)
        @test !isvalid(report)
        @test occursin("root element", report.issues[1].message)
    end
end

@testset "validateRulesXML — per-behavior error accumulation" begin
    # Two bad behaviors in one file: both should be reported.
    mktemp() do path, io
        write(io, """
        <behavior_rulesets>
          <behavior_ruleset name="c">
            <behavior name="bad1">
              <increasing_signals><signal name="x" type="bogus">
                <applies_to_dead>0</applies_to_dead></signal></increasing_signals>
            </behavior>
            <behavior name="bad2">
              <increasing_signals><signal name="y" type="hill">
                <hill_power>2</hill_power>
                <applies_to_dead>0</applies_to_dead></signal></increasing_signals>
            </behavior>
          </behavior_ruleset>
        </behavior_rulesets>
        """)
        close(io)
        report = validateRulesXML(path)
        @test !isvalid(report)
        @test PhysiCellXMLRules.nerrors(report) == 2
    end
end

@testset "validateRulesXML — semantic warnings" begin
    # Accumulator without behavior_saturation and with positive base_value
    mktemp() do path, io
        write(io, """
        <behavior_rulesets><behavior_ruleset name="c">
          <behavior name="b">
            <type>accumulator</type>
            <base_value>0.05</base_value>
            <increasing_signals>
              <max_response>0.2</max_response>
              <signal name="x" type="heaviside">
                <threshold>1</threshold>
                <applies_to_dead>0</applies_to_dead>
              </signal>
            </increasing_signals>
          </behavior>
        </behavior_ruleset></behavior_rulesets>
        """)
        close(io)
        report = validateRulesXML(path)
        @test isvalid(report)  # warnings only, not errors
        @test PhysiCellXMLRules.nwarnings(report) >= 2
    end
end

@testset "validateRulesXML — redundant direction on Hill" begin
    mktemp() do path, io
        write(io, """
        <behavior_rulesets><behavior_ruleset name="c"><behavior name="b">
          <increasing_signals><signal name="x" type="hill">
            <type>increasing</type>
            <half_max>1</half_max><hill_power>2</hill_power>
            <applies_to_dead>0</applies_to_dead>
          </signal></increasing_signals>
        </behavior></behavior_ruleset></behavior_rulesets>
        """)
        close(io)
        report = validateRulesXML(path)
        @test isvalid(report)
        @test any(i -> occursin("redundant", i.message), report.issues)
    end
end
