# [Features](@id Features)

This page enumerates every element of the rules XML standard that the
package understands. Whenever a name is matched (e.g. an aggregator or
mediator name), matching is **case-insensitive and treats spaces,
underscores, and hyphens as equivalent** — so `partial_hill`, `partial
hill`, `Partial-Hill`, and `PartialHill` all parse identically.

A core design principle of the standard is that **the original PhysiCell
rules are the default**. If `type`, `aggregator`, and `mediator` elements
are omitted, you get the original rules grammar back.

## Document structure

```xml
<behavior_rulesets>
  <behavior_ruleset name="cell_type">
    <behavior name="behavior_name">
      <type>setter | accumulator | attenuator</type>          <!-- optional, default "setter" -->
      <base_value>...</base_value>                             <!-- optional; b₀ for setter, r₀ for acc/att -->
      <behavior_base>...</behavior_base>                       <!-- accumulator/attenuator only; overrides cell-type b₀ -->
      <behavior_saturation>...</behavior_saturation>           <!-- accumulator/attenuator only; bₛ -->
      <mediator>...</mediator>                                 <!-- optional, default "decreasing_dominant" -->
      <decreasing_signals> ... </decreasing_signals>           <!-- optional aggregator branch -->
      <increasing_signals> ... </increasing_signals>           <!-- optional aggregator branch -->
    </behavior>
  </behavior_ruleset>
</behavior_rulesets>
```

A `<decreasing_signals>` / `<increasing_signals>` branch is an aggregator:

```xml
<increasing_signals>
  <aggregator>...</aggregator>                                  <!-- optional, default "multivariate_hill" -->
  <max_response>...</max_response>                              <!-- b\_+ for setter, r₊ for accumulator -->
  <signal name="..." type="..."> ... </signal>
  ...                                                            <!-- any number of <signal> children -->
</increasing_signals>
```

A `<signal>` is either an *elementary* signal (a transformer applied to a
named PhysiCell signal), or a *composite* signal (a nested
`type="aggregator"` or `type="mediator"`). The default elementary type is
`partial_hill`.

## Elementary signals (transformers)

Elementary signals first transform a raw PhysiCell signal (`s`) into a
single number, which is then passed to its enclosing aggregator. Each
`<signal>` element specifies the transformer via its `type` attribute.

| `type`         | Description                                                                                                                | Required children                            | Formula                                                              |
|----------------|----------------------------------------------------------------------------------------------------------------------------|---------------------------------------------|----------------------------------------------------------------------|
| `partial_hill` | default                                                                                                                    | `half_max` (γ), `hill_power` (n)            | (s/γ)ⁿ                                                                |
| `hill`         | Hill function                                                                                                              | `half_max` (γ), `hill_power` (n)            | x / (1 + x), where x = (s/γ)ⁿ                                         |
| `linear`       | linearly vary on [0,1] across a range of signal values, extending constantly outside                                       | `signal_min` (s₁), `signal_max` (s₂)        | (s−s₁)/(s₂−s₁) on [s₁,s₂] (or the reverse, depending on `<type>`)    |
| `heaviside`    | 0/1 depending on whether the signal is above/below a threshold                                                             | `threshold` (T)                             | H(s−T) or H(T−s) (depending on `<type>`)                              |
| `identity`     | identity function                                                                                                          | (none)                                      | s                                                                     |

Every elementary signal additionally requires `<applies_to_dead>0|1</applies_to_dead>`.

`linear` and `heaviside` accept a child `<type>increasing|decreasing</type>`
element that controls the direction of the transformer. The default is
`increasing`. `partial_hill`, `hill`, and `identity` are direction-agnostic
on their own — to express direction relative to a fixed point, use a
[reference value](#signal-reference-values) instead. (Including a
`<type>` child on a direction-agnostic transformer is permitted but
produces a validator warning since it has no effect.)

### XML examples

A default `partial_hill` (the `type` attribute is optional here since
`partial_hill` is the default):

```xml
<signal name="pressure" type="partial_hill">
    <half_max>0.5</half_max>
    <hill_power>2</hill_power>
    <applies_to_dead>0</applies_to_dead>
</signal>
```

A `linear` with explicit direction:

```xml
<signal name="oxygen" type="linear">
    <type>increasing</type>
    <signal_min>0</signal_min>
    <signal_max>10</signal_max>
    <applies_to_dead>0</applies_to_dead>
</signal>
```

## Signal reference values

For cases in which the signal is measured relative to a fixed point, a
`<reference>` element can be added inside an elementary signal:

```xml
<reference>
    <type>increasing | decreasing</type>
    <value>...</value>
</reference>
```

The difference between the raw signal and the reference value is what gets
passed to the transformer:

- `increasing` reference: difference is `s − s₀`.
- `decreasing` reference: difference is `s₀ − s`.

Whenever the difference is negative, `0` is passed on instead. Only
`partial_hill`, `hill`, and `identity` accept references. For `partial_hill`
and `hill`, the `half_max` must lie in the support of the reference (above
an increasing reference; below a decreasing one); the package adjusts
`half_max` so that the transformer still hits 0.5 at the documented
half-maximum point.

```xml
<signal name="contact with dead" type="partial_hill">
    <half_max>0.5</half_max>
    <hill_power>2</hill_power>
    <reference>
        <type>increasing</type>
        <value>0.25</value>
    </reference>
    <applies_to_dead>1</applies_to_dead>
</signal>
```

## Aggregators

An aggregator reduces a vector of constituent signals (`xᵢ`, after
transformation) to a single number. Aggregators live inside
`<decreasing_signals>` / `<increasing_signals>` branches (and inside nested
`<signal type="aggregator">` elements).

| `aggregator`         | Formula                          |
|----------------------|----------------------------------|
| `multivariate_hill`  | ∑xᵢ / (1 + ∑xᵢ)  *(default)*     |
| `sum`                | ∑xᵢ                              |
| `product`            | ∏xᵢ                              |
| `min`                | minᵢ xᵢ                          |
| `max`                | maxᵢ xᵢ                          |
| `mean`               | (1/n)·∑xᵢ                        |
| `median`             | median of xᵢ                     |
| `geometric_mean`     | (∏xᵢ)^(1/n)                      |
| `first`              | x₁ *(skips reduction; useful when there is only one signal)* |
| `custom`             | user-supplied in PhysiCell's `custom.cpp`: `double f(std::vector<double> signals_in);` |

```xml
<increasing_signals>
    <aggregator>sum</aggregator>
    <max_response>1.0</max_response>
    <signal name="oxygen" type="linear"> ... </signal>
    <signal name="glucose" type="linear"> ... </signal>
</increasing_signals>
```

## Mediators

A mediator combines the outputs of the decreasing-signals aggregator (`D`)
and the increasing-signals aggregator (`U`) into the final behavior value
(or, for accumulator/attenuator behaviors, the rate of change).
Mediators live as a child `<mediator>` element of `<behavior>` (or of a
nested `<signal type="mediator">`).

In the formulas below, `b\_-` is the decreasing `<max_response>`, `b₀` is
`<base_value>`, and `b\_+` is the increasing `<max_response>`.

| `mediator`           | Formula                                                  |
|----------------------|----------------------------------------------------------|
| `decreasing_dominant`| D·b\_- + (1−D)·((1−U)·b₀ + U·b\_+)  *(default)*           |
| `increasing_dominant`| U·b\_+ + (1−U)·((1−D)·b₀ + D·b\_-)                         |
| `neutral`            | b₀ + D·(b\_- − b₀) + U·(b\_+ − b₀)                         |
| `custom`             | user-supplied: `double f(MediatorSignal* pMS, std::vector<double> signals_in);` (or the no-`pMS` overload) |

```xml
<behavior name="migration speed">
    <mediator>increasing_dominant</mediator>
    <increasing_signals> ... </increasing_signals>
    <decreasing_signals> ... </decreasing_signals>
</behavior>
```

## Behavior types: setter, accumulator, attenuator

A `<type>` element directly inside a `<behavior>` chooses how the mediator
output is interpreted:

- `setter` (default) — the mediator output is *the behavior value*. The
  cell's behavior is set directly to `b' = mediator(D, U)`.
- `accumulator` — the mediator output is the *rate of change* of the
  behavior; positive rates push the behavior toward `behavior_saturation`,
  negative rates push toward `behavior_base`.
- `attenuator` — same mechanism as `accumulator`, but used when the
  saturation is "below" the base (i.e. the behavior decays toward
  `behavior_saturation`).

For accumulator/attenuator behaviors, the rate-of-change parameterisation is:

- `<base_value>` = `r₀` (base rate, typically negative so the behavior
  relaxes to base in the absence of signals).
- `<decreasing_signals><max_response>` = `r₋` (typically negative).
- `<increasing_signals><max_response>` = `r₊` (typically positive).
- `<behavior_base>` = `b₀` (optional override of the cell-type's base
  behavior).
- `<behavior_saturation>` = `bₛ` (the saturation limit).

The behavior then evolves as

```math
b'(t) = \begin{cases}
|r|\,(b_0 - b), & r < 0 \\
0,              & r = 0 \\
|r|\,(b_s - b), & r > 0
\end{cases}
```

i.e. the behavior exponentially "decays" toward `b₀` (when `r<0`) or `bₛ`
(when `r>0`).

```xml
<behavior name="migration speed">
    <type>accumulator</type>
    <base_value note="r₀">-0.01</base_value>
    <behavior_base note="b₀">0.0</behavior_base>
    <behavior_saturation note="bₛ">5.0</behavior_saturation>
    <mediator>increasing_dominant</mediator>
    <decreasing_signals>
        <max_response note="r₋">-0.1</max_response>
        <aggregator>first</aggregator>
        <signal name="pressure" type="linear">
            <signal_min>0.2</signal_min>
            <signal_max>1.0</signal_max>
            <applies_to_dead>0</applies_to_dead>
        </signal>
    </decreasing_signals>
    <increasing_signals>
        <max_response note="r₊">0.2</max_response>
        <aggregator>first</aggregator>
        <signal name="oxygen" type="heaviside">
            <threshold>12.0</threshold>
            <applies_to_dead>0</applies_to_dead>
        </signal>
    </increasing_signals>
</behavior>
```

The validator emits a warning for any accumulator/attenuator without a
`<behavior_saturation>`, with no `<base_value>`, or with `<max_response>`
signs that contradict the relaxation semantics.

## Advanced: hierarchical signals

The standard does go deeper than the two-layer (mediator → aggregator)
structure described above. After the top mediator and aggregator layer,
**any signal can itself be a `<signal type="mediator">` or
`<signal type="aggregator">`** containing further children. The validator
and parser walk these recursively.

```xml
<behavior name="migration speed">
    <increasing_signals>
        <signal type="aggregator">
            <aggregator>product</aggregator>
            <signal name="oxygen" type="linear">
                <signal_min>0</signal_min><signal_max>10</signal_max>
                <applies_to_dead>0</applies_to_dead>
            </signal>
            <signal name="glucose" type="linear">
                <signal_min>0</signal_min><signal_max>10</signal_max>
                <applies_to_dead>0</applies_to_dead>
            </signal>
            <signal type="mediator">
                <mediator>neutral</mediator>
                <base_value>0.1</base_value>
                <decreasing_signals>
                    <max_response>0.01</max_response>
                    <signal name="pressure" type="partial_hill">
                        <half_max>0.5</half_max><hill_power>2</hill_power>
                        <applies_to_dead>0</applies_to_dead>
                    </signal>
                </decreasing_signals>
                <increasing_signals>
                    <max_response>1.0</max_response>
                    <signal name="contact with dead" type="heaviside">
                        <threshold>1</threshold>
                        <applies_to_dead>0</applies_to_dead>
                    </signal>
                </increasing_signals>
            </signal>
        </signal>
    </increasing_signals>
    <decreasing_signals/>
</behavior>
```

The expected user workflow is still the original two-layer shape (a
`decreasing_dominant` mediator over `multivariate_hill` aggregators over
`partial_hill` transformers); hierarchical signals are an escape hatch
for modellers who need to compose richer expressions.
