```@meta
CollapsedDocStrings = true
```

# Evaluate

Evaluate a parsed rule at user-supplied raw signal values. The entry
point is [`evaluateBehavior`](@ref); the layer evaluators
(`evaluateMediator`, `evaluateAggregator`, `evaluateSignal`) and the UI
helpers (`elementarySignals`, `rawSignalNames`, `suggestSignalRange`)
are accessible via the `PhysiCellXMLRules.` prefix for white-box use
but are not part of the exported public API.

Custom mediators and aggregators (delegated to PhysiCell's `custom.cpp`)
and hierarchical sub-signals (slated for v2) raise
[`UnsupportedRuleError`](@ref) when encountered.

```@autodocs
Modules = [PhysiCellXMLRules]
Pages = ["evaluate.jl"]
```
