using PhysiCellXMLRules
using Documenter

DocMeta.setdocmeta!(PhysiCellXMLRules, :DocTestSetup, :(using PhysiCellXMLRules); recursive=true)

makedocs(;
    modules=[PhysiCellXMLRules],
    authors="Daniel Bergman <danielrbergman@gmail.com> and contributors",
    sitename="PhysiCellXMLRules.jl",
    format=Documenter.HTML(;
        canonical="https://drbergman-lab.github.io/PhysiCellXMLRules.jl",
        edit_link="main",
        assets=String[]
    ),
    pages=[
        "Home" => "index.md",
        "Manual" => Any[
            "Guide" => "man/guide.md"
        ],
        "Documentation" => map(
            s -> "lib/$(s)",
            sort(readdir(joinpath(@__DIR__, "src/lib")))
        ),
    ]
)

deploydocs(;
    repo="github.com/drbergman-lab/PhysiCellXMLRules.jl",
    devbranch="main",
    push_preview=true,
)
