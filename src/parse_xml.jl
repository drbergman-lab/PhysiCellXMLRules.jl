using LightXML

export BehaviorRuleset, parseRulesXML

"""
    BehaviorRuleset(cell_type::String, behaviors::Vector{Behavior})

The parsed representation of a single `<behavior_ruleset>` element from a
rules XML file. Returned (in a vector) by [`parseRulesXML`](@ref).
"""
struct BehaviorRuleset
    cell_type::String
    behaviors::Vector{Behavior}
end

#=
Canonical names emitted/accepted by this package. Inputs are matched against
these after normalisation (lowercase, with separators stripped) so that
`partial_hill`, `partial hill`, and `PartialHill` are all equivalent.
=#
const _ELEMENTARY_TYPES = ("partial_hill", "hill", "linear", "heaviside", "identity")
const _COMPOSITE_TYPES = ("mediator", "aggregator")
const _MEDIATORS = ("decreasing_dominant", "increasing_dominant", "neutral", "custom")
const _AGGREGATORS = ("multivariate_hill", "sum", "product", "mean", "min", "max", "median", "geometric_mean", "first", "custom")
const _BEHAVIOR_TYPES = ("setter", "accumulator", "attenuator")
const _DIRECTIONS = ("increasing", "decreasing")

_normalize(s::AbstractString) = replace(lowercase(s), r"[_\s\-]" => "")

function _match(s::AbstractString, candidates)
    ns = _normalize(s)
    for c in candidates
        _normalize(c) == ns && return c
    end
    return nothing
end

"""
    parseRulesXML(path_to_xml::AbstractString) -> Vector{BehaviorRuleset}

Parse a PhysiCell rules XML file into the [`BehaviorRuleset`](@ref) /
[`Behavior`](@ref) / [`MediatorSignal`](@ref) / [`AggregatorSignal`](@ref) /
elementary-signal hierarchy.

The parser is strict: any non-conforming element raises an error. To collect
errors into a report instead, use [`validateRulesXML`](@ref).

Signal type names, mediator names, and aggregator names are matched
case-insensitively and treat space/underscore/hyphen as equivalent, so
`"PartialHill"`, `"partial_hill"`, and `"partial hill"` all parse identically.
"""
function parseRulesXML(path_to_xml::AbstractString)
    @assert isfile(path_to_xml) "Rules XML file not found: $(path_to_xml)"
    xml_doc = parse_file(path_to_xml)
    try
        return _parseRulesRoot(root(xml_doc))
    finally
        free(xml_doc)
    end
end

function _parseRulesRoot(xml_root::XMLElement)
    name(xml_root) == "behavior_rulesets" ||
        throw(ArgumentError("Root element must be <behavior_rulesets>, got <$(name(xml_root))>"))
    rulesets = BehaviorRuleset[]
    for ruleset_e in get_elements_by_tagname(xml_root, "behavior_ruleset")
        push!(rulesets, _parseRuleset(ruleset_e))
    end
    return rulesets
end

function _parseRuleset(ruleset_e::XMLElement)
    cell_type = attribute(ruleset_e, "name")
    isnothing(cell_type) && throw(ArgumentError("<behavior_ruleset> is missing the required `name` attribute"))
    behaviors = Behavior[]
    for behavior_e in get_elements_by_tagname(ruleset_e, "behavior")
        push!(behaviors, _parseBehavior(behavior_e, cell_type))
    end
    return BehaviorRuleset(cell_type, behaviors)
end

function _parseBehavior(behavior_e::XMLElement, cell_type::AbstractString)
    behavior_name = attribute(behavior_e, "name")
    isnothing(behavior_name) && throw(ArgumentError("<behavior> in cell_type '$cell_type' is missing the required `name` attribute"))
    where_str = "behavior '$behavior_name' (cell_type '$cell_type')"

    type_str = _childContent(behavior_e, "type", "setter")
    canonical_type = _match(type_str, _BEHAVIOR_TYPES)
    isnothing(canonical_type) && throw(ArgumentError("Unknown behavior type '$type_str' in $where_str. Expected one of $(join(_BEHAVIOR_TYPES, ", "))."))

    behavior_base = _parseFloatChild(behavior_e, "behavior_base")
    behavior_saturation = _parseFloatChild(behavior_e, "behavior_saturation")

    mediator = _parseMediatorBody(behavior_e, where_str)
    return Behavior(behavior_name, mediator, canonical_type;
                    behavior_base=behavior_base,
                    behavior_saturation=behavior_saturation)
end

function _parseMediatorBody(parent_e::XMLElement, where_str::AbstractString)
    mediator_name = _childContent(parent_e, "mediator", "decreasing_dominant")
    canonical = _match(mediator_name, _MEDIATORS)
    isnothing(canonical) && throw(ArgumentError("Unknown mediator '$mediator_name' in $where_str. Expected one of $(join(_MEDIATORS, ", "))."))

    base = _parseFloatChild(parent_e, "base_value")

    dec_e = find_element(parent_e, "decreasing_signals")
    inc_e = find_element(parent_e, "increasing_signals")
    if isnothing(dec_e) && isnothing(inc_e)
        throw(ArgumentError("$where_str must have at least one of <decreasing_signals> or <increasing_signals>"))
    end

    dec_agg, dec_max = isnothing(dec_e) ? (AggregatorSignal(AbstractSignal[]), nothing) : _parseAggregatorBody(dec_e, "decreasing_signals in $where_str")
    inc_agg, inc_max = isnothing(inc_e) ? (AggregatorSignal(AbstractSignal[]), nothing) : _parseAggregatorBody(inc_e, "increasing_signals in $where_str")

    return MediatorSignal(dec_agg, inc_agg, dec_max, base, inc_max, canonical)
end

function _parseAggregatorBody(parent_e::XMLElement, where_str::AbstractString)
    aggregator_name = _childContent(parent_e, "aggregator", "multivariate_hill")
    canonical = _match(aggregator_name, _AGGREGATORS)
    isnothing(canonical) && throw(ArgumentError("Unknown aggregator '$aggregator_name' in $where_str. Expected one of $(join(_AGGREGATORS, ", "))."))

    max_response = _parseFloatChild(parent_e, "max_response")

    signals = AbstractSignal[]
    for signal_e in get_elements_by_tagname(parent_e, "signal")
        push!(signals, _parseSignal(signal_e, where_str))
    end
    return AggregatorSignal(signals, canonical), max_response
end

function _parseSignal(signal_e::XMLElement, where_str::AbstractString)
    type_attr = attribute(signal_e, "type")
    raw_type = isnothing(type_attr) ? "partial_hill" : type_attr

    canonical_composite = _match(raw_type, _COMPOSITE_TYPES)
    if canonical_composite == "mediator"
        return _parseMediatorBody(signal_e, "nested mediator signal in $where_str")
    elseif canonical_composite == "aggregator"
        agg, _ = _parseAggregatorBody(signal_e, "nested aggregator signal in $where_str")
        return agg
    end

    canonical_elem = _match(raw_type, _ELEMENTARY_TYPES)
    isnothing(canonical_elem) && throw(ArgumentError(
        "Unknown signal type='$raw_type' in $where_str. Expected one of $(join((_ELEMENTARY_TYPES..., _COMPOSITE_TYPES...), ", "))."))

    signal_name = attribute(signal_e, "name")
    isnothing(signal_name) && throw(ArgumentError("Elementary <signal type='$raw_type'> in $where_str is missing the required `name` attribute"))

    applies_to_dead = _parseBoolChild(signal_e, "applies_to_dead")
    isnothing(applies_to_dead) && throw(ArgumentError("Elementary signal '$signal_name' in $where_str is missing <applies_to_dead>"))

    if canonical_elem == "partial_hill" || canonical_elem == "hill"
        half_max = _parseRequiredFloat(signal_e, "half_max", signal_name, where_str)
        hill_power = _parseRequiredFloat(signal_e, "hill_power", signal_name, where_str)
        reference = SignalReference(signal_e)
        T = canonical_elem == "partial_hill" ? PartialHillSignal : HillSignal
        return T(signal_name, half_max, hill_power, applies_to_dead, reference)
    elseif canonical_elem == "identity"
        reference = SignalReference(signal_e)
        return IdentitySignal(signal_name, applies_to_dead, reference)
    elseif canonical_elem == "linear"
        signal_min = _parseRequiredFloat(signal_e, "signal_min", signal_name, where_str)
        signal_max = _parseRequiredFloat(signal_e, "signal_max", signal_name, where_str)
        direction = _parseDirectionChild(signal_e, signal_name, where_str)
        return LinearSignal(signal_name, signal_min, signal_max, applies_to_dead, direction)
    elseif canonical_elem == "heaviside"
        threshold = _parseRequiredFloat(signal_e, "threshold", signal_name, where_str)
        direction = _parseDirectionChild(signal_e, signal_name, where_str)
        return HeavisideSignal(signal_name, threshold, applies_to_dead, direction)
    end
end

function _childContent(parent_e::XMLElement, child_name::AbstractString, default::AbstractString)
    child = find_element(parent_e, child_name)
    return isnothing(child) ? default : strip(content(child))
end

function _parseFloatChild(parent_e::XMLElement, child_name::AbstractString)
    child = find_element(parent_e, child_name)
    isnothing(child) && return nothing
    text = strip(content(child))
    isempty(text) && return nothing
    try
        return parse(Float64, text)
    catch
        throw(ArgumentError("Could not parse <$child_name>$(text)</$child_name> as a number"))
    end
end

function _parseRequiredFloat(parent_e::XMLElement, child_name::AbstractString, signal_name::AbstractString, where_str::AbstractString)
    v = _parseFloatChild(parent_e, child_name)
    isnothing(v) && throw(ArgumentError("Signal '$signal_name' in $where_str is missing required <$child_name>"))
    return v
end

function _parseBoolChild(parent_e::XMLElement, child_name::AbstractString)
    child = find_element(parent_e, child_name)
    isnothing(child) && return nothing
    text = strip(lowercase(content(child)))
    text in ("1", "true") && return true
    text in ("0", "false") && return false
    throw(ArgumentError("Could not parse <$child_name>$(text)</$child_name> as a boolean (expected 0/1/true/false)"))
end

function _parseDirectionChild(parent_e::XMLElement, signal_name::AbstractString, where_str::AbstractString)
    child = find_element(parent_e, "type")
    isnothing(child) && return "increasing"
    raw = strip(content(child))
    canonical = _match(raw, _DIRECTIONS)
    isnothing(canonical) && throw(ArgumentError("Signal '$signal_name' in $where_str has invalid <type>$raw</type> (expected 'increasing' or 'decreasing')"))
    return canonical
end
