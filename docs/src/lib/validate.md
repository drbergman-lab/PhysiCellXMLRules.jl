```@meta
CollapsedDocStrings = true
```

# Validate

Validate an XML rules file against the standard, collecting errors and
warnings into a [`ValidationReport`](@ref). Parser errors at each `<behavior>`
boundary are caught individually, and semantic warnings (e.g. an accumulator
without `<behavior_saturation>`, or a redundant `<type>` on a Hill signal)
are also surfaced.

```@autodocs
Modules = [PhysiCellXMLRules]
Pages = ["validate.jl"]
```
