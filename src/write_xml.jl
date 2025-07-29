using CSV, DataFrames, LightXML

export writeXMLRules

"""
    standardizeCustomName(name::AbstractString)

If the name for a signal or behavior starts with "custom:", use the synonym "custom <name>" instead.

[PhysiCellModelManager.jl](https://github.com/drbergman-lab/PhysiCellModelManager.jl/) uses `:` to use attributes to specify elements in an XML path. So, we use `custom <name>` to avoid incorrect splitting on `:`.
"""
function standardizeCustomName(name)
    if !startswith(name, "custom:")
        return name
    end
    # store all custom behaviors as "custom <name>" to only use `:` for indicating attribute on xml paths
    name = name[8:end] |> lstrip
    return "custom $name"
end

abstract type AbstractSignal end

struct SignalReference
    value::Float64
    type::String
    function SignalReference(value::Real, type::AbstractString="increasing")
        @assert type in ["increasing", "decreasing"] "type must be either 'increasing' or 'decreasing'"
        new(value, type)
    end
end

validateReference(::Nothing, ::Real) = nothing
function validateReference(reference::SignalReference, half_max::Real)
    if reference.type == "increasing"
        @assert reference.value < half_max "half_max ($(half_max)) must be greater than the reference value ($(reference.value)) for an increasing reference"
    else
        @assert reference.value > half_max "half_max ($(half_max)) must be less than the reference value ($(reference.value)) for a decreasing reference"
    end
    return nothing
end

function SignalReference(e::XMLElement)
    reference_element = find_element(e, "reference")
    if isnothing(reference_element)
        return nothing
    end
    reference_value = content(find_element(reference_element, "value"))
    reference_value = parse(Float64, reference_value)
    reference_type = content(find_element(reference_element, "type"))
    return SignalReference(reference_value, reference_type)
end

abstract type ElementarySignal <: AbstractSignal end
abstract type RelativeSignal <: ElementarySignal end
abstract type AbstractHillSignal <: RelativeSignal end
abstract type AbsoluteSignal <: ElementarySignal end

struct HillTypeParameters
    half_max::Float64
    hill_power::Float64
end

struct HillSignal <: AbstractHillSignal
    name::String
    p::HillTypeParameters
    applies_to_dead::Bool
    reference::Union{Nothing,SignalReference}
    function HillSignal(name::AbstractString, half_max::Real, hill_power::Real, applies_to_dead::Bool, reference::Union{Nothing,SignalReference}=nothing)
        validateReference(reference, half_max)
        name = standardizeCustomName(name)
        p = HillTypeParameters(half_max, hill_power)
        new(name, p, applies_to_dead, reference)
    end
end

type(::HillSignal) = "hill"

struct PartialHillSignal <: AbstractHillSignal
    name::String
    p::HillTypeParameters
    applies_to_dead::Bool
    reference::Union{Nothing,SignalReference}
    function PartialHillSignal(name::AbstractString, half_max::Real, hill_power::Real, applies_to_dead::Bool, reference::Union{Nothing,SignalReference}=nothing)
        validateReference(reference, half_max)
        name = standardizeCustomName(name)
        p = HillTypeParameters(half_max, hill_power)
        new(name, p, applies_to_dead, reference)
    end
end

type(::PartialHillSignal) = "partial_hill"

struct IdentitySignal <: RelativeSignal
    name::String
    applies_to_dead::Bool
    reference::Union{Nothing,SignalReference}
    function IdentitySignal(name::AbstractString, applies_to_dead::Bool, reference::Union{Nothing,SignalReference}=nothing)
        name = standardizeCustomName(name)
        new(name, applies_to_dead, reference)
    end
end    

struct LinearSignal <: AbsoluteSignal
    name::String
    applies_to_dead::Bool
    signal_min::Float64
    signal_max::Float64
    type::String
    function LinearSignal(name::AbstractString, signal_min::Real, signal_max::Real, applies_to_dead::Bool, type::AbstractString="increasing")
        @assert type in ["increasing", "decreasing"] "type must be either 'increasing' or 'decreasing'"
        @assert signal_min < signal_max "signal_min ($signal_min) must be less than signal_max ($signal_max)"
        name = standardizeCustomName(name)
        new(name, applies_to_dead, signal_min, signal_max, type)
    end
end

struct HeavisideSignal <: AbsoluteSignal
    name::String
    applies_to_dead::Bool
    threshold::Float64
    type::String
    function HeavisideSignal(name::AbstractString, threshold::Real, applies_to_dead::Bool, type::AbstractString="increasing")
        @assert type in ["increasing", "decreasing"] "type must be either 'increasing' or 'decreasing'"
        name = standardizeCustomName(name)
        new(name, applies_to_dead, threshold, type)
    end
end

struct AggregatorSignal <: AbstractSignal
    signals::Vector{<:AbstractSignal}
    aggregator::String
    function AggregatorSignal(signals::Vector{<:AbstractSignal}, aggregator::AbstractString="multivariate_hill")
        possible_aggregators = ["multivariate hill", "multivariate_hill", "sum", "product", "mean", "min", "max", "median", "geometric mean", "geometric_mean", "first"]
        @assert aggregator in possible_aggregators "Aggregator must be one of $(join("'" .* possible_aggregators .+ "'", ", ", ", or "))"
        new(signals, aggregator)
    end
    function AggregatorSignal(signal::AbstractSignal; aggregator::AbstractString="multivariate_hill")
        return AggregatorSignal([signal], aggregator)
    end
end

Base.isempty(aggregator::AggregatorSignal) = isempty(aggregator.signals)

struct MediatorSignal <: AbstractSignal
    decreasing_signal::AggregatorSignal
    increasing_signal::AggregatorSignal
    min::Union{Nothing,Float64}
    base::Union{Nothing,Float64}
    max::Union{Nothing,Float64}
    mediator::String
    function MediatorSignal(decreasing_signal::AggregatorSignal, increasing_signal::AggregatorSignal, min::Union{Nothing,Real}=nothing, base::Union{Nothing,Real}=nothing, max::Union{Nothing,Real}=nothing, mediator::AbstractString="decreasing_dominant")
        @assert isnothing(min) || isnothing(base) || min <= base "min ($min) must be less than or equal to base ($base)"
        @assert isnothing(min) || isnothing(max) || min <= max "min ($min) must be less than or equal to max ($max)"
        @assert isnothing(base) || isnothing(max) || base <= max "base ($base) must be less than or equal to max ($max)"
        @assert mediator in ["decreasing_dominant", "decreasing dominant", "increasing_dominant", "increasing dominant", "neutral"] "mediator must be one of 'decreasing_dominant', 'increasing_dominant', or 'neutral'"
        new(decreasing_signal, increasing_signal, min, base, max, mediator)
    end
    function MediatorSignal(decreasing_signals::AbstractVector{<:AbstractSignal}, increasing_signals::AbstractVector{<:AbstractSignal}, min::Union{Nothing,Real}=nothing, base::Union{Nothing,Real}=nothing, max::Union{Nothing,Real}=nothing, mediator::AbstractString="decreasing_dominant")
        return MediatorSignal(AggregatorSignal(decreasing_signals), AggregatorSignal(increasing_signals), min, base, max, mediator)
    end
end

struct Behavior
    name::String
    signal::AbstractSignal
    type::String
    function Behavior(name::AbstractString, signal::MediatorSignal, type::AbstractString="setter")
        @assert type in ["setter", "attenuator", "accumulator"] "type must be either 'setter', 'attenuator', or 'accumulator'"
        name = standardizeCustomName(name)
        new(name, signal, type)
    end
    function Behavior(name::AbstractString, signal::AbstractSignal, type::AbstractString="setter")
        throw(ArgumentError("The signal must be either a MediatorSignal. Got $(typeof(signal)) for behavior $(name)"))
    end
end

"""
    writeXMLRules(path_to_xml::AbstractString, path_to_csv::AbstractString; force::Bool=false)

Write the rules from the CSV file at `path_to_csv` to the XML file at `path_to_xml`.

If `force` is set to `true`, the function will overwrite the existing XML file at `path_to_xml` if it exists.
Note: this is not the inverse of [`exportCSVRules`](@ref) as `writeXMLRules` discards comments in the original CSV and `exportCSVRules` adds comments to the exported CSV file.
"""
function writeXMLRules(path_to_xml::AbstractString, path_to_csv::AbstractString; force::Bool=false)
    @assert splitext(path_to_xml)[2] == ".xml" "The path to the XML file must end with .xml. Got $(path_to_xml)"
    @assert force || !isfile(path_to_xml) "The path to the XML file must not exist. $(path_to_xml) is a file. Use writeXMLRules(...; force=true) to overwrite it."
    xml_doc = XMLDocument()
    writeXMLRules!(xml_doc, path_to_csv)
    save_file(xml_doc, path_to_xml)
    free(xml_doc)
    return
end

function writeXMLRules!(xml_doc::XMLDocument, path_to_csv::AbstractString)
    xml_root = create_root(xml_doc, "behavior_rulesets")
    addRules!(xml_root, path_to_csv)
    return
end

function addRules!(xml_root::XMLElement, path_to_csv::AbstractString)
    @assert splitext(path_to_csv)[2] == ".csv" "The path to the CSV file must end with .csv. Got $(path_to_csv)"
    @assert isfile(path_to_csv) "The path to the CSV file must be a file. $(path_to_csv) is not a file."
    header = [:cell_type, :signal, :response, :behavior, :max_response, :p₁, :p₂, :applies_to_dead]
    types = [String, String, String, String, Float64, Float64, Float64, Bool]
    df = CSV.read(path_to_csv, DataFrame; header=header, types=types, comment="//")
    if isempty(df)
        return
    end
    addRules!(xml_root, df)
    return
end

function addRules!(xml_root::XMLElement, df::DataFrame)
    for row in eachrow(df)
        cell_type = row[:cell_type]
        signal_name, reference, reference_type = row[:signal] |> parseSignal
        response, signal_type = row[:response] |> parseResponse
        behavior_name = row[:behavior]

        max_response = row[:max_response]
        par_1 = row[:p₁]
        par_2 = row[:p₂]
        applies_to_dead = row[:applies_to_dead]
        @assert !ismissing(applies_to_dead) "The following CSV row is missing applies_to_dead. The row is likely missing a column:\n\t$(join(row, ","))"

        signal_is_relative = signal_type <: RelativeSignal
        @assert signal_is_relative || signal_type <: AbsoluteSignal "signal type must be either a PartialHillSignal, HillSignal, IdentitySignal, LinearSignal, or HeavisideSignal. Found $(signal_type) for cell_type $(cell_type) and signal name $(signal_name)"
        @assert isnothing(reference) || signal_is_relative "signal type must be a RelativeSignal if a reference is provided"
        if signal_type <: AbstractHillSignal
            signal = signal_type(signal_name, par_1, par_2, applies_to_dead, reference)
        elseif signal_type == IdentitySignal
            @assert ismissing(par_1) "Identity signal does not take any parameters. Found p₁=$(par_1)."
            @assert ismissing(par_2) "Identity signal does not take any parameters. Found p₂=$(par_2)."
            signal = signal_type(signal_name, applies_to_dead, reference)
        elseif signal_type == LinearSignal
            signal = signal_type(signal_name, par_1, par_2, applies_to_dead, reference_type)
        elseif signal_type == HeavisideSignal
            @assert ismissing(par_2) "Found a second parameter for a Heaviside signal. Only one parameter (threshold) is allowed. Found threshold=$(par_1) and p₂=$(par_2)"
            signal = signal_type(signal_name, par_1, applies_to_dead, reference_type)
        end
        increasing_signals = AbstractSignal[]
        decreasing_signals = AbstractSignal[]
        base = nothing
        @assert response in ["increases", "decreases"] "response must be either 'increases' or 'decreases'"
        if response == "decreases"
            push!(decreasing_signals, signal)
            min = max_response
            max = nothing
        else
            push!(increasing_signals, signal)
            min = nothing
            max = max_response
        end
        
        mediator = MediatorSignal(decreasing_signals, increasing_signals, min, base, max)
        behavior = Behavior(behavior_name, mediator)
        addRule!(xml_root, cell_type, behavior)
    end
    return
end

function parseSignal(signal::String)
    if startswith(signal, "(")
        parenthesis_ind = findfirst(")", signal)[1]
        reference_type = signal[2:parenthesis_ind-1]
        signal = signal[parenthesis_ind+2:end]
    else
        reference_type = "increasing"
    end

    if endswith(signal, ")")
        parenthesis_ind = findlast("(", signal)[1]
        signal_name = signal[1:parenthesis_ind-2]
        _, reference_value = split(signal[parenthesis_ind+1:end-1])
        reference_value = parse(Float64, reference_value)
        reference = SignalReference(reference_value, reference_type)
    else
        signal_name = signal
        reference = nothing
    end
    return signal_name, reference, reference_type
end

function parseResponse(response::String)
    if response in ["increases", "decreases"]
        return response, PartialHillSignal
    end
    response, signal_type = split(response, " (")
    @assert signal_type[end] == ')' "signal type must be in parentheses. Found '($(signal_type)'. And end is '$(signal_type[end])'. Whether is it ): $(signal_type[end] == ")")"
    signal_type = signal_type[1:end-1]
    signal_type = parseSignalType(signal_type)
    return response, signal_type
end

function parseSignalType(signal_type::AbstractString)
    signal_type = split(signal_type, "_") .|> uppercasefirst
    signal_symbol = "$(join(signal_type))Signal" |> Symbol
    return  eval(signal_symbol)
end

function addRule!(xml_root::XMLElement, cell_type::String, behavior::Behavior)
    behavior_element = getBehaviorElement(xml_root, cell_type, behavior.name)
    validateOrWriteElement!(behavior_element, "type", behavior.type)
    fillSignalElement!(behavior_element, behavior.signal)
end

function getBehaviorElement(xml_root::XMLElement, cell_type::String, behavior_name::String)
    behavior_ruleset_element = getOrCreateElementByAttribute(xml_root, "behavior_ruleset", "name", cell_type)
    behavior_element = getOrCreateElementByAttribute(behavior_ruleset_element, "behavior", "name", behavior_name)
    return behavior_element
end
 
function addSignalElement!(e::XMLElement, signal::MediatorSignal)
    signal_element = createElementByAttribute(e, "signal", "type", "mediator")
    fillSignalElement!(signal_element, signal)
    return
end

function addSignalElement!(e::XMLElement, signal::AggregatorSignal)
    signal_element = createElementByAttribute(e, "signal", "type", "aggregator")
    fillSignalElement!(signal_element, signal)
    return
end

function addSignalElement!(e::XMLElement, signal::ElementarySignal)
    signal_element = getOrCreateElementByAttribute(e, "signal", "name", signal.name)
    validateOrWriteElement!(signal_element, "applies_to_dead", signal.applies_to_dead)
    fillSignalElement!(signal_element, signal)
    return
end

function fillSignalElement!(e::XMLElement, signal::MediatorSignal)
    validateOrWriteElement!(e, "mediator", signal.mediator)
    isnothing(signal.base) || validateOrWriteElement!(e, "base_value", signal.base)

    if !isempty(signal.decreasing_signal)
        decreasing_signals_element = getOrCreateElement(e, "decreasing_signals")
        fillSignalElement!(decreasing_signals_element, signal.decreasing_signal, signal.min)
    end
    
    if !isempty(signal.increasing_signal)
        increasing_signals_element = getOrCreateElement(e, "increasing_signals")
        fillSignalElement!(increasing_signals_element, signal.increasing_signal, signal.max)
    end
    return
end

function fillSignalElement!(e::XMLElement, signal::AggregatorSignal, max_response::Union{Nothing,Float64}=nothing)
    validateOrWriteElement!(e, "aggregator", signal.aggregator)
    isnothing(max_response) || validateOrWriteElement!(e, "max_response", max_response)
    for signal in signal.signals
        addSignalElement!(e, signal)
    end
    return
end
  
function fillSignalElement!(e::XMLElement, signal::RelativeSignal)
    addSignalReference!(e, signal.reference)
    finishFillSignalElement!(e, signal)
    return
end

fillSignalElement!(e::XMLElement, signal::AbsoluteSignal) = finishFillSignalElement!(e, signal)

function finishFillSignalElement!(e::XMLElement, signal::AbstractHillSignal)
    validateOrWriteAttribute!(e, "type", type(signal))
    validateOrWriteElement!(e, "half_max", signal.p.half_max)
    validateOrWriteElement!(e, "hill_power", signal.p.hill_power)
    return
end

function finishFillSignalElement!(e::XMLElement, signal::IdentitySignal)
    validateOrWriteAttribute!(e, "type", "identity")
    return
end

function finishFillSignalElement!(e::XMLElement, signal::LinearSignal)
    validateOrWriteAttribute!(e, "type", "linear")
    validateOrWriteElement!(e, "type", signal.type)
    validateOrWriteElement!(e, "signal_min", signal.signal_min)
    validateOrWriteElement!(e, "signal_max", signal.signal_max)
    return
end

function finishFillSignalElement!(e::XMLElement, signal::HeavisideSignal)
    validateOrWriteAttribute!(e, "type", "heaviside")
    validateOrWriteElement!(e, "type", signal.type)
    validateOrWriteElement!(e, "threshold", signal.threshold)
    return
end

addSignalReference!(::XMLElement, ::Nothing) = nothing

function addSignalReference!(e::XMLElement, reference::SignalReference)
    reference_element = getOrCreateElement(e, "reference")
    validateOrWriteElement!(reference_element, "type", reference.type)
    validateOrWriteElement!(reference_element, "value", reference.value)
    return
end

function validateOrWriteElement!(e::XMLElement, element_name::AbstractString, value::T) where {T}
    sub_e = find_element(e, element_name)
    if isnothing(sub_e)
        sub_e = new_child(e, element_name)
    end
    if !isnothing(value)
        parse_fn = T == String ? identity : x -> parse(T, x)
        @assert content(sub_e) == "" || parse_fn(content(sub_e)) == value "$(element_name) value ($(value)) does not match the $(element_name) in the XML ($(content(sub_e)))"
        value_str = (T == Bool ? _booleanToBinary(value) : value) |> string
        set_content(sub_e, value_str)
    end
end

function validateOrWriteAttribute!(e::XMLElement, attribute_name::AbstractString, value)
    if has_attribute(e, attribute_name)
        @assert attribute(e, attribute_name) == value "$(attribute_name) value ($(value)) does not match the $(attribute_name) in the XML ($(attribute(e, attribute_name)))"
    else
        set_attribute(e, attribute_name, value)
    end
end