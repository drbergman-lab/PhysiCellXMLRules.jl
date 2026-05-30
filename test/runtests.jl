using PhysiCellXMLRules
using Test

# Clean leftover artifacts from prior test runs (xml/csv files generated
# directly in test/; assets/ is preserved).
for f in readdir(@__DIR__; join=true)
    isfile(f) && endswith(lowercase(f), r"\.(xml|csv)$") && rm(f; force=true)
end

@testset "PhysiCellXMLRules.jl" begin
    include("./WriteRulesTests.jl")
    include("./ExportRulesTests.jl")
    include("./ParseRulesTests.jl")
    include("./ValidateRulesTests.jl")
    include("./SummarizeRulesTests.jl")
    include("./EvaluateRulesTests.jl")
end
