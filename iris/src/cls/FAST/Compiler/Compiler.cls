/// Compiles a flow definition into the seven runtime artefacts, each stored as
/// a CompiledArtifact record. Re-compiling overwrites prior artefacts.
Class FAST.Compiler.Compiler [ Abstract ]
{

/// Compile the flow with the given slug. Returns $$$OK; on failure fills
/// errors. On success the flow's Status becomes "compiled".
ClassMethod CompileFlow(flowSlug As %String, Output errors As %DynamicArray) As %Status
{
    set errors = []
    set flow = ##class(FAST.Data.FlowDefinition).SlugIdxOpen(flowSlug)
    if '$isobject(flow) {
        do errors.%Push("Flow not found: " _ flowSlug)
        return $$$ERROR($$$GeneralError, "flow not found")
    }
    set def = ##class(FAST.Util.JSON).Parse(flow.DefinitionJSON)
    set sc = ##class(FAST.Compiler.Validator).Validate(def, .errors)
    if $$$ISERR(sc) return sc

    set gen = "FAST.Compiler.ArtifactGenerator"
    do ..Store(flowSlug, "recipe.json", "json", "application/json", $classmethod(gen, "Recipe", def, flowSlug))
    do ..Store(flowSlug, "prompt.md", "markdown", "text/markdown", $classmethod(gen, "Prompt", def))
    do ..Store(flowSlug, "output-schema.json", "json", "application/json", $classmethod(gen, "OutputSchema", def))
    do ..Store(flowSlug, "fhir-action-template.json", "json", "application/json", $classmethod(gen, "ActionTemplate", def))
    do ..Store(flowSlug, "production-settings.json", "json", "application/json", $classmethod(gen, "ProductionSettings", def))
    do ..Store(flowSlug, "healthconnect-mapping.json", "json", "application/json", ##class(FAST.Compiler.MappingGenerator).Mapping(def))
    do ..Store(flowSlug, "module.xml", "xml", "application/xml", $classmethod(gen, "ModuleXml", def, flowSlug))

    set flow.Status = "compiled"
    set flow.UpdatedAt = $zdatetime($ztimestamp, 3)
    return flow.%Save()
}

/// Upsert one artefact for a flow.
ClassMethod Store(flowSlug As %String, name As %String, type As %String, contentType As %String, content As %String) As %Status
{
    set art = ##class(FAST.Data.CompiledArtifact).FlowArtifactIdxOpen(flowSlug, name)
    if '$isobject(art) {
        set art = ##class(FAST.Data.CompiledArtifact).%New()
        set art.FlowSlug = flowSlug
        set art.ArtifactName = name
    }
    set art.ArtifactType = type
    set art.ContentType = contentType
    set art.Content = content
    set art.CreatedAt = $zdatetime($ztimestamp, 3)
    return art.%Save()
}

}
