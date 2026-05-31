export exportInteractiveHTML

const _EXPLORER_TEMPLATE_PATH = joinpath(@__DIR__, "assets", "explorer.html")

"""
    exportInteractiveHTML(path_to_html::AbstractString, source; force=false, title=nothing)

Write a single self-contained HTML file at `path_to_html` for interactively
exploring the rules in `source`. `source` can be either:

- a path to a rules XML file, or
- a `Vector{BehaviorRuleset}` already returned by [`parseRulesXML`](@ref).

The HTML loads `plotly.js` from a CDN (`https://cdn.plot.ly/`) and renders:

- a header with cell-type / behavior dropdowns,
- a sidebar with one card per elementary signal in the chosen behavior
  (with axis toggle: x / y / fixed, value or range inputs, and editable
  transformer parameters),
- a plot pane that re-renders on any change — a 1D dose-response line
  when only one signal is varied, a 2D heatmap when two are varied.

Behaviors that use a `custom` mediator/aggregator, or that contain
hierarchical (composite) sub-signals, are listed in the dropdown but show
a banner in place of the plot instead of evaluating: the former are
delegated to PhysiCell's `custom.cpp`, the latter are slated for v2 of
the explorer. The XML parser, validator, and CSV exporter still handle
them — only the in-browser evaluator currently does not.

```julia
exportInteractiveHTML("explorer.html", "config/cell_rules.xml")
```

If `force` is `true`, an existing file at `path_to_html` is overwritten;
otherwise the function refuses to overwrite.
"""
function exportInteractiveHTML(path_to_html::AbstractString, path_to_xml::AbstractString;
                               force::Bool=false, title::Union{Nothing,AbstractString}=nothing)
    @assert splitext(path_to_html)[2] == ".html" "Output path must end with .html. Got $(path_to_html)"
    @assert force || !isfile(path_to_html) "$(path_to_html) already exists. Pass `force=true` to overwrite."
    @assert isfile(path_to_xml) "Rules XML file not found: $(path_to_xml)"
    rulesets = parseRulesXML(path_to_xml)
    return _writeExplorer(path_to_html, rulesets; title=something(title, basename(path_to_xml)), force=force)
end

function exportInteractiveHTML(path_to_html::AbstractString, rulesets::AbstractVector{BehaviorRuleset};
                               force::Bool=false, title::Union{Nothing,AbstractString}=nothing)
    @assert splitext(path_to_html)[2] == ".html" "Output path must end with .html. Got $(path_to_html)"
    @assert force || !isfile(path_to_html) "$(path_to_html) already exists. Pass `force=true` to overwrite."
    return _writeExplorer(path_to_html, rulesets; title=something(title, "rules"), force=force)
end

function _writeExplorer(path_to_html::AbstractString, rulesets::AbstractVector{BehaviorRuleset};
                        title::AbstractString, force::Bool)
    template = read(_EXPLORER_TEMPLATE_PATH, String)
    json = _rulesToJSON(rulesets)
    html = replace(template,
                   "{{TITLE}}"      => _jsonEscape(title),
                   "{{RULES_JSON}}" => json)
    open(path_to_html, "w") do io; write(io, html); end
    return path_to_html
end

# ─── JSON serializer (tiny, just what the explorer template needs) ─────────
function _rulesToJSON(rulesets::AbstractVector{BehaviorRuleset})
    obj = Dict{String,Any}("rulesets" => [_rulesetToJSON(rs) for rs in rulesets])
    io = IOBuffer()
    _writeJSON(io, obj)
    return String(take!(io))
end

_rulesetToJSON(rs::BehaviorRuleset) = Dict{String,Any}(
    "cell_type" => rs.cell_type,
    "behaviors" => [_behaviorToJSON(b) for b in rs.behaviors],
)

function _behaviorToJSON(b::Behavior)
    m = b.signal::MediatorSignal
    return Dict{String,Any}(
        "name"                => b.name,
        "type"                => b.type,
        "behavior_base"       => b.behavior_base,
        "behavior_saturation" => b.behavior_saturation,
        "mediator"            => Dict{String,Any}(
            "name"       => m.mediator,
            "base_value" => m.base,
        ),
        "increasing" => _aggToJSON(m.increasing_signal, m.max),
        "decreasing" => _aggToJSON(m.decreasing_signal, m.min),
    )
end

_aggToJSON(::Nothing, _) = nothing
function _aggToJSON(agg::AggregatorSignal, max_response)
    isempty(agg) && return nothing
    return Dict{String,Any}(
        "aggregator"   => agg.aggregator,
        "max_response" => max_response,
        "signals"      => [_signalToJSON(s) for s in agg.signals],
    )
end

function _signalToJSON(s::ElementarySignal)
    return Dict{String,Any}(
        "kind"            => "elementary",
        "name"            => s.name,
        "transformer"     => _transformerName(s),
        "params"          => _signalParams(s),
        "applies_to_dead" => s.applies_to_dead,
        "reference"       => _referenceToJSON(_referenceOf(s)),
        "id"              => s.id,
    )
end
function _signalToJSON(s::AggregatorSignal)
    return Dict{String,Any}("kind" => "composite", "composite" => "aggregator", "aggregator" => s.aggregator, "id" => s.id)
end
function _signalToJSON(s::MediatorSignal)
    return Dict{String,Any}("kind" => "composite", "composite" => "mediator", "mediator" => s.mediator, "id" => s.id)
end

_transformerName(::PartialHillSignal) = "partial_hill"
_transformerName(::HillSignal)        = "hill"
_transformerName(::IdentitySignal)    = "identity"
_transformerName(::LinearSignal)      = "linear"
_transformerName(::HeavisideSignal)   = "heaviside"

_signalParams(s::PartialHillSignal) = Dict{String,Any}("half_max"=>s.p.half_max, "hill_power"=>s.p.hill_power)
_signalParams(s::HillSignal)        = Dict{String,Any}("half_max"=>s.p.half_max, "hill_power"=>s.p.hill_power)
_signalParams(::IdentitySignal)     = Dict{String,Any}()
_signalParams(s::LinearSignal)      = Dict{String,Any}("signal_min"=>s.signal_min, "signal_max"=>s.signal_max, "direction"=>s.type)
_signalParams(s::HeavisideSignal)   = Dict{String,Any}("threshold"=>s.threshold, "direction"=>s.type)

_referenceOf(s::RelativeSignal) = s.reference
_referenceOf(::AbsoluteSignal)  = nothing
_referenceToJSON(::Nothing)     = nothing
_referenceToJSON(r::SignalReference) = Dict{String,Any}("type" => r.type, "value" => r.value)

# Minimal JSON writer (no external dep) ──────────────────────────────────────
function _writeJSON(io::IO, v)
    if v === nothing
        print(io, "null")
    elseif v isa Bool
        print(io, v ? "true" : "false")
    elseif v isa Real
        if isfinite(v)
            print(io, v isa Integer ? v : Float64(v))
        else
            # NaN/Inf are not valid JSON; emit null and the explorer will treat as default
            print(io, "null")
        end
    elseif v isa AbstractString
        print(io, '"', _jsonEscape(v), '"')
    elseif v isa AbstractDict
        print(io, '{')
        first = true
        for (k, x) in v
            first ? (first = false) : print(io, ',')
            print(io, '"', _jsonEscape(string(k)), '"', ':')
            _writeJSON(io, x)
        end
        print(io, '}')
    elseif v isa AbstractVector
        print(io, '[')
        first = true
        for x in v
            first ? (first = false) : print(io, ',')
            _writeJSON(io, x)
        end
        print(io, ']')
    else
        _writeJSON(io, string(v))
    end
end

function _jsonEscape(s::AbstractString)
    sprint() do io
        for c in s
            if c == '"'      print(io, "\\\"")
            elseif c == '\\' print(io, "\\\\")
            elseif c == '\n' print(io, "\\n")
            elseif c == '\r' print(io, "\\r")
            elseif c == '\t' print(io, "\\t")
            elseif c < ' '   print(io, "\\u", lpad(string(UInt32(c), base=16), 4, '0'))
            else             print(io, c)
            end
        end
    end
end
