/// Generates healthconnect-mapping.json: an explicit map from portal flow
/// concepts to HealthConnect-style Business Service / Process / Operation
/// components. This is the product's core story surface.
Class FAST.Compiler.MappingGenerator [ Abstract ]
{

ClassMethod Mapping(def As %DynamicObject) As %String
{
    set m = {}
    set rows = []

    do rows.%Push(..Row("Trigger", ..Describe(def.trigger), "Business Service", "FAST.BS.AgentTriggerService"))

    set ev = def.evidence
    if $isobject(ev) {
        if ##class(FAST.Util.JSON).ArrSize(ev.fhir) > 0 {
            do rows.%Push(..Row("Evidence · FHIR", ..Join(ev.fhir), "Business Operation", "FAST.BO.FHIRRead"))
        }
        if ##class(FAST.Util.JSON).ArrSize(ev.sql) > 0 {
            do rows.%Push(..Row("Evidence · SQL", ..Join(ev.sql), "Business Operation", "FAST.BO.SQLQuery"))
        }
        if ##class(FAST.Util.JSON).ArrSize(ev.vector) > 0 {
            do rows.%Push(..Row("Evidence · Vector", ..Join(ev.vector), "Business Operation", "FAST.BO.VectorSearch"))
        }
    }

    do rows.%Push(..Row("Agent Instruction", def.agent.role, "Business Process", "FAST.BP.AIHub"))
    do rows.%Push(..Row("LLM Egress", "POST /chat/completions (cached replay or live HTTPS)", "Business Operation", "FAST.BO.LLMService (EnsLib.HTTP.OutboundAdapter)"))

    if $extract(def.action.type, 1, 5) = "draft" {
        do rows.%Push(..Row("FHIR Action", "draft " _ def.action.resourceType, "Business Operation", "FAST.BO.FHIRWriteback"))
    } else {
        do rows.%Push(..Row("Action", "read-only", "Business Process", "FAST.BP.AgentOrchestrator"))
    }

    set m.flow = def.name
    set m.orchestrator = "FAST.BP.AgentOrchestrator"
    set m.mappings = rows
    return ##class(FAST.Util.JSON).ToString(m)
}

ClassMethod Row(portalConcept As %String, portalDetail As %String, hcType As %String, hcComponent As %String) As %DynamicObject
{
    set r = {}
    set r.portalConcept = portalConcept
    set r.portalDetail = portalDetail
    set r.healthConnectType = hcType
    set r.healthConnectComponent = hcComponent
    return r
}

ClassMethod Describe(trigger As %DynamicObject) As %String
{
    if '$isobject(trigger) return ""
    set s = trigger.type
    if trigger.resourceType '= "" set s = s _ " · " _ trigger.resourceType
    if trigger.condition '= "" set s = s _ " · " _ trigger.condition
    return s
}

ClassMethod Join(arr As %DynamicArray) As %String
{
    set s = "", it = arr.%GetIterator()
    while it.%GetNext(.k, .v) { set s = s _ $select(s="":"", 1:", ") _ v }
    return s
}

}
