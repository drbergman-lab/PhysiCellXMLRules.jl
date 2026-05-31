using Test

#=
Validates the bundled XSD against the test fixtures using xmllint
(libxml2). Skipped quietly if xmllint isn't on PATH, since the schema
is shipped as a documentation artifact rather than a hard dependency
of the Julia code.
=#

const _XSD = joinpath(@__DIR__, "..", "schemas", "cell_rules.xsd")
const _XMLLINT = Sys.which("xmllint")

function _xmllint(args::Vector{String})
    out = IOBuffer(); err = IOBuffer()
    proc = run(pipeline(`$_XMLLINT $args`; stdout=out, stderr=err); wait=false)
    wait(proc)
    return proc.exitcode, String(take!(out)), String(take!(err))
end

if isnothing(_XMLLINT)
    @info "xmllint not found on PATH; skipping XSD validation tests" maxlog=1
else
    @testset "XSD — fixtures validate" begin
        for f in ("extended_cell_rules.xml", "multi_signal_rules.xml")
            path = joinpath(@__DIR__, "assets", f)
            code, _, err = _xmllint(["--schema", _XSD, "--noout", path])
            @test code == 0
            code == 0 || @info err
        end
    end

    @testset "XSD — invalid file rejected" begin
        # Wrong root element → schema rejects.
        mktemp() do path, io
            write(io, "<?xml version=\"1.0\"?><not_the_root/>")
            close(io)
            code, _, _ = _xmllint(["--schema", _XSD, "--noout", path])
            @test code != 0
        end
        # Unknown mediator name → schema rejects.
        mktemp() do path, io
            write(io, """
            <?xml version="1.0" encoding="UTF-8"?>
            <behavior_rulesets>
              <behavior_ruleset name="c">
                <behavior name="b">
                  <mediator>not_a_real_mediator</mediator>
                  <increasing_signals>
                    <signal name="x" type="hill">
                      <half_max>1</half_max>
                      <hill_power>2</hill_power>
                      <applies_to_dead>0</applies_to_dead>
                    </signal>
                  </increasing_signals>
                </behavior>
              </behavior_ruleset>
            </behavior_rulesets>
            """)
            close(io)
            code, _, _ = _xmllint(["--schema", _XSD, "--noout", path])
            @test code != 0
        end
        # note="..." attribute on a value element is allowed (PhysiCell
        # convention of inline doc attributes is honored by the schema).
        mktemp() do path, io
            write(io, """
            <?xml version="1.0" encoding="UTF-8"?>
            <behavior_rulesets>
              <behavior_ruleset name="c">
                <behavior name="b">
                  <base_value note="the base rate">0.5</base_value>
                  <increasing_signals>
                    <max_response note="r_plus">1.0</max_response>
                    <signal name="x" type="hill">
                      <half_max>1</half_max>
                      <hill_power>2</hill_power>
                      <applies_to_dead>0</applies_to_dead>
                    </signal>
                  </increasing_signals>
                </behavior>
              </behavior_ruleset>
            </behavior_rulesets>
            """)
            close(io)
            code, _, _ = _xmllint(["--schema", _XSD, "--noout", path])
            @test code == 0
        end
    end
end
