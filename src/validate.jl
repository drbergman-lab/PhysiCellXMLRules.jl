using LightXML

export ValidationIssue, ValidationReport, validateRulesXML

"""
    ValidationIssue(severity::Symbol, where::String, message::String)

A single finding from [`validateRulesXML`](@ref). `severity` is `:error`
(the file is not a valid rules XML) or `:warning` (likely benign, but the
ruleset may not behave as intended).
"""
struct ValidationIssue
    severity::Symbol
    where::String
    message::String
end

"""
    ValidationReport(path::AbstractString, issues::Vector{ValidationIssue})

The result of validating a rules XML. `isvalid(report)` is `true` iff no
issues have severity `:error`. `isempty(report)` is `true` iff there are no
issues at all (errors *or* warnings). Pretty-printed by `Base.show`.
"""
struct ValidationReport
    path::String
    issues::Vector{ValidationIssue}
end

Base.isempty(r::ValidationReport) = isempty(r.issues)
Base.isvalid(r::ValidationReport) = !any(i -> i.severity == :error, r.issues)
nerrors(r::ValidationReport) = count(i -> i.severity == :error, r.issues)
nwarnings(r::ValidationReport) = count(i -> i.severity == :warning, r.issues)

function Base.show(io::IO, ::MIME"text/plain", r::ValidationReport)
    println(io, "ValidationReport for $(r.path)")
    if isempty(r.issues)
        print(io, "  ✓ no issues found")
        return
    end
    println(io, "  $(nerrors(r)) error(s), $(nwarnings(r)) warning(s)")
    for issue in r.issues
        tag = issue.severity == :error ? "ERROR" : "WARN "
        println(io, "  [$tag] $(issue.where): $(issue.message)")
    end
end

Base.show(io::IO, r::ValidationReport) = show(io, MIME("text/plain"), r)

"""
    validateRulesXML(path_to_xml::AbstractString) -> ValidationReport

Validate a PhysiCell rules XML file and return a [`ValidationReport`](@ref).
Errors per behavior are collected (one bad behavior does not stop validation
of the rest), and semantic warnings (e.g. an accumulator missing a saturation
limit) are also surfaced.

```julia
report = validateRulesXML("cell_rules.xml")
isvalid(report) || error("Rules XML has problems:\\n\$report")
```
"""
function validateRulesXML(path_to_xml::AbstractString)
    issues = ValidationIssue[]

    if !isfile(path_to_xml)
        push!(issues, ValidationIssue(:error, "<file>", "file not found: $path_to_xml"))
        return ValidationReport(path_to_xml, issues)
    end

    xml_doc = try
        parse_file(path_to_xml)
    catch err
        push!(issues, ValidationIssue(:error, "<file>", "could not parse as XML: $(sprint(showerror, err))"))
        return ValidationReport(path_to_xml, issues)
    end

    try
        xml_root = root(xml_doc)
        if name(xml_root) != "behavior_rulesets"
            push!(issues, ValidationIssue(:error, "<root>", "root element must be <behavior_rulesets>, got <$(name(xml_root))>"))
            return ValidationReport(path_to_xml, issues)
        end

        for ruleset_e in get_elements_by_tagname(xml_root, "behavior_ruleset")
            cell_type = attribute(ruleset_e, "name")
            if isnothing(cell_type)
                push!(issues, ValidationIssue(:error, "<behavior_ruleset>", "missing required `name` attribute"))
                continue
            end

            for behavior_e in get_elements_by_tagname(ruleset_e, "behavior")
                behavior_name = attribute(behavior_e, "name")
                where_str = isnothing(behavior_name) ?
                    "<behavior> in cell_type '$cell_type'" :
                    "behavior '$behavior_name' in cell_type '$cell_type'"
                if isnothing(behavior_name)
                    push!(issues, ValidationIssue(:error, where_str, "missing required `name` attribute"))
                    continue
                end

                behavior = try
                    _parseBehavior(behavior_e, cell_type)
                catch err
                    msg = err isa Exception ? sprint(showerror, err) : string(err)
                    push!(issues, ValidationIssue(:error, where_str, msg))
                    nothing
                end
                isnothing(behavior) && continue

                _redundantDirectionWarnings!(issues, behavior_e, where_str)
                _semanticChecks!(issues, behavior, where_str)
            end
        end
    finally
        free(xml_doc)
    end

    return ValidationReport(path_to_xml, issues)
end

function _semanticChecks!(issues::Vector{ValidationIssue}, behavior::Behavior, where_str::AbstractString)
    m = behavior.signal::MediatorSignal

    if behavior.type in ("accumulator", "attenuator")
        if isnothing(behavior.behavior_saturation)
            push!(issues, ValidationIssue(:warning, where_str,
                "$(behavior.type) behavior has no <behavior_saturation>; the behavior has no bound on accumulation"))
        end
        if isnothing(m.base)
            push!(issues, ValidationIssue(:warning, where_str,
                "$(behavior.type) behavior has no <base_value>; without a base rate the behavior will not relax in the absence of signals"))
        elseif m.base > 0
            push!(issues, ValidationIssue(:warning, where_str,
                "$(behavior.type) behavior has positive <base_value> ($(m.base)); typically the base rate is ≤ 0 so the behavior relaxes toward <behavior_base>"))
        end
        if !isempty(m.decreasing_signal) && !isnothing(m.min) && m.min > 0
            push!(issues, ValidationIssue(:warning, where_str,
                "$(behavior.type) behavior has positive decreasing <max_response> ($(m.min)); rates in the decreasing branch should normally be negative"))
        end
        if !isempty(m.increasing_signal) && !isnothing(m.max) && m.max < 0
            push!(issues, ValidationIssue(:warning, where_str,
                "$(behavior.type) behavior has negative increasing <max_response> ($(m.max)); rates in the increasing branch should normally be positive"))
        end
    end

    if isempty(m.decreasing_signal) && isempty(m.increasing_signal)
        push!(issues, ValidationIssue(:warning, where_str,
            "behavior has no signals in either <decreasing_signals> or <increasing_signals>"))
    end
end

function _redundantDirectionWarnings!(issues::Vector{ValidationIssue}, behavior_e::XMLElement, where_str::AbstractString)
    for signal_e in _allSignalElements(behavior_e)
        type_attr = attribute(signal_e, "type")
        raw_type = isnothing(type_attr) ? "partial_hill" : type_attr
        canonical = _match(raw_type, _ELEMENTARY_TYPES)
        canonical in ("partial_hill", "hill", "identity") || continue
        dir_child = find_element(signal_e, "type")
        isnothing(dir_child) && continue
        signal_name = something(attribute(signal_e, "name"), "<unnamed>")
        push!(issues, ValidationIssue(:warning, where_str,
            "signal '$signal_name' (type=$raw_type) has a redundant <type>$(strip(content(dir_child)))</type>; only Linear/Heaviside use this element (use <reference> for direction-aware Hill/PartialHill/Identity)"))
    end
end

function _allSignalElements(parent_e::XMLElement)
    out = XMLElement[]
    _collectSignals!(out, parent_e)
    return out
end

function _collectSignals!(out::Vector{XMLElement}, parent_e::XMLElement)
    for child in child_elements(parent_e)
        if name(child) == "signal"
            push!(out, child)
        end
        _collectSignals!(out, child)
    end
end
