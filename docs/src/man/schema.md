# [XSD schema](@id Schema)

The repository ships an XML Schema Definition for the rules XML
grammar:

```
schemas/cell_rules.xsd
```

It is the machine-readable counterpart to the [Features](@ref Features)
page. Two audiences:

- **Editor / IDE tooling.** Any editor that understands XSD (oXygen,
  IntelliJ, Visual Studio Code with an XML extension, vim with one of
  the XML LSP servers, …) can attach the schema and give you element
  autocomplete, attribute hints, and inline validation as you type a
  rules XML file.
- **External validators.** Run a one-shot check against any rules file
  without spinning up Julia:

```sh
xmllint --schema schemas/cell_rules.xsd --noout my_cell_rules.xml
```

## What the schema enforces

- Root is `<behavior_rulesets>`, containing `<behavior_ruleset
  name="…">` children, each containing `<behavior name="…">`s.
- Element names (e.g. `<half_max>`, `<applies_to_dead>`,
  `<reference>`, `<aggregator>`, `<mediator>`) and attribute names
  (`name`, `type`, `id`).
- Value enumerations for the `type` / `mediator` / `aggregator` /
  `<type>` (direction) / behavior-`<type>` slots. Common
  capitalisations (snake_case, CamelCase) are accepted; other casings
  parse in Julia but won't pass the schema.
- Numeric content where numeric, boolean content where boolean.
- The optional positive-integer `id` attribute on `<signal>` elements.
- Annotation attributes — most commonly `note="..."` for inline human
  documentation — pass through on every value element.

## What the schema does *not* enforce

These constraints can't be expressed in XSD 1.0 and remain the job of
[`validateRulesXML`](@ref):

- The **discriminated child elements** of a `<signal>` based on its
  `type` attribute (e.g. `type="hill"` requires `<half_max>` and
  `<hill_power>`; `type="linear"` requires `<signal_min>` and
  `<signal_max>`). The schema allows any combination of the legal
  child elements.
- **Mediator monotonicity**: `<max_response>` of the decreasing branch
  ≤ `<base_value>` ≤ `<max_response>` of the increasing branch.
- `<behavior_base>` and `<behavior_saturation>` being meaningful
  **only when `<type>` is `accumulator` or `attenuator`**. The schema
  permits them on any behavior.
- A Hill / PartialHill `<reference>` value being in the support of
  `<half_max>`.

The recommended workflow is: schema validation as a fast structural
gate (editors, CI), then [`validateRulesXML`](@ref) for the semantic
checks above plus warnings (accumulator missing `<behavior_saturation>`,
redundant `<type>` on a Hill signal, etc.).
