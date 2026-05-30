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
exposes five workflows on top of that standard:

| Function                                  | Purpose                                                                     |
|-------------------------------------------|-----------------------------------------------------------------------------|
| [`writeXMLRules`](@ref)                   | Convert a legacy CSV rules file to the XML format.                          |
| [`exportCSVRules`](@ref)                  | Export a (possibly hierarchical) XML rules file to an annotated CSV.        |
| [`parseRulesXML`](@ref)                   | Parse an XML rules file into a typed `Vector{BehaviorRuleset}`.             |
| [`validateRulesXML`](@ref)                | Validate an XML rules file and return a [`ValidationReport`](@ref).         |
| [`summarizeRulesXML`](@ref)               | Print a human-readable, indented summary of every behavior in a rules XML. |

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
