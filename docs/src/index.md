```@meta
CurrentModule = PhysiCellXMLRules
```

# PhysiCellXMLRules

Documentation for [PhysiCellXMLRules](https://github.com/drbergman-lab/PhysiCellXMLRules.jl).

PhysiCellXMLRules defines, parses, validates, and converts the XML rules
format consumed by the [extended PhysiCell rules
grammar](https://github.com/drbergman/PhysiCell/). The package lets you:

- [`writeXMLRules`](@ref) — convert a CSV rules file to the XML format
- [`exportCSVRules`](@ref) — export an XML rules file back to a (possibly
  lossy) CSV approximation
- [`parseRulesXML`](@ref) — parse an XML rules file into a typed Julia
  hierarchy (`BehaviorRuleset` → `Behavior` → `MediatorSignal` →
  `AggregatorSignal` → elementary signals)
- [`validateRulesXML`](@ref) — check that a rules XML file conforms to the
  standard and surface common modelling pitfalls
- [`summarizeRulesXML`](@ref) — print a human-readable tree view of every
  behavior in a rules XML file

See the [Guide](@ref Guide) for installation and a quick tour, the
[Features](@ref Features) page for the full list of supported transformers /
aggregators / mediators / behavior types, and the [Examples](@ref Examples)
page for worked rulesets.

```@index
```

```@autodocs
Modules = [PhysiCellXMLRules]
Pages = ["PhysiCellXMLRules.jl"]
```
