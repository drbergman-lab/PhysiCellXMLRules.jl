#=
Internal helpers for dose-response evaluation: given a parsed Behavior,
produce arrays of input signal values and rule outputs over those inputs.
Shared by the RecipesBase plot extension (and, later, by the interactive
HTML explorer or any other UI sitting on top of evaluateBehavior).

Not exported. Intended call sites are the package's own extensions or
internal docs.
=#

function _resolveRange(behavior::Behavior, name::AbstractString, override)
    if override isa Tuple{<:Real,<:Real}
        return (float(override[1]), float(override[2]))
    end
    for s in elementarySignals(behavior)
        s.name == name && return suggestSignalRange(s)
    end
    throw(ArgumentError("signal '$name' is not referenced by behavior '$(behavior.name)'"))
end

function _resolveFixedValue(behavior::Behavior, name::AbstractString, override)
    override isa Real && return float(override)
    lo, hi = _resolveRange(behavior, name, nothing)
    return 0.5 * (lo + hi)
end

function _baseSignals(behavior::Behavior,
                      varied::Tuple,
                      fixed::AbstractDict,
                      signal_ranges)
    signals = Dict{String,Float64}()
    range_dict = isnothing(signal_ranges) ? Dict{String,Tuple{Float64,Float64}}() : signal_ranges
    for name in rawSignalNames(behavior)
        name in varied && continue
        override = get(fixed, name, nothing)
        signals[name] = _resolveFixedValue(behavior, name, override)
    end
    return signals, range_dict
end

"""
    _doseResponse1D(behavior; vary, fixed=Dict(), n=200, signal_ranges=nothing,
                              b_min=nothing, b_base=nothing, b_max=nothing)
        -> (xs::Vector{Float64}, ys::Vector{Float64})

Sweep `vary` (a raw signal name in `behavior`) across its range (`signal_ranges[vary]`
or [`suggestSignalRange`](@ref) of the first matching elementary signal) at `n` points,
holding every other raw signal in `behavior` at the value provided by `fixed`
(or the midpoint of its suggested range if absent). Returns the swept x
values and the corresponding `evaluateBehavior` outputs.
"""
function _doseResponse1D(behavior::Behavior;
                         vary::AbstractString,
                         fixed::AbstractDict = Dict{String,Float64}(),
                         n::Integer = 200,
                         signal_ranges = nothing,
                         b_min = nothing,
                         b_base = nothing,
                         b_max = nothing)
    base, range_dict = _baseSignals(behavior, (vary,), fixed, signal_ranges)
    lo, hi = _resolveRange(behavior, vary, get(range_dict, vary, nothing))
    xs = collect(range(lo, hi; length=n))
    ys = similar(xs)
    for (i, x) in pairs(xs)
        base[vary] = x
        ys[i] = evaluateBehavior(behavior, base; b_min=b_min, b_base=b_base, b_max=b_max)
    end
    return xs, ys
end

"""
    _doseResponse2D(behavior; vary, fixed=Dict(), n=50, signal_ranges=nothing,
                              b_min=nothing, b_base=nothing, b_max=nothing)
        -> (xs, ys, zs::Matrix{Float64})

Sweep two raw signal names (`vary = (xname, yname)`) across an n×n grid.
`zs[i, j]` is `evaluateBehavior(behavior, …)` at `(xs[j], ys[i])` — row-major
in the y-axis, matching most plotting libraries' surface/heatmap convention.
"""
function _doseResponse2D(behavior::Behavior;
                         vary::Tuple{<:AbstractString,<:AbstractString},
                         fixed::AbstractDict = Dict{String,Float64}(),
                         n::Integer = 50,
                         signal_ranges = nothing,
                         b_min = nothing,
                         b_base = nothing,
                         b_max = nothing)
    xname, yname = vary
    xname == yname && throw(ArgumentError("vary tuple must reference two distinct signals; got ('$xname','$yname')"))
    base, range_dict = _baseSignals(behavior, vary, fixed, signal_ranges)
    xlo, xhi = _resolveRange(behavior, xname, get(range_dict, xname, nothing))
    ylo, yhi = _resolveRange(behavior, yname, get(range_dict, yname, nothing))
    xs = collect(range(xlo, xhi; length=n))
    ys = collect(range(ylo, yhi; length=n))
    zs = Matrix{Float64}(undef, n, n)
    for (i, y) in pairs(ys), (j, x) in pairs(xs)
        base[xname] = x
        base[yname] = y
        zs[i, j] = evaluateBehavior(behavior, base; b_min=b_min, b_base=b_base, b_max=b_max)
    end
    return xs, ys, zs
end
