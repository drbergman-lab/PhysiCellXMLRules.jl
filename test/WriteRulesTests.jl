using CSV, DataFrames, PhysiCellXMLRules, LightXML

csv_text = """
// rules

cell_type_1,pressure,decreases,cycle entry,0.0,0.5,4.0,0
cell_type_1,contact with cell_type_5,increases,transform to cell_type_2,0.0001,0.01,4.0,0
cell_type_2,substrate_1,decreases,migration speed,0.0,0.5,4.0,0
cell_type_2,substrate_2,decreases,transform to cell_type_1,0.0,0.2,4.0,0
cell_type_3,pressure,decreases,cycle entry,0.0,1.0,4.0,0
cell_type_3,contact with cell_type_5,increases,transform to cell_type_4,0.0001,0.01,4.0,0
cell_type_4,substrate_1,decreases,migration speed,0.0,0.5,4.0,0
cell_type_4,substrate_2,decreases,transform to cell_type_3,0.0,0.2,4.0,0
cell_type_5,custom:sample,increases,custom:sample,100.0,0.01,4.0,0
"""

open("cell_rules.csv", "w") do f
    write(f, csv_text)
end

writeXMLRules("./test.xml", "./cell_rules.csv")
n_rules = readchomp(`grep -c "<signal" ./test.xml`) |> x->parse(Int, x)
@test n_rules == countlines(IOBuffer(csv_text)) - 2
xml_lines = readlines("./test.xml")
@test [contains(xml_line, "<behavior name=\"custom:sample\"") for xml_line in xml_lines] |> sum == 1 # should be exactly one custom sample behavior
@test [contains(xml_line, "<signal name=\"custom:sample\"") for xml_line in xml_lines] |> sum == 1 # should be exactly one custom sample signal

# ----------------------------
open("cell_rules_empty.csv", "w") do f
    write(f, "")
end

writeXMLRules("./test_empty.xml", "./cell_rules_empty.csv")
n_lines = open("./test_empty.xml", "r") do f; countlines(f); end
@test n_lines == 2 # the encoding line and the </hypothesis_rulesets> line

# ----------------------------
open("cell_rules_emptyish.csv", "w") do f
    write(f, "//\n")
end

writeXMLRules("./test_emptyish.xml", "./cell_rules_emptyish.csv")
n_lines = open("./test_emptyish.xml", "r") do f; countlines(f); end
@test n_lines == 2 # the encoding line and the </hypothesis_rulesets> line

# test errors
behavior_element = new_element("behavior")
@test_throws ArgumentError PhysiCellXMLRules.getElement(behavior_element, "signals"; require_exist=true)

increasing_signals = PhysiCellXMLRules.createElement(behavior_element, "increasing_signals")
@test_throws ArgumentError PhysiCellXMLRules.createElement(behavior_element, "increasing_signals")

PhysiCellXMLRules.createElementByAttribute(increasing_signals, "signal", "name", "pressure")
@test_throws ArgumentError PhysiCellXMLRules.createElementByAttribute(increasing_signals, "signal", "name", "pressure")

@test_throws ArgumentError PhysiCellXMLRules.getElementByAttribute(increasing_signals, "signal", "name", "oxygen"; require_exist=true)

#! Test more advanced rules
csv_text = """
cell_type_1,pressure (from 0.25),decreases,cycle entry,0.0,0.5,4.0,0
cell_type_1,(decreasing) oxygen (from 5.0),increases,cycle entry,2.0,0.5,4.0,0
cell_type_1,oxygen (from 15.0),decreases (hill),custom:glucose,2.0,20.0,4.0,0
cell_type_2,pressure,increases (linear),cycle entry,0.1,0.5,1.2,0
cell_type_3,(decreasing) custom:sample,increases (heaviside),migration speed,0.1,0.5,,0
cell_type_3,(decreasing) custom:sample,increases (heaviside),migration speed,0.1,0.5,,0
cell_type_4,(decreasing) custom:sample (from 2.0),increases (identity),migration speed,0.1,,,0
"""

open("cell_rules_advanced.csv", "w") do f
    write(f, csv_text)
end

writeXMLRules("./test_advanced.xml", "./cell_rules_advanced.csv")

#! test hierarchical rules
advanced_xml_doc = XMLDocument()
xml_root = create_root(advanced_xml_doc, "behavior_rulesets")

cell_type = "cd8"
behavior_name = "attack cancer"

decreasing_signal_1 = PhysiCellXMLRules.PartialHillSignal("pressure", 0.5, 4.0, false)

elem_signal_1 = PhysiCellXMLRules.HillSignal("oxygen", 2.0, 20.0, false)
elem_signal_2 = PhysiCellXMLRules.HeavisideSignal("glucose", 10.0, true)
decreasing_signal_2 = PhysiCellXMLRules.MediatorSignal([elem_signal_1], [elem_signal_2])

decreasing_signals = [decreasing_signal_1, decreasing_signal_2] |> PhysiCellXMLRules.AggregatorSignal

aggregator = PhysiCellXMLRules.AggregatorSignal(PhysiCellXMLRules.LinearSignal("contact with cancer", 0.8, 2.2, false))
increasing_signals = PhysiCellXMLRules.AggregatorSignal(aggregator)

min, base, max = 0.1, 0.5, 1.2
mediator = PhysiCellXMLRules.MediatorSignal(decreasing_signals, increasing_signals, min, base, max)
behavior = PhysiCellXMLRules.Behavior(behavior_name, mediator)
PhysiCellXMLRules.addRule!(xml_root, cell_type, behavior)

save_file(advanced_xml_doc, "./test_super_advanced.xml")

#! test behavior with non-mediator signal
@test_throws ArgumentError PhysiCellXMLRules.Behavior("cycle entry", aggregator)

#! Test write on pseudo-exported csv
csv_text = """
// XML Rules Export
// cell_type,signal,response,behavior,max_response,half_max,hill_power,applies_to_dead

// cancer
//   cycle entry
//     decreasing to 0.0
cancer,pressure,decreases,cycle entry,0.0,0.5,8,0
//   apoptosis
//     increasing to 1.0
cancer,damage,increases,apoptosis,1.0,30,10,0
//   debris secretion
//     increasing to 1.0
cancer,dead,increases,debris secretion,1.0,1e-10,1,1

// cd8
//   migration bias
//     increasing to 0.5
cd8,debris gradient,increases,migration bias,0.5,1e-3,2,0
"""

open("exported_cell_rules.csv", "w") do f
    write(f, csv_text)
end

writeXMLRules("./test_on_exported.xml", "./exported_cell_rules.csv")
n_rules = readchomp(`grep -c "<signal" ./test_on_exported.xml`) |> x->parse(Int, x)
@test n_rules == 4 #! the number of rules in the csv file

@test_throws AssertionError writeXMLRules("./test_on_exported.xml", "./exported_cell_rules.csv")
writeXMLRules("./test_on_exported.xml", "./exported_cell_rules.csv"; force=true)

#! test bad csv
csv_text = """
// note that this line only has 7 columns (missing the applie_to_dead column)
cell_type_1,pressure,decreases,cycle entry,0,0.5,4
"""
open("bad_cell_rules.csv", "w") do f
    write(f, csv_text)
end
@test_throws AssertionError writeXMLRules("./test_bad_exported.xml", "./bad_cell_rules.csv")