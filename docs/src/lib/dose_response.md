```@meta
CollapsedDocStrings = true
```

# Dose-response helpers

Internal helpers for sweeping a parsed `Behavior` over one or two raw
signals and collecting `evaluateBehavior` outputs. Shared by the
`RecipesBase` Plots recipe and the interactive HTML explorer; not part
of the exported public API but documented here for users building
their own visualisations on top of [`evaluateBehavior`](@ref).

```@autodocs
Modules = [PhysiCellXMLRules]
Pages = ["dose_response.jl"]
```
