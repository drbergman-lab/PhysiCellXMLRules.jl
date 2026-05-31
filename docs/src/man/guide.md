# [Guide](@id Guide)

## Getting started
### Download julia
See [here](https://julialang.org/downloads/) for more options:
```sh
$ curl -fsSL https://install.julialang.org | sh
```
Note: this command also installs the [JuliaUp](https://github.com/JuliaLang/juliaup) installation manager, which will automatically install julia and help keep it up to date.

### Add the BergmanLabRegistry
Launch julia by running `julia` in a shell.
Then, enter the Pkg REPL by pressing `]`.
Finally, add the BergmanLabRegistry by running:
```
pkg> registry add https://github.com/drbergman-lab/BergmanLabRegistry
```

### Install PhysiCellXMLRules
Still in the Pkg REPL, run:
```
pkg> add PhysiCellXMLRules
```

## What this package does
PhysiCellXMLRules is the Julia-side reference implementation of the rules XML
standard consumed by the extended PhysiCell rules grammar. The package
exposes these workflows on top of that standard:

| Function                                  | Purpose                                                                     |
|-------------------------------------------|-----------------------------------------------------------------------------|
| [`writeXMLRules`](@ref)                   | CSV → XML, or `Vector{BehaviorRuleset}` → XML (round-trip).                 |
| [`exportCSVRules`](@ref)                  | Export a (possibly hierarchical) XML rules file to an annotated CSV.        |
| [`parseRulesXML`](@ref)                   | Parse an XML rules file into a typed `Vector{BehaviorRuleset}`.             |
| [`validateRulesXML`](@ref)                | Validate an XML rules file and return a [`ValidationReport`](@ref).         |
| [`summarizeRulesXML`](@ref)               | Print a human-readable, indented summary of every behavior in a rules XML.  |
| [`evaluateBehavior`](@ref)                | Compute the rule's output at given raw signal values.                       |
| [`exportInteractiveHTML`](@ref)           | Write a single self-contained HTML for browsing the rules in a browser.     |
| Plots recipe                              | `plot(behavior; vary=…)` for 1D/2D dose-response (loaded with `Plots`).     |

The full list of XML elements, attributes, and acceptable values is on the
[Features](@ref Features) page; worked rulesets are on the
[Examples](@ref Examples) page.

## Converting CSV ↔ XML

```julia
using PhysiCellXMLRules
writeXMLRules("rules.xml", "rules.csv")     # CSV → XML
exportCSVRules("rules.csv", "rules.xml")    # XML → annotated CSV
```

`exportCSVRules` adds a comment header and a per-cell-type / per-behavior tree
of comments above each row, so the CSV doubles as a human-readable
description of the XML. The CSV format is a strict subset of the XML format,
so the conversion can be lossy when the XML contains hierarchical signals,
custom mediators or aggregators, or accumulator/attenuator behaviors.

## Parsing, validating, and summarising an XML rules file

```julia
using PhysiCellXMLRules

# Validate first — collects multiple errors and warnings into one report.
report = validateRulesXML("config/cell_rules.xml")
isvalid(report) || error("rules XML has problems:\n", report)

# Parse into a typed tree.
rulesets = parseRulesXML("config/cell_rules.xml")

# Inspect a specific behavior.
ruleset = rulesets[1]
behavior = ruleset.behaviors[1]
behavior.signal.mediator         # e.g. "decreasing_dominant"
behavior.signal.increasing_signal.aggregator  # e.g. "multivariate_hill"

# Or print a tree view of the whole file.
summarizeRulesXML("config/cell_rules.xml")
```

[`parseRulesXML`](@ref) is strict (the first malformed behavior raises). When
you need a per-behavior report instead, use [`validateRulesXML`](@ref), which
catches errors at the `<behavior>` boundary and also emits semantic warnings
(e.g. an accumulator with no `<behavior_saturation>`).

## Saving an edited rules tree back to XML

`writeXMLRules` has two methods: one takes a CSV path, the other takes an
already-parsed `Vector{BehaviorRuleset}`. The latter lets you parse, mutate,
and serialise without leaving Julia:

```julia
rulesets = parseRulesXML("config/cell_rules.xml")
# … edit rulesets in place …
writeXMLRules("config/cell_rules.modified.xml", rulesets; force=true)
```

The writer auto-assigns `id` attributes when sibling signals share a name
or a composite type, so the resulting XML is unambiguous and re-parses to
exactly the same typed tree.

## Evaluating a rule at chosen signal values

```julia
behavior = rulesets[1].behaviors[1]
evaluateBehavior(behavior, Dict("time" => 25.0))            # b' for a setter
evaluateBehavior(behavior, Dict("oxygen" => 7, "pressure" => 0.3))
```

For accumulator/attenuator behaviors the returned value is the rate of
change `r` rather than a behavior value. You can override the mediator's
stored max/base/max-response per call (`b_min=`, `b_base=`, `b_max=`) to
explore "what would happen if …" without mutating the tree.

## Dose-response plots (Plots.jl recipe)

Load `Plots` and a behavior becomes plottable directly:

```julia
using Plots, PhysiCellXMLRules
rulesets = parseRulesXML("config/cell_rules.xml")
b = rulesets[1].behaviors[1]

plot(b; vary="time")                       # 1D dose-response line
plot(b; vary=("oxygen", "pressure"))       # 2D heatmap
plot(b; vary="time",
       signal_ranges=Dict("time" => (0, 60)),
       fixed=Dict("damage" => 0.2))
```

`RecipesBase` is a *weak* dependency — no plotting deps for users who
don't need them. The recipe is for the Plots ecosystem; Makie uses a
different recipe system and is not currently supported.

## Interactive HTML explorer

For a richer, mouseable view, generate a self-contained HTML file:

```julia
exportInteractiveHTML("explorer.html", "config/cell_rules.xml"; force=true)
```

Open the file in any browser. The explorer has cell-type / behavior
dropdowns, a sidebar of signal cards (axis selector x / y / fixed, value
or range inputs, transformer parameter inputs, direction toggles for
Linear/Heaviside), a plot pane that re-renders on any change, and a
"Save XML" button that downloads the (possibly edited) tree back as XML.
Plotly is pulled from a CDN at view time, so no Julia runtime is required
to use the file.

See the [Examples](@ref Examples) page for screenshots and walked-through
behaviors from the bundled test fixtures.
