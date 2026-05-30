export summarizeRulesXML, summarizeRules

"""
    summarizeRulesXML([io::IO=stdout,] path_to_xml::AbstractString)

Parse the rules XML at `path_to_xml` and print a human-readable, indented
summary of every behavior to `io`. Useful for quickly understanding what an
unfamiliar rules file does without scrolling through XML.

```julia
summarizeRulesXML("config/cell_rules.xml")
```

See also: [`summarizeRules`](@ref) (operates on an already-parsed
`Vector{BehaviorRuleset}`), [`parseRulesXML`](@ref), and
[`validateRulesXML`](@ref).
"""
summarizeRulesXML(path::AbstractString) = summarizeRulesXML(stdout, path)
function summarizeRulesXML(io::IO, path::AbstractString)
    rulesets = parseRulesXML(path)
    summarizeRules(io, rulesets)
end

"""
    summarizeRules([io::IO=stdout,] rulesets::Vector{BehaviorRuleset})

Print a summary of an already-parsed vector of [`BehaviorRuleset`](@ref).
"""
summarizeRules(rulesets::AbstractVector{BehaviorRuleset}) = summarizeRules(stdout, rulesets)
function summarizeRules(io::IO, rulesets::AbstractVector{BehaviorRuleset})
    for (i, rs) in enumerate(rulesets)
        i == 1 || println(io)
        _summarizeRuleset(io, rs)
    end
end

function _summarizeRuleset(io::IO, rs::BehaviorRuleset)
    println(io, "cell_type: ", rs.cell_type)
    for behavior in rs.behaviors
        _summarizeBehavior(io, behavior, 1)
    end
end

function _summarizeBehavior(io::IO, behavior::Behavior, depth::Int)
    pad = "  "^depth
    extras = String[]
    if behavior.type == "setter"
        push!(extras, "setter")
    else
        push!(extras, behavior.type)
        isnothing(behavior.behavior_base) || push!(extras, "behavior_base=$(behavior.behavior_base)")
        isnothing(behavior.behavior_saturation) || push!(extras, "behavior_saturation=$(behavior.behavior_saturation)")
    end
    println(io, pad, "behavior \"", behavior.name, "\"  [", join(extras, ", "), "]")
    _summarizeSignal(io, behavior.signal, depth + 1; base_label="base_value")
end

function _summarizeSignal(io::IO, m::MediatorSignal, depth::Int; base_label::AbstractString="base_value")
    pad = "  "^depth
    extras = String[]
    isnothing(m.base) || push!(extras, "$base_label=$(m.base)")
    suffix = isempty(extras) ? "" : "  [" * join(extras, ", ") * "]"
    println(io, pad, "mediator: ", m.mediator, suffix)
    if !isempty(m.increasing_signal)
        _summarizeAggregatorBranch(io, m.increasing_signal, m.max, "increasing_signals", depth + 1)
    end
    if !isempty(m.decreasing_signal)
        _summarizeAggregatorBranch(io, m.decreasing_signal, m.min, "decreasing_signals", depth + 1)
    end
end

function _summarizeAggregatorBranch(io::IO, agg::AggregatorSignal, max_response, branch_label::AbstractString, depth::Int)
    pad = "  "^depth
    extras = ["aggregator=$(agg.aggregator)"]
    isnothing(max_response) || push!(extras, "max_response=$(max_response)")
    println(io, pad, branch_label, "  [", join(extras, ", "), "]")
    for s in agg.signals
        _summarizeSignal(io, s, depth + 1)
    end
end

function _summarizeSignal(io::IO, agg::AggregatorSignal, depth::Int)
    pad = "  "^depth
    println(io, pad, "nested aggregator  [aggregator=", agg.aggregator, "]")
    for s in agg.signals
        _summarizeSignal(io, s, depth + 1)
    end
end

function _summarizeSignal(io::IO, s::ElementarySignal, depth::Int)
    pad = "  "^depth
    println(io, pad, "signal \"", s.name, "\": ", _describeTransformer(s),
            "  [applies_to_dead=", s.applies_to_dead, _referenceSuffix(s), "]")
end

_referenceSuffix(s::AbsoluteSignal) = ""
function _referenceSuffix(s::RelativeSignal)
    isnothing(s.reference) && return ""
    return ", reference=$(s.reference.type) from $(s.reference.value)"
end

_describeTransformer(s::PartialHillSignal) = "PartialHill(half_max=$(s.p.half_max), hill_power=$(s.p.hill_power))"
_describeTransformer(s::HillSignal) = "Hill(half_max=$(s.p.half_max), hill_power=$(s.p.hill_power))"
_describeTransformer(s::IdentitySignal) = "Identity"
_describeTransformer(s::LinearSignal) = "Linear($(s.type), signal_min=$(s.signal_min), signal_max=$(s.signal_max))"
_describeTransformer(s::HeavisideSignal) = "Heaviside($(s.type), threshold=$(s.threshold))"
