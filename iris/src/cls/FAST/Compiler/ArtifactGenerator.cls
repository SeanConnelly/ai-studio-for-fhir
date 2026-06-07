/// Generates the compiled artefacts for a flow definition. Each method returns
/// the artefact content as a string; the Compiler persists them.
Class FAST.Compiler.ArtifactGenerator [ Abstract ]
{

/// Which HealthConnect-style business operations this flow needs, by evidence.
ClassMethod OperationsFor(def As %DynamicObject) As %DynamicObject
{
    set ops = {}
    set ev = def.evidence
    if $isobject(ev) {
        if ##class(FAST.Util.JSON).ArrSize(ev.fhir) > 0 set ops.fhirRead = "FAST.BO.FHIRRead"
        if ##class(FAST.Util.JSON).ArrSize(ev.sql) > 0 set ops.sqlQuery = "FAST.BO.SQLQuery"
        if ##class(FAST.Util.JSON).ArrSize(ev.vector) > 0 set ops.vectorSearch = "FAST.BO.VectorSearch"
    }
    set ops.ai = "FAST.BP.AIHub"
    set ops.llmEgress = "FAST.BO.LLMService"
    if $extract(def.action.type, 1, 5) = "draft" set ops.writeback = "FAST.BO.FHIRWriteback"
    return ops
}

/// recipe.json — the executable recipe consumed by the runtime.
ClassMethod Recipe(def As %DynamicObject, flowSlug As %String) As %String
{
    set r = {}
    set r.recipeId = flowSlug
    set r.name = def.name
    set r.category = def.category
    set r.trigger = def.%Get("trigger")
    set r.evidence = def.%Get("evidence")
    set r.agent = def.%Get("agent")
    set r.action = def.%Get("action")
    set rt = {}
    set rt.production = "FAST.Production"
    set rt.businessService = "FAST.BS.AgentTriggerService"
    set rt.orchestratorProcess = "FAST.BP.AgentOrchestrator"
    set rt.operations = ..OperationsFor(def)
    set r.runtime = rt
    return ##class(FAST.Util.JSON).ToString(r)
}

/// prompt.md — the agent instruction prompt.
ClassMethod Prompt(def As %DynamicObject) As %String
{
    set nl = $char(10)
    set role = $select(def.agent.role'="":def.agent.role, 1:"agent")
    set p = "# Agent Instruction: " _ def.name _ nl _ nl
    set p = p _ "**Role:** " _ role _ nl _ nl
    set p = p _ "## Objective" _ nl _ def.agent.instruction _ nl _ nl
    set p = p _ "Use only the supplied evidence. Do not invent facts. Return output that matches the `" _ def.agent.outputSchema _ "` schema." _ nl _ nl
    set p = p _ "## Required output sections" _ nl
    set p = p _ "- Summary" _ nl
    set p = p _ "- Evidence (each item referencing its FHIR resource, SQL fact, or knowledge chunk)" _ nl
    set p = p _ "- Recommendations" _ nl
    set p = p _ "- Proposed FHIR Actions (drafts only — every write-back requires human review)" _ nl
    set p = p _ "- Safety / review status" _ nl
    return p
}

/// output-schema.json — JSON Schema for the agent's structured output.
ClassMethod OutputSchema(def As %DynamicObject) As %String
{
    set s = {}
    set s."$schema" = "http://json-schema.org/draft-07/schema#"
    set s.title = def.agent.outputSchema
    set s.type = "object"
    set props = {}
    set props.summary = {"type": "string"}
    set props.findings = {"type": "array"}
    set props.evidence = {"type": "array"}
    set props.recommendations = {"type": "array"}
    set props.missingData = {"type": "array"}
    set props.proposedActions = {"type": "array"}
    set safety = {"type": "object"}
    set safety.properties = {"requiresHumanReview": {"type": "boolean"}, "reason": {"type": "string"}}
    set props.safety = safety
    // Schema-specific extras for the hero workflows
    if def.agent.outputSchema = "prior-auth-packet" {
        set props.requestedService = {"type": "string"}
        set props.policyCriteriaMatched = {"type": "array"}
        set props.missingEvidenceChecklist = {"type": "array"}
        set props.draftJustification = {"type": "string"}
    } elseif def.agent.outputSchema = "nl-query-result" {
        set props.interpretedIntent = {"type": "string"}
        set props.generatedQueryType = {"type": "string", "enum": ["FHIR_SEARCH", "SQL"]}
        set props.generatedQuery = {"type": "string"}
        set props.validationStatus = {"type": "string", "enum": ["approved", "rejected", "needs_review"]}
        set props.resultPreview = {"type": "array"}
    }
    set s.properties = props
    return ##class(FAST.Util.JSON).ToString(s)
}

/// fhir-action-template.json — a draft FHIR resource skeleton for the action.
ClassMethod ActionTemplate(def As %DynamicObject) As %String
{
    set rt = def.action.resourceType
    set type = def.action.type
    if (type = "read-only") || (rt = "") {
        return ##class(FAST.Util.JSON).ToString({"actionType": "read-only", "note": "This flow performs no FHIR write-back."})
    }
    set t = {}
    set t.resourceType = rt
    set t.status = "draft"
    set t.subject = {"reference": "{{patientId}}"}
    set t."_meta" = {"approvalRequired": (def.action.approvalRequired), "note": "Draft only — requires human review before any commit."}
    if rt = "Task" {
        set t.intent = "order"
        set t.description = "{{recommendation.text}}"
        set t.authoredOn = "{{now}}"
    } elseif rt = "ServiceRequest" {
        set t.intent = "order"
        set t.code = {"text": "{{recommendation.serviceText}}"}
        set t.authoredOn = "{{now}}"
    } elseif rt = "DocumentReference" {
        set t.type = {"text": "{{document.title}}"}
        set t.date = "{{now}}"
        set t.content = [{"attachment": {"contentType": "text/markdown", "data": "{{document.base64}}"}}]
    } elseif rt = "Communication" {
        set t.payload = [{"contentString": "{{communication.text}}"}]
        set t.sent = "{{now}}"
    } elseif rt = "DetectedIssue" {
        set t.code = {"text": "{{issue.summary}}"}
        set t.detail = "{{issue.detail}}"
    } elseif rt = "QuestionnaireResponse" {
        set t.authored = "{{now}}"
        set t.item = "{{questionnaire.items}}"
    } elseif rt = "CarePlan" {
        set t.intent = "plan"
        set t.title = "{{carePlan.title}}"
    }
    return ##class(FAST.Util.JSON).ToString(t)
}

/// production-settings.json — HealthConnect-style runtime configuration.
ClassMethod ProductionSettings(def As %DynamicObject) As %String
{
    set p = {}
    set p.production = "FAST.Production"
    set p.businessService = "FAST.BS.AgentTriggerService"
    set p.routerProcess = "FAST.BP.AgentOrchestrator"
    set p.orchestratorProcess = "FAST.BP.AgentOrchestrator"
    set p.operations = ..OperationsFor(def)
    set p.settings = {"poolSize": 1, "logTraceEvents": true, "approvalRequiredForWriteback": true}
    return ##class(FAST.Util.JSON).ToString(p)
}

/// module.xml — lightweight IPM-style descriptor for the compiled flow.
ClassMethod ModuleXml(def As %DynamicObject, flowSlug As %String) As %String
{
    set nl = $char(10)
    set x = "<?xml version=""1.0"" encoding=""UTF-8""?>" _ nl
    set x = x _ "<Export generator=""Cache"" version=""25"">" _ nl
    set x = x _ "  <Document name=""fhir-agent-flow-" _ flowSlug _ ".MODULE"">" _ nl
    set x = x _ "    <Module>" _ nl
    set x = x _ "      <Name>fhir-agent-flow-" _ flowSlug _ "</Name>" _ nl
    set x = x _ "      <Version>1.0.0</Version>" _ nl
    set x = x _ "      <Packaging>module</Packaging>" _ nl
    set x = x _ "      <Description>" _ ..XmlEscape(def.name) _ "</Description>" _ nl
    set x = x _ "      <Dependencies>" _ nl
    set x = x _ "        <ModuleReference><Name>fhir-agent-studio</Name><Version>1.0.0</Version></ModuleReference>" _ nl
    set x = x _ "      </Dependencies>" _ nl
    set x = x _ "      <Resource Name=""recipe.json""/>" _ nl
    set x = x _ "      <Resource Name=""prompt.md""/>" _ nl
    set x = x _ "      <Resource Name=""output-schema.json""/>" _ nl
    set x = x _ "      <Resource Name=""fhir-action-template.json""/>" _ nl
    set x = x _ "      <Resource Name=""production-settings.json""/>" _ nl
    set x = x _ "      <Resource Name=""healthconnect-mapping.json""/>" _ nl
    set x = x _ "    </Module>" _ nl
    set x = x _ "  </Document>" _ nl
    set x = x _ "</Export>" _ nl
    return x
}

ClassMethod XmlEscape(s As %String) As %String
{
    set s = $replace(s, "&", "&amp;")
    set s = $replace(s, "<", "&lt;")
    set s = $replace(s, ">", "&gt;")
    return s
}

}
