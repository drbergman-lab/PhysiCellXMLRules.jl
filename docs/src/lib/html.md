```@meta
CollapsedDocStrings = true
```

# Interactive HTML explorer

Write a single self-contained HTML file for exploring a rules XML
in the browser. The explorer renders every behavior as a 1D dose-response
line (or 2D heatmap when two distinct raw signals are varied), lets the
user retune mediator scalars, transformer parameters, axis assignments,
and signal-direction toggles live, and can save the (edited) rules back
out as XML.

```@autodocs
Modules = [PhysiCellXMLRules]
Pages = ["html.jl"]
```
