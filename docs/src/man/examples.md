# [Examples](@id Examples)

The PhysiCell sample project `template_xml_rules_extended` ships a
[`cell_rules.xml`](https://github.com/drbergman/PhysiCell/blob/1.14.2-drbergman-2.1.2/sample_projects/template_xml_rules_extended/config/cell_rules.xml)
that exercises every feature of the standard. This page walks through a
representative subset; each "cell type" in that file is really a single
ruleset designed to isolate one feature. Driving the simulation with each
cell type in turn is the easiest way to build intuition for how the
ingredients combine.

The signal driving every ruleset in the fixture is `time` and the behavior
under control is `custom:sample`. That makes it easy to plot `custom:sample`
against simulation time and read off the transformer / aggregator / mediator
shape directly.

## Increasing partial Hill

```xml
<behavior_ruleset name="increasing_partial_hill">
    <behavior name="custom:sample">
        <increasing_signals>
            <max_response>1</max_response>
            <signal name="time" type="PartialHill">
                <half_max>30</half_max>
                <hill_power>2</hill_power>
                <applies_to_dead>0</applies_to_dead>
            </signal>
        </increasing_signals>
    </behavior>
</behavior_ruleset>
```

`custom:sample` rises monotonically with `time` toward `max_response = 1`.
At `time = 30` the partial-Hill output is `(30/30)² = 1`, which the default
`multivariate_hill` aggregator passes through as `1/(1+1) = 0.5` — so the
behavior is at 50% of its `max_response` at the half-max.

## Decreasing partial Hill via a reference

```xml
<signal name="time" type="PartialHill">
    <half_max>30</half_max>
    <hill_power>2</hill_power>
    <applies_to_dead>0</applies_to_dead>
    <reference>
        <type>decreasing</type>
        <value>60</value>
    </reference>
</signal>
```

The same partial-Hill transformer, but now driven by `60 − time` (clamped
to 0). At `time = 0` the input is 60, the half-max is shifted to 30, so the
behavior is high; at `time ≥ 60` the input is 0, so the behavior collapses
back to base.

## Mediator variants

The fixture contains four "mediator" rulesets with identical signals but
different mediators (`decreasing_dominant`, `increasing_dominant`, `neutral`,
and `custom`). Compare them to see how each formula trades off the
contributions of `D` and `U`.

```xml
<behavior_ruleset name="neutral_mediator_hill">
    <behavior name="custom:sample">
        <mediator>neutral</mediator>
        <decreasing_signals>
            <max_response>0</max_response>
            <signal name="time" type="PartialHill">
                <half_max>20</half_max>
                <hill_power>2</hill_power>
                <applies_to_dead>0</applies_to_dead>
            </signal>
        </decreasing_signals>
        <increasing_signals>
            <max_response>1</max_response>
            <signal name="time" type="PartialHill">
                <half_max>40</half_max>
                <hill_power>5</hill_power>
                <applies_to_dead>0</applies_to_dead>
            </signal>
        </increasing_signals>
    </behavior>
</behavior_ruleset>
```

Under the `neutral` mediator, the increasing and decreasing branches
contribute additively, so the behavior peaks where their net contribution
is largest. Compare with `decreasing_dominant_mediator_hill` (decreasing
fully overrides) and `increasing_dominant_mediator_hill` (increasing fully
overrides) in the same file.

## Mean aggregator

```xml
<increasing_signals>
    <aggregator>mean</aggregator>
    <max_response>1</max_response>
    <signal name="time" type="Heaviside">
        <type>increasing</type>
        <threshold>13.5</threshold>
        <applies_to_dead>0</applies_to_dead>
    </signal>
    <signal name="time" type="Heaviside">
        <type>increasing</type>
        <threshold>28.5</threshold>
        <applies_to_dead>0</applies_to_dead>
    </signal>
    <signal name="time" type="Heaviside">
        <type>increasing</type>
        <threshold>43.5</threshold>
        <applies_to_dead>0</applies_to_dead>
    </signal>
    <signal name="time" type="Heaviside">
        <type>increasing</type>
        <threshold>58.5</threshold>
        <applies_to_dead>0</applies_to_dead>
    </signal>
</increasing_signals>
```

Four step functions, averaged, produce a four-step staircase as `time`
crosses 13.5, 28.5, 43.5, and 58.5 — useful for piecewise-constant
behaviors. With `sum` instead of `mean` the same construction grows
unbounded; with `mean` the output stays in `[0, 1]`.

## Tent (rise then fall)

```xml
<behavior_ruleset name="tent">
    <behavior name="custom:sample">
        <increasing_signals>
            <aggregator>sum</aggregator>
            <max_response>1</max_response>
            <signal name="time" type="Linear">
                <signal_min>10</signal_min><signal_max>20</signal_max>
                <applies_to_dead>0</applies_to_dead>
            </signal>
        </increasing_signals>
        <decreasing_signals>
            <aggregator>sum</aggregator>
            <max_response>0</max_response>
            <signal name="time" type="Linear">
                <signal_min>40</signal_min><signal_max>50</signal_max>
                <applies_to_dead>0</applies_to_dead>
            </signal>
        </decreasing_signals>
    </behavior>
</behavior_ruleset>
```

Linear ramp up on `[10, 20]`, then a linear ramp down on `[40, 50]` driven
by the (default) `decreasing_dominant` mediator. The result is a tent
function in `time`.

## Accumulator

```xml
<behavior_ruleset name="accumulator">
    <behavior name="custom:sample">
        <type>accumulator</type>
        <behavior_saturation>1.0</behavior_saturation>
        <base_value>-0.05</base_value>
        <increasing_signals>
            <max_response>0.2</max_response>
            <aggregator>product</aggregator>
            <signal name="time" type="Hill">
                <half_max>5</half_max><hill_power>2</hill_power>
                <applies_to_dead>0</applies_to_dead>
            </signal>
            <signal name="time" type="Heaviside">
                <type>decreasing</type>
                <threshold>30</threshold>
                <applies_to_dead>0</applies_to_dead>
            </signal>
        </increasing_signals>
    </behavior>
</behavior_ruleset>
```

Here the mediator output is a *rate*, not a behavior value. The product
aggregator says: the rate goes positive only when *both* `time` is
sufficiently large (Hill) *and* `time < 30` (Heaviside). Otherwise the base
rate `r₀ = −0.05` pulls the behavior back toward the cell-type base. The
saturation `1.0` caps the accumulated value.

## Custom mediator / custom aggregator

```xml
<behavior_ruleset name="custom_mediator">
    <behavior name="custom:sample">
        <mediator>custom</mediator>
        ...
    </behavior>
</behavior_ruleset>
```

`custom` mediators and aggregators are *not* implemented in the XML
itself — they delegate to C++ functions you provide in PhysiCell's
`custom.cpp`. The signature is:

```cpp
// custom mediator (with access to MediatorSignal's min/base/max)
double f(MediatorSignal* pMS, std::vector<double> signals_in);
// or the simpler form
double f(std::vector<double> signals_in);

// custom aggregator
double f(std::vector<double> signals_in);
```

This package validates the XML and faithfully round-trips the `custom`
keyword, but cannot tell you whether the corresponding C++ hook is
registered — that's checked at simulation time. See the
`template_xml_rules_extended` sample project for an example registration.

## Inspecting an unfamiliar rules XML

For any rules XML you didn't write yourself, the fastest path to
understanding it is:

```julia
using PhysiCellXMLRules

report = validateRulesXML("config/cell_rules.xml")
println(report)             # surfaces any structural problems

summarizeRulesXML("config/cell_rules.xml")
```

A truncated sample of `summarizeRulesXML` against the fixture above:

```
cell_type: increasing_partial_hill
  behavior "custom:sample"  [setter]
    mediator: decreasing_dominant
      increasing_signals  [aggregator=multivariate_hill, max_response=1.0]
        signal "time": PartialHill(half_max=30.0, hill_power=2.0)  [applies_to_dead=false]

cell_type: tent
  behavior "custom:sample"  [setter]
    mediator: decreasing_dominant
      increasing_signals  [aggregator=sum, max_response=1.0]
        signal "time": Linear(increasing, signal_min=10.0, signal_max=20.0)  [applies_to_dead=false]
      decreasing_signals  [aggregator=sum, max_response=0.0]
        signal "time": Linear(increasing, signal_min=40.0, signal_max=50.0)  [applies_to_dead=false]

cell_type: accumulator
  behavior "custom:sample"  [accumulator, behavior_saturation=1.0]
    mediator: decreasing_dominant  [base_value=-0.05]
      increasing_signals  [aggregator=product, max_response=0.2]
        signal "time": Hill(half_max=5.0, hill_power=2.0)  [applies_to_dead=false]
        signal "time": Heaviside(decreasing, threshold=30.0)  [applies_to_dead=false]
```
