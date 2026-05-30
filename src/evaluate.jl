using Statistics: median, mean

export evaluateBehavior, UnsupportedRuleError, MissingSignalError

# ─────────────────────────────────────────────────────────────────────────────
# Errors
# ─────────────────────────────────────────────────────────────────────────────

"""
    UnsupportedRuleError(reason::String)

Thrown when a rule references a feature the Julia evaluator does not
implement: currently `custom` mediators/aggregators (delegated to C++ in
PhysiCell), and (v1) hierarchical sub-signals (`<signal type="aggregator">`
or `<signal type="mediator">` nested inside a rule). The latter is
slated for v2 — see the package docs.
"""
struct UnsupportedRuleError <: Exception
    reason::String
end
Base.showerror(io::IO, e::UnsupportedRuleError) = print(io, "UnsupportedRuleError: ", e.reason)

"""
    MissingSignalError(name::String)

Thrown by [`evaluateBehavior`](@ref) when a required raw signal value is
not present in the `signals` dictionary passed to the evaluator.
"""
struct MissingSignalError <: Exception
    name::String
end
Base.showerror(io::IO, e::MissingSignalError) = print(io, "MissingSignalError: no value supplied for signal '", e.name, "'")

# ─────────────────────────────────────────────────────────────────────────────
# Mediator default behavior values, per the rules grammar
#   (used when <max_response> / <base_value> are omitted on a rule)
# ─────────────────────────────────────────────────────────────────────────────
const _DEFAULT_B_MIN  = 0.1
const _DEFAULT_B_BASE = 1.0
const _DEFAULT_B_MAX  = 10.0

# ─────────────────────────────────────────────────────────────────────────────
# Elementary signal evaluation: raw signal value → transformer output
# ─────────────────────────────────────────────────────────────────────────────

"""
    evaluateSignal(signal, raw::Real) -> Float64

Apply the elementary `signal`'s transformer (with reference handling, if
any) to a raw signal value. Always returns a value in `[0, ∞)` for the
unbounded transformers (`partial_hill`, `identity`) and in `[0, 1]` for the
bounded ones (`hill`, `linear`, `heaviside`).
"""
function evaluateSignal(s::PartialHillSignal, raw::Real)
    x, γ = _referenceAdjust(s, raw)
    γ <= 0 && return 0.0
    return (x / γ)^s.p.hill_power
end

function evaluateSignal(s::HillSignal, raw::Real)
    x, γ = _referenceAdjust(s, raw)
    γ <= 0 && return 0.0
    z = (x / γ)^s.p.hill_power
    return z / (1 + z)
end

function evaluateSignal(s::IdentitySignal, raw::Real)
    x, _ = _referenceAdjust(s, raw)
    return float(x)
end

function evaluateSignal(s::LinearSignal, raw::Real)
    w = s.signal_max - s.signal_min
    w <= 0 && return 0.0
    if s.type == "increasing"
        return clamp((raw - s.signal_min) / w, 0.0, 1.0)
    else
        return clamp((s.signal_max - raw) / w, 0.0, 1.0)
    end
end

function evaluateSignal(s::HeavisideSignal, raw::Real)
    if s.type == "increasing"
        return raw >= s.threshold ? 1.0 : 0.0
    else
        return raw <= s.threshold ? 1.0 : 0.0
    end
end

#=
Reference handling for RelativeSignals (Hill / PartialHill / Identity).
With an `increasing` reference of value s₀ and half-max γ, the input is
shifted to max(raw - s₀, 0) and the half-max becomes γ - s₀. With a
`decreasing` reference, it's max(s₀ - raw, 0) and γ becomes s₀ - γ. With
no reference, x = raw and γ is unchanged.
=#
_referenceAdjust(s::PartialHillSignal, raw::Real) = _refShift(raw, s.p.half_max, s.reference)
_referenceAdjust(s::HillSignal,        raw::Real) = _refShift(raw, s.p.half_max, s.reference)
_referenceAdjust(s::IdentitySignal,    raw::Real) = _refShift(raw, 1.0,          s.reference)

_refShift(raw::Real, γ::Real, ::Nothing) = (float(raw), float(γ))
function _refShift(raw::Real, γ::Real, ref::SignalReference)
    if ref.type == "increasing"
        return (max(raw - ref.value, 0.0), γ - ref.value)
    else
        return (max(ref.value - raw, 0.0), ref.value - γ)
    end
end

# Signal name accessor (some elementary signals share this field already;
# generic for any AbstractSignal that has it).
_signalName(s) = s.name

# ─────────────────────────────────────────────────────────────────────────────
# Aggregator evaluation
# ─────────────────────────────────────────────────────────────────────────────

"""
    evaluateAggregator(agg::AggregatorSignal, signals::AbstractDict{<:AbstractString,<:Real}) -> Float64

Evaluate an aggregator: apply every child signal's transformer using the raw
values in `signals`, then reduce with the aggregator's named operation.
Returns `0.0` if the aggregator is empty.

Throws [`UnsupportedRuleError`](@ref) for `custom` aggregators, and for
hierarchical sub-signals (composite `<signal type="aggregator|mediator">`)
which are slated for v2.
"""
function evaluateAggregator(agg::AggregatorSignal, signals::AbstractDict{<:AbstractString,<:Real})
    isempty(agg) && return 0.0
    xs = [_evaluateAggChild(s, signals) for s in agg.signals]
    return _reduce(Val(Symbol(agg.aggregator)), xs)
end

function _evaluateAggChild(s::ElementarySignal, signals::AbstractDict)
    haskey(signals, s.name) || throw(MissingSignalError(s.name))
    return evaluateSignal(s, signals[s.name])
end

function _evaluateAggChild(::AggregatorSignal, ::AbstractDict)
    throw(UnsupportedRuleError("hierarchical aggregator signals are slated for v2; only elementary signal children are supported in v1"))
end
function _evaluateAggChild(::MediatorSignal, ::AbstractDict)
    throw(UnsupportedRuleError("hierarchical mediator signals are slated for v2; only elementary signal children are supported in v1"))
end

_reduce(::Val{:multivariate_hill}, xs) = (s = sum(xs); s / (1 + s))
_reduce(::Val{:sum},               xs) = sum(xs)
_reduce(::Val{:product},           xs) = prod(xs)
_reduce(::Val{:min},               xs) = minimum(xs)
_reduce(::Val{:max},               xs) = maximum(xs)
_reduce(::Val{:mean},              xs) = mean(xs)
_reduce(::Val{:median},            xs) = median(xs)
_reduce(::Val{:geometric_mean},    xs) = prod(xs)^(1 / length(xs))
_reduce(::Val{:first},             xs) = xs[1]
_reduce(::Val{:custom},            xs) = throw(UnsupportedRuleError("custom aggregator: cannot evaluate in Julia (delegated to custom.cpp in PhysiCell)"))

# ─────────────────────────────────────────────────────────────────────────────
# Mediator evaluation
# ─────────────────────────────────────────────────────────────────────────────

"""
    evaluateMediator(m::MediatorSignal, signals; b_min=nothing, b_base=nothing, b_max=nothing) -> Float64

Evaluate the mediator: compute `D` (decreasing aggregator output), `U`
(increasing aggregator output), then combine using the mediator's formula.

The `b_min` / `b_base` / `b_max` keyword arguments override the defaults
inherited from the mediator's `min`/`base`/`max` fields. If a value is
`nothing` everywhere, the grammar defaults (`0.1`, `1.0`, `10.0`) are used —
the same defaults the PhysiCell rules grammar applies when `<max_response>`
or `<base_value>` is omitted from the XML.
"""
function evaluateMediator(m::MediatorSignal, signals::AbstractDict{<:AbstractString,<:Real};
                          b_min::Union{Nothing,Real}=nothing,
                          b_base::Union{Nothing,Real}=nothing,
                          b_max::Union{Nothing,Real}=nothing)
    D = evaluateAggregator(m.decreasing_signal, signals)
    U = evaluateAggregator(m.increasing_signal, signals)
    bm = something(b_min,  m.min,  _DEFAULT_B_MIN)
    b0 = something(b_base, m.base, _DEFAULT_B_BASE)
    bM = something(b_max,  m.max,  _DEFAULT_B_MAX)
    return _combine(Val(Symbol(m.mediator)), D, U, bm, b0, bM)
end

_combine(::Val{:decreasing_dominant}, D, U, bm, b0, bM) = D * bm + (1 - D) * ((1 - U) * b0 + U * bM)
_combine(::Val{:increasing_dominant}, D, U, bm, b0, bM) = U * bM + (1 - U) * ((1 - D) * b0 + D * bm)
_combine(::Val{:neutral},             D, U, bm, b0, bM) = b0 + D * (bm - b0) + U * (bM - b0)
_combine(::Val{:custom},              D, U, bm, b0, bM) = throw(UnsupportedRuleError("custom mediator: cannot evaluate in Julia (delegated to custom.cpp in PhysiCell)"))

# ─────────────────────────────────────────────────────────────────────────────
# Top-level behavior evaluation
# ─────────────────────────────────────────────────────────────────────────────

"""
    evaluateBehavior(behavior::Behavior, signals::AbstractDict{<:AbstractString,<:Real};
                     b_min=nothing, b_base=nothing, b_max=nothing) -> Float64

Evaluate the rule for `behavior` at the given raw signal values.

For a **setter** behavior, the returned value is the resulting behavior
value (`b'`). For an **accumulator** or **attenuator** behavior, the
returned value is the rate of change of the behavior (`r`) — the rate the
PhysiCell simulator then integrates over time.

`signals` must contain a raw value for every elementary signal name
referenced in the rule (`MissingSignalError` otherwise). `b_min` / `b_base`
/ `b_max` override the mediator's stored `min`/`base`/`max` values; pass
them explicitly to explore "what would this rule do if I changed the
max_response or base_value?"
"""
function evaluateBehavior(behavior::Behavior, signals::AbstractDict{<:AbstractString,<:Real};
                          b_min::Union{Nothing,Real}=nothing,
                          b_base::Union{Nothing,Real}=nothing,
                          b_max::Union{Nothing,Real}=nothing)
    return evaluateMediator(behavior.signal::MediatorSignal, signals;
                            b_min=b_min, b_base=b_base, b_max=b_max)
end

# ─────────────────────────────────────────────────────────────────────────────
# Helpers for the explorer UIs (recipes, HTML)
# ─────────────────────────────────────────────────────────────────────────────

"""
    elementarySignals(behavior::Behavior) -> Vector{ElementarySignal}

Collect every elementary signal referenced by `behavior` in
increasing-then-decreasing order. Repeated occurrences of the same signal
name are returned individually (a signal can appear once on the increasing
side and once on the decreasing side, with different transformer
parameters — both are knobs in the explorer).

Hierarchical sub-signals are not walked into (v1 limitation; see
[`UnsupportedRuleError`](@ref)).
"""
function elementarySignals(behavior::Behavior)
    out = ElementarySignal[]
    for branch in (behavior.signal.increasing_signal, behavior.signal.decreasing_signal)
        for s in branch.signals
            s isa ElementarySignal && push!(out, s)
        end
    end
    return out
end

"""
    rawSignalNames(behavior::Behavior) -> Vector{String}

Distinct raw signal names referenced by the rule (one per axis the user
can vary). Preserves order of first appearance.
"""
function rawSignalNames(behavior::Behavior)
    seen = String[]
    for s in elementarySignals(behavior)
        s.name in seen || push!(seen, s.name)
    end
    return seen
end

"""
    suggestSignalRange(signal::ElementarySignal) -> NTuple{2,Float64}

Return a sensible `(low, high)` range to vary `signal` over when plotting,
based on the transformer's natural scale (e.g. centred on `half_max`,
spanning `signal_min` and `signal_max`, or bracketing a `threshold`).
"""
function suggestSignalRange(s::PartialHillSignal)
    base = isnothing(s.reference) ? 0.0 : s.reference.value
    γ = s.p.half_max
    return (float(base), float(base + 3 * abs(γ - base)))
end
function suggestSignalRange(s::HillSignal)
    base = isnothing(s.reference) ? 0.0 : s.reference.value
    γ = s.p.half_max
    return (float(base), float(base + 3 * abs(γ - base)))
end
function suggestSignalRange(s::IdentitySignal)
    base = isnothing(s.reference) ? 0.0 : s.reference.value
    return (float(base), float(base + 1.0))
end
function suggestSignalRange(s::LinearSignal)
    w = s.signal_max - s.signal_min
    return (float(s.signal_min - 0.2w), float(s.signal_max + 0.2w))
end
function suggestSignalRange(s::HeavisideSignal)
    return (float(s.threshold - 1), float(s.threshold + 1))
end
