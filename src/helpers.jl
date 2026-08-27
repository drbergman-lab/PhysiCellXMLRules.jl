using LightXML

function getElement(parent_element::XMLElement, element_name::AbstractString; require_exist::Bool=false)
    ce = find_element(parent_element, element_name)
    if isnothing(ce) && require_exist
        throw(ArgumentError("Element '$element_name' not found in parent element '$parent_element'"))
    end
    return ce
end

function createElement(parent_element::XMLElement, element_name::AbstractString; require_new::Bool=true)
    if require_new && !isnothing(getElement(parent_element, element_name; require_exist=false))
        throw(ArgumentError("Element '$element_name' already exists in parent element '$parent_element'"))
    end
    return new_child(parent_element, element_name)
end

function getOrCreateElement(parent_element::XMLElement, element_name::AbstractString)
    ce = getElement(parent_element, element_name; require_exist=false)
    if isnothing(ce)
        ce = createElement(parent_element, element_name; require_new=false) # since we already checked it doesn't exist, don't need it to be new
    end
    return ce
end

function getElementByAttribute(parent_element::XMLElement, element_name::AbstractString, attribute_name::AbstractString, attribute_value::AbstractString; require_exist::Bool=false)
    candidate_elements = get_elements_by_tagname(parent_element, element_name)
    for ce in candidate_elements
        if attribute(ce,attribute_name)==attribute_value
            return ce
        end
    end
    if require_exist
        throw(ArgumentError("Element '$element_name' not found in parent element '$parent_element' with attribute '$attribute_name' = '$attribute_value'"))
    end
    return nothing
end

function createElementByAttribute(parent_element::XMLElement, element_name::AbstractString, attribute_name::AbstractString, attribute_value::AbstractString; require_new::Bool=true)
    if require_new && !isnothing(getElementByAttribute(parent_element, element_name, attribute_name, attribute_value; require_exist=false))
        throw(ArgumentError("$(element_name) already exists with (attribute, value) = ($(attribute_name), $(attribute_value)).")) # improve this to name the parent element and the new element name
    end
    ce = new_child(parent_element, element_name)
    set_attribute(ce, attribute_name, attribute_value)
    return ce
end

function getOrCreateElementByAttribute(parent_element::XMLElement, element_name::AbstractString, attribute_name::AbstractString, attribute_value::AbstractString)
    ce = getElementByAttribute(parent_element, element_name, attribute_name, attribute_value; require_exist=false)
    if isnothing(ce)
        ce = createElementByAttribute(parent_element, element_name, attribute_name, attribute_value; require_new=false) # since we already checked it doesn't exist, don't need it to be new
    end
    return ce
end

_booleanToBinary(value::Bool) = value ? 1 : 0