```@meta
CollapsedDocStrings = true
```

# Parse

Parse an XML rules file into a typed `Vector{BehaviorRuleset}` hierarchy.
The parser is strict (the first malformed behavior raises an
`ArgumentError`); see [Validate](validate.md) for a collect-errors variant.

```@autodocs
Modules = [PhysiCellXMLRules]
Pages = ["parse_xml.jl"]
```
