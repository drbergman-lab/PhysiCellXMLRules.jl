using PhysiCellXMLRules, RecipesBase, Test
using PhysiCellXMLRules: _doseResponse1D, _doseResponse2D

const _FIXTURE = joinpath(@__DIR__, "assets", "extended_cell_rules.xml")

@testset "_doseResponse1D — tent shape" begin
    rulesets = parseRulesXML(_FIXTURE)
    by = Dict(rs.cell_type => rs for rs in rulesets)
    b = by["tent"].behaviors[1]
    xs, ys = _doseResponse1D(b; vary="time",
                             signal_ranges=Dict("time"=>(0.0, 60.0)),
                             n=61, b_base=0.0)
    @test length(xs) == 61
    @test length(ys) == 61
    @test xs[1]   == 0.0
    @test xs[end] == 60.0
    @test ys[findfirst(==(0.0),  xs)] ≈ 0.0
    @test ys[findfirst(==(20.0), xs)] ≈ 1.0
    @test ys[findfirst(==(45.0), xs)] ≈ 0.5
    @test ys[findfirst(==(60.0), xs)] ≈ 0.0
end

@testset "_doseResponse1D — defaults to suggested range and midpoints for fixed" begin
    rulesets = parseRulesXML(_FIXTURE)
    by = Dict(rs.cell_type => rs for rs in rulesets)
    b = by["increasing_partial_hill"].behaviors[1]
    xs, ys = _doseResponse1D(b; vary="time", n=50, b_base=0.0)
    @test issorted(xs)
    @test all(0 .≤ ys .≤ 1.0 + 1e-9)
end

@testset "_doseResponse1D — multi-occurrence range aggregation (tent)" begin
    # tent has two `time` Linear signals — increasing on (10,20) and on (40,50).
    # The default range should span both, and the lower bound should be ≥ 0.
    rulesets = parseRulesXML(_FIXTURE)
    by = Dict(rs.cell_type => rs for rs in rulesets)
    b = by["tent"].behaviors[1]
    xs, _ = _doseResponse1D(b; vary="time", n=20)
    @test xs[1]   ≥ 0
    @test xs[1]   < 10                # below the first linear's signal_min
    @test xs[end] > 50                # past the second linear's signal_max
end

@testset "_doseResponse2D — sanity over a hand-built behavior" begin
    # Two distinct raw signals 'x' (increasing) and 'y' (increasing); use
    # 'sum' aggregators so a single signal passes through cleanly.
    s_inc = PhysiCellXMLRules.LinearSignal("x", 0.0, 1.0, false, "increasing")
    s_dec = PhysiCellXMLRules.LinearSignal("y", 0.0, 1.0, false, "increasing")
    inc_agg = PhysiCellXMLRules.AggregatorSignal([s_inc], "sum")
    dec_agg = PhysiCellXMLRules.AggregatorSignal([s_dec], "sum")
    m = PhysiCellXMLRules.MediatorSignal(dec_agg, inc_agg, 0.0, 0.0, 1.0, "decreasing_dominant")
    b = PhysiCellXMLRules.Behavior("test", m)
    xs, ys, zs = _doseResponse2D(b; vary=("x","y"),
                                 signal_ranges=Dict("x"=>(0.0,1.0),"y"=>(0.0,1.0)),
                                 n=11)
    @test size(zs) == (11, 11)
    # At x=1, y=0: D=0, U=1; decreasing_dominant → 0·0 + 1·(0·0 + 1·1) = 1
    @test zs[findfirst(==(0.0), ys), findfirst(==(1.0), xs)] ≈ 1.0
    # At y=1: D=1 → 1·0 + 0·… = 0
    @test zs[findfirst(==(1.0), ys), findfirst(==(0.0), xs)] ≈ 0.0
end

@testset "Recipe — errors on bad vary" begin
    rulesets = parseRulesXML(_FIXTURE)
    b = rulesets[1].behaviors[1]
    @test_throws ArgumentError _doseResponse1D(b; vary="not_a_signal")
    @test_throws ArgumentError _doseResponse2D(b; vary=("time","time"))
end

@testset "Recipe — extension loaded and registered" begin
    # Verify the extension module is present and registered an apply_recipe
    # method for Behavior. We can't *invoke* the recipe here without a
    # plotting frontend (Plots.jl provides `is_key_supported`), but its
    # presence is a useful smoke test that the @recipe macroexpand was OK.
    ext = Base.get_extension(PhysiCellXMLRules, :PhysiCellXMLRulesRecipesBaseExt)
    @test ext isa Module
    @test hasmethod(RecipesBase.apply_recipe, Tuple{AbstractDict{Symbol,Any}, PhysiCellXMLRules.Behavior})
end
