using PhysiCellXMLRules

function compare_csvs(csv_original::AbstractString, csv_exported::AbstractString)
    csv_original_text = readlines(csv_original)
    csv_exported_test = readlines(csv_exported)

    for line in csv_original_text
        if isempty(line) || startswith(line, "//")
            continue
        end
        @test line in csv_exported_test
    end
    
    for line in csv_exported_test
        line = lstrip(line)
        if isempty(line) || startswith(line, "//")
            continue
        end
        @test line in csv_original_text
    end
end

xml_csv_pairs = [
    ("./test.xml", "./cell_rules.csv"),
    ("./test_empty.xml", "./cell_rules_empty.csv"),
    ("./test_emptyish.xml", "./cell_rules_emptyish.csv"),
    ("./test_advanced.xml", "./cell_rules_advanced.csv"),
]

for (path_to_xml, path_to_original_csv) in xml_csv_pairs
    path_to_csv = "$(split(path_to_original_csv, ".csv")[1])_exported.csv"
    exportCSVRules(path_to_csv, path_to_xml)
    compare_csvs(path_to_original_csv, path_to_csv)
end

exportCSVRules("./test_super_advanced.csv", "./test_super_advanced.xml")

#! test export without specifying elementary signal type
xml_doc = XMLDocument()
xml_root = create_root(xml_doc, "behavior_rulesets")

cell_type = "cd8"
e = new_child(xml_root, "behavior_ruleset")
set_attribute(e, "name", cell_type)

behavior_name = "attack cancer"
e = new_child(e, "behavior")
set_attribute(e, "name", behavior_name)

e_decreasing = new_child(e, "decreasing_signals") 
e_max_response = new_child(e_decreasing, "max_response")
set_content(e_max_response, "0.5")
e_signal = new_child(e_decreasing, "signal")
set_attribute(e_signal, "name", "pressure")

e_half_max = new_child(e_signal, "half_max")
set_content(e_half_max, "4.0")
e_hill_power = new_child(e_signal, "hill_power")
set_content(e_hill_power, "2.0")
e_applies_to_dead = new_child(e_signal, "applies_to_dead")
set_content(e_applies_to_dead, "0")

save_file(xml_doc, "./test_elementary_sans_type.xml")
exportCSVRules("./test_elementary_sans_type.csv", "./test_elementary_sans_type.xml")

@test_throws AssertionError exportCSVRules("./test_elementary_sans_type.csv", "./test_elementary_sans_type.xml")
exportCSVRules("./test_elementary_sans_type.csv", "./test_elementary_sans_type.xml"; force=true)

#! test export with unsupported elementary signal type
set_attribute(e_signal, "type", "unsupported_type")
save_file(xml_doc, "./test_elementary_unsupported_type.xml")
@test_throws PhysiCellXMLRules.UnsupportedSignalTypeError exportCSVRules("./test_elementary_unsupported_type.csv", "./test_elementary_unsupported_type.xml")
try
    exportCSVRules("./test_elementary_unsupported_type_2.csv", "./test_elementary_unsupported_type.xml")
catch e
    @test e isa PhysiCellXMLRules.UnsupportedSignalTypeError
    @test e.cell_type == cell_type
    @test e.behavior_name == behavior_name
    @test e.signal_name == "pressure"
    @test e.signal_type == "unsupported_type"
    showerror(stdout, e)
end

#! test export with missing max_response in aggregator
xml_doc = XMLDocument()
xml_root = create_root(xml_doc, "behavior_rulesets")
cell_type = "cd8"
e = new_child(xml_root, "behavior_ruleset")
set_attribute(e, "name", cell_type)
behavior_name = "attack cancer"
e = new_child(e, "behavior")
set_attribute(e, "name", behavior_name)
e_increasing = new_child(e, "increasing_signals") 
e_signal_1 = new_child(e_increasing, "signal")
set_attribute(e_signal_1, "name", "debris gradient")
e_half_max_1 = new_child(e_signal_1, "half_max")
set_content(e_half_max_1, "1e-3")
e_hill_power_1 = new_child(e_signal_1, "hill_power")
set_content(e_hill_power_1, "2")
e_applies_to_dead_1 = new_child(e_signal_1, "applies_to_dead")
set_content(e_applies_to_dead_1, "0")
save_file(xml_doc, "./test_missing_max_response.xml")
exportCSVRules("./test_missing_max_response.csv", "./test_missing_max_response.xml")

#! test applies_to_dead export
function applies_to_dead_column(path_to_csv::AbstractString)
    lines = readlines(path_to_csv) .|> strip
    filter!(line -> !isempty(line) && !startswith(line, "//"), lines)
    return [split(line, ",")[end] for line in lines]
end

#! applies_to_dead=1 must survive the CSV -> XML -> CSV round trip for every
#! elementary signal type
csv_text = """
cancer,pressure,decreases,cycle entry,0.0,0.5,8.0,0
cancer,dead,increases,debris secretion,1.0,1.0e-10,1.0,1
cd8,damage,increases (hill),apoptosis,1.0,30.0,10.0,1
cd8,oxygen,increases (identity),migration speed,1.0,,,1
cd8,pressure,increases (linear),migration bias,1.0,0.5,1.2,1
cd8,time,increases (heaviside),attack cancer,1.0,10.0,,1
"""

open("cell_rules_applies_to_dead.csv", "w") do f
    write(f, csv_text)
end

writeXMLRules("./test_applies_to_dead.xml", "./cell_rules_applies_to_dead.csv")
exportCSVRules("./cell_rules_applies_to_dead_exported.csv", "./test_applies_to_dead.xml")
compare_csvs("./cell_rules_applies_to_dead.csv", "./cell_rules_applies_to_dead_exported.csv")
@test applies_to_dead_column("./cell_rules_applies_to_dead_exported.csv") == ["0", "1", "1", "1", "1", "1"]

#! 0/1/true/false are all accepted (case- and whitespace-insensitively) and an
#! absent or empty <applies_to_dead> means the rule does not apply to dead cells
xml_doc = XMLDocument()
xml_root = create_root(xml_doc, "behavior_rulesets")
e = new_child(xml_root, "behavior_ruleset")
set_attribute(e, "name", "cd8")
e = new_child(e, "behavior")
set_attribute(e, "name", "attack cancer")
e_increasing = new_child(e, "increasing_signals")
set_content(new_child(e_increasing, "max_response"), "1.0")

applies_to_dead_variants = ["1", "true", " TRUE ", "0", "false", " False ", nothing, ""]
for (i, applies_to_dead) in enumerate(applies_to_dead_variants)
    e_variant = new_child(e_increasing, "signal")
    set_attribute(e_variant, "name", "signal_$i")
    set_content(new_child(e_variant, "half_max"), "1.0")
    set_content(new_child(e_variant, "hill_power"), "2.0")
    isnothing(applies_to_dead) || set_content(new_child(e_variant, "applies_to_dead"), applies_to_dead)
end

save_file(xml_doc, "./test_applies_to_dead_variants.xml")
exportCSVRules("./test_applies_to_dead_variants.csv", "./test_applies_to_dead_variants.xml")
@test applies_to_dead_column("./test_applies_to_dead_variants.csv") == ["1", "1", "1", "0", "0", "0", "0", "0"]

#! an unparseable <applies_to_dead> is an error rather than a silent 0
e_signal = new_child(e_increasing, "signal")
set_attribute(e_signal, "name", "unparseable")
set_content(new_child(e_signal, "half_max"), "1.0")
set_content(new_child(e_signal, "hill_power"), "2.0")
set_content(new_child(e_signal, "applies_to_dead"), "maybe")
save_file(xml_doc, "./test_applies_to_dead_unparseable.xml")
@test_throws ArgumentError exportCSVRules("./test_applies_to_dead_unparseable.csv", "./test_applies_to_dead_unparseable.xml")


#! test that a composite signal does not truncate its aggregator
#! the same ruleset must export the same rows regardless of where the composite
#! signal sits among its siblings
function export_rows(rulesets, tag::AbstractString)
    path_to_xml = "./test_composite_siblings_$(tag).xml"
    path_to_csv = "./test_composite_siblings_$(tag).csv"
    writeXMLRules(path_to_xml, rulesets; force=true)
    exportCSVRules(path_to_csv, path_to_xml; force=true)
    lines = readlines(path_to_csv) .|> strip
    filter!(line -> !isempty(line) && !startswith(line, "//"), lines)
    return lines
end

function composite_sibling_rulesets(mediator_first::Bool)
    elementary = PhysiCellXMLRules.PartialHillSignal("pressure", 0.5, 4.0, false)
    nested = PhysiCellXMLRules.MediatorSignal([PhysiCellXMLRules.HillSignal("oxygen", 2.0, 20.0, false)],
                                              [PhysiCellXMLRules.HeavisideSignal("glucose", 10.0, false)])
    signals = mediator_first ? [nested, elementary] : [elementary, nested]
    increasing_signals = PhysiCellXMLRules.AggregatorSignal(PhysiCellXMLRules.AbstractSignal[signals...])
    mediator = PhysiCellXMLRules.MediatorSignal(PhysiCellXMLRules.AggregatorSignal(PhysiCellXMLRules.AbstractSignal[]),
                                                increasing_signals, nothing, 0.5, 1.2)
    return [BehaviorRuleset("cd8", [PhysiCellXMLRules.Behavior("attack cancer", mediator)])]
end

rows_elementary_first = export_rows(composite_sibling_rulesets(false), "elementary_first")
rows_mediator_first = export_rows(composite_sibling_rulesets(true), "mediator_first")

#! the elementary sibling is exportable on its own and must survive either ordering
@test "cd8,pressure,increases,attack cancer,1.2,0.5,4.0,0" in rows_elementary_first
@test "cd8,pressure,increases,attack cancer,1.2,0.5,4.0,0" in rows_mediator_first
@test sort(rows_elementary_first) == sort(rows_mediator_first)
@test length(rows_mediator_first) == 3
