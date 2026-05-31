module PhysiCellXMLRulesRecipesBaseExt

using PhysiCellXMLRules
using PhysiCellXMLRules: Behavior, _doseResponse1D, _doseResponse2D
using RecipesBase

"""
    plot(behavior::Behavior; vary, fixed=Dict(), n=200, signal_ranges=nothing,
                              b_min=nothing, b_base=nothing, b_max=nothing)

This extension registers a `RecipesBase` recipe, so a `Behavior` becomes
plottable from `Plots.jl` (and anything else that consumes the Plots
recipe protocol, e.g. `StatsPlots`). Makie uses a different, incompatible
recipe system and is not supported by this extension — a Makie extension
could be added separately using the same `_doseResponse1D` /
`_doseResponse2D` helpers in the main package.

- `vary::AbstractString` — sweep this raw signal name across its range,
  producing a 1D dose-response line.
- `vary::Tuple{<:AbstractString,<:AbstractString}` — sweep two signals,
  producing a 2D heatmap.

`fixed` sets values for the non-varied signals (defaults to the midpoint of
each signal's suggested range). `signal_ranges` overrides the swept range
per signal as `Dict("name" => (lo, hi))`. `b_min`/`b_base`/`b_max` override
the mediator's stored max/base/max-response just like for
`evaluateBehavior`.

For accumulator/attenuator behaviors the plotted quantity is the rate
of change `r`; for setters it's the behavior value `b'`.
"""
@recipe function f(behavior::Behavior;
                   vary = nothing,
                   fixed = Dict{String,Float64}(),
                   n = nothing,
                   signal_ranges = nothing,
                   b_min = nothing,
                   b_base = nothing,
                   b_max = nothing)
    isnothing(vary) && throw(ArgumentError(
        "plotting a Behavior requires the `vary` keyword (a signal name " *
        "for a 1D dose-response or a 2-tuple of signal names for a heatmap)"))
    if vary isa AbstractString
        nn = isnothing(n) ? 200 : Int(n)
        xs, ys = _doseResponse1D(behavior; vary=vary, fixed=fixed, n=nn,
                                 signal_ranges=signal_ranges,
                                 b_min=b_min, b_base=b_base, b_max=b_max)
        xguide --> vary
        yguide --> _yguide(behavior)
        title  --> _titleFor(behavior)
        label  --> _signalLabel(behavior)
        seriestype --> :line
        return xs, ys

    elseif vary isa Tuple && length(vary) == 2 &&
           all(x -> x isa AbstractString, vary)
        nn = isnothing(n) ? 50 : Int(n)
        xname, yname = vary
        xs, ys, zs = _doseResponse2D(behavior; vary=vary, fixed=fixed, n=nn,
                                     signal_ranges=signal_ranges,
                                     b_min=b_min, b_base=b_base, b_max=b_max)
        xguide --> xname
        yguide --> yname
        title  --> _titleFor(behavior; varies=vary)
        seriestype --> :heatmap
        return xs, ys, zs

    else
        throw(ArgumentError(
            "`vary` must be a String (1D dose-response) or a Tuple{String,String} (2D heatmap); " *
            "got $(typeof(vary)) = $(repr(vary))"))
    end
end

_yguide(b::Behavior) = b.type == "setter" ? b.name : "d($(b.name))/dt"

_signalLabel(b::Behavior) = string(b.signal.mediator, " / ",
                                   isempty(b.signal.increasing_signal) ? "" : b.signal.increasing_signal.aggregator)

function _titleFor(b::Behavior; varies=nothing)
    base = "$(b.name) [$(b.type)]"
    return varies === nothing ? base : base
end

end # module
