# Guide

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

## Using PhysiCellXMLRules
To convert a PhysiCell rules file (in CSV format) into an XML format, use
```
using PhysiCellXMLRules
new_file = "rules.xml"
source_file = "rules.csv"
writeXMLRules(new_file, source_file)
```

To convert from the XML format to the CSV format, use
```
using PhysiCellXMLRules
new_file = "rules.csv"
source_file = "rules.xml"
exportCSVRules(new_file, source_file)
```