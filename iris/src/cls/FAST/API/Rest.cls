/// REST dispatch for FHIR Agent Studio, served at /fhir-agent-studio/api.
/// All responses are JSON. Phase 1 covers status + template/flow reads;
/// compile/deploy/run endpoints arrive in later phases.
Class FAST.API.Rest Extends %CSP.REST
{

/// Allow the Vite dev server (different origin) to call the API in dev mode.
Parameter HandleCorsRequest = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/status" Method="GET" Call="GetStatus" Cors="true"/>
<Route Url="/templates" Method="GET" Call="ListTemplates" Cors="true"/>
<Route Url="/templates/import" Method="POST" Call="ImportTemplate" Cors="true"/>
<Route Url="/templates/:slug" Method="GET" Call="GetTemplate" Cors="true"/>
<Route Url="/admin/seed" Method="POST" Call="AdminSeed" Cors="true"/>
<Route Url="/components/:entity" Method="GET" Call="CompList" Cors="true"/>
<Route Url="/components/:entity" Method="POST" Call="CompCreate" Cors="true"/>
<Route Url="/components/:entity/:slug" Method="GET" Call="CompGet" Cors="true"/>
<Route Url="/components/:entity/:slug" Method="PUT" Call="CompUpdate" Cors="true"/>
<Route Url="/components/:entity/:slug" Method="DELETE" Call="CompDelete" Cors="true"/>
<Route Url="/fhir/tools/patient-search" Method="GET" Call="ToolPatientSearch" Cors="true"/>
<Route Url="/fhir/tools/everything" Method="GET" Call="ToolEverything" Cors="true"/>
<Route Url="/fhir/tools/terminology" Method="GET" Call="ToolTerminology" Cors="true"/>
<Route Url="/fhir/tools/cohort" Method="GET" Call="ToolCohort" Cors="true"/>
<Route Url="/orders/catalogue" Method="GET" Call="OrdersCatalogue" Cors="true"/>
<Route Url="/patients/:id/orders" Method="GET" Call="OrdersList" Cors="true"/>
<Route Url="/patients/:id/orders" Method="POST" Call="OrdersPlace" Cors="true"/>
<Route Url="/pa/:claimId/submit" Method="POST" Call="OrdersSubmit" Cors="true"/>
<Route Url="/pa-queue" Method="GET" Call="OrdersQueue" Cors="true"/>
<Route Url="/care-rules" Method="GET" Call="CareRulesList" Cors="true"/>
<Route Url="/care-rules" Method="POST" Call="CareRulesCreate" Cors="true"/>
<Route Url="/care-rules/:slug/run" Method="POST" Call="CareRulesRun" Cors="true"/>
<Route Url="/care-rules/:slug/worklist" Method="GET" Call="CareRulesWorklist" Cors="true"/>
<Route Url="/care-rules/:slug/worklist/update" Method="POST" Call="CareRulesWorklistUpdate" Cors="true"/>
<Route Url="/care-rules/:slug" Method="DELETE" Call="CareRulesDelete" Cors="true"/>
<Route Url="/care-plan/demo-patients" Method="GET" Call="CarePlanDemoPatients" Cors="true"/>
<Route Url="/patients/:id/care-plan/tasks" Method="POST" Call="CarePlanCreateTasks" Cors="true"/>
<Route Url="/patients/:id/triage-session" Method="POST" Call="TriageSaveSession" Cors="true"/>
<Route Url="/patients/:id/communication" Method="POST" Call="SaveCommunication" Cors="true"/>
<Route Url="/options/evidence" Method="GET" Call="OptionsEvidence" Cors="true"/>
<Route Url="/admin/llm" Method="GET" Call="AdminLLMGet" Cors="true"/>
<Route Url="/admin/llm" Method="POST" Call="AdminLLMSet" Cors="true"/>
<Route Url="/admin/llm/test" Method="POST" Call="AdminLLMTest" Cors="true"/>
<Route Url="/admin/llm/cache" Method="GET" Call="AdminLLMCacheList" Cors="true"/>
<Route Url="/admin/llm/cache/:id" Method="GET" Call="AdminLLMCacheGet" Cors="true"/>
<Route Url="/patients/:id/preventative" Method="GET" Call="PreventativeForPatient" Cors="true"/>
<Route Url="/patients/:id/preventative/letter" Method="POST" Call="PreventativeLetter" Cors="true"/>
<Route Url="/flows" Method="GET" Call="ListFlows" Cors="true"/>
<Route Url="/flows" Method="POST" Call="SaveFlow" Cors="true"/>
<Route Url="/flows/from-template/:templateSlug" Method="POST" Call="CreateFlowFromTemplate" Cors="true"/>
<Route Url="/flows/:slug" Method="GET" Call="GetFlow" Cors="true"/>
<Route Url="/flows/:slug" Method="PUT" Call="UpdateFlow" Cors="true"/>
<Route Url="/flows/:slug" Method="DELETE" Call="DeleteFlow" Cors="true"/>
<Route Url="/flows/:slug/clone" Method="POST" Call="CloneFlow" Cors="true"/>
<Route Url="/flows/:slug/compile" Method="POST" Call="CompileFlow" Cors="true"/>
<Route Url="/flows/:slug/artifacts" Method="GET" Call="ListArtifacts" Cors="true"/>
<Route Url="/flows/:slug/artifacts/:name" Method="GET" Call="GetArtifact" Cors="true"/>
<Route Url="/flows/:slug/healthconnect-mapping" Method="GET" Call="GetMapping" Cors="true"/>
<Route Url="/flows/:slug/deploy" Method="POST" Call="DeployFlow" Cors="true"/>
<Route Url="/flows/:slug/test" Method="POST" Call="TestFlow" Cors="true"/>
<Route Url="/flows/:slug/run" Method="POST" Call="RunAgent" Cors="true"/>
<Route Url="/authoring/step-test" Method="POST" Call="AuthoringStepTest" Cors="true"/>
<Route Url="/authoring/prompt-preview" Method="POST" Call="AuthoringPromptPreview" Cors="true"/>
<Route Url="/options/patients" Method="GET" Call="OptionPatients" Cors="true"/>
<Route Url="/options/resources" Method="GET" Call="OptionResources" Cors="true"/>
<Route Url="/runtime/run" Method="POST" Call="RuntimeRun" Cors="true"/>
<Route Url="/invocations" Method="GET" Call="ListInvocations" Cors="true"/>
<Route Url="/invocations/:requestId" Method="GET" Call="GetInvocation" Cors="true"/>
<Route Url="/invocations/:requestId/audit" Method="GET" Call="GetAudit" Cors="true"/>
<Route Url="/invocations/:requestId/actions/:actionId/approve" Method="POST" Call="ApproveAction" Cors="true"/>
<Route Url="/invocations/:requestId/actions/:actionId/reject" Method="POST" Call="RejectAction" Cors="true"/>
<Route Url="/worklists/:key" Method="GET" Call="GetWorklist" Cors="true"/>
<Route Url="/traces/:traceId" Method="GET" Call="GetTrace" Cors="true"/>
</Routes>
}

/// GET /status — health check + row counts. No auth, no secrets required.
ClassMethod GetStatus() As %Status
{
    set o = {}
    set o.status = "ok"
    set o.product = "FHIR Agent Studio"
    set o.version = $get(^FAST("version"), "0.1.0")
    set o.iris = $zversion
    set o.namespace = $namespace
    set o.timestamp = $zdatetime($ztimestamp, 3)
    set counts = {}
    set counts.templates = ..Count("FAST_Data.Template")
    set counts.flows = ..Count("FAST_Data.FlowDefinition")
    set counts.compiledArtifacts = ..Count("FAST_Data.CompiledArtifact")
    set counts.deployedRecipes = ..Count("FAST_Data.DeployedRecipe")
    set counts.invocations = ..Count("FAST_Data.AgentInvocation")
    set counts.fhirResources = ..Count("HSFHIR_X0001_R.Rsrc")
    set counts.knowledgeDocuments = ..Count("FAST_Data.KnowledgeDocument")
    set o.counts = counts
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// GET /templates — every agent the user can open: seeded templates PLUS
/// authored FlowDefinitions. A flow with the same slug as a template SHADOWS it
/// (matching FAST.Runtime.Runtime.LoadDef, which resolves flow-first at run
/// time), so the gallery always shows what would actually run.
ClassMethod ListTemplates() As %Status
{
    set arr = [], seen = ""
    // authored flows first (they shadow same-slug templates)
    set sql = "SELECT Slug, Name, Description, Version, DefinitionJSON FROM FAST_Data.FlowDefinition ORDER BY Name"
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, sql)
    while rs.%Next() {
        set slug = rs.%Get("Slug")
        set def = ..ParseOrNull(rs.%Get("DefinitionJSON"))
        set t = {}
        set t.slug = slug
        set t.name = rs.%Get("Name")
        set t.category = $select($isobject(def): def.category, 1: "Custom")
        if t.category = "" set t.category = "Custom"
        set t.description = rs.%Get("Description")
        set t.version = rs.%Get("Version")
        set t.source = "flow"
        do arr.%Push(t)
        set $list(seen, *+1) = slug
    }
    set sql = "SELECT Slug, Name, Category, Description, Version FROM FAST_Data.Template ORDER BY Name"
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, sql)
    while rs.%Next() {
        if $listfind(seen, rs.%Get("Slug")) continue
        set t = {}
        set t.slug = rs.%Get("Slug")
        set t.name = rs.%Get("Name")
        set t.category = rs.%Get("Category")
        set t.description = rs.%Get("Description")
        set t.version = rs.%Get("Version")
        set t.source = "template"
        do arr.%Push(t)
    }
    set o = {}
    set o.templates = arr
    set o.count = arr.%Size()
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// GET /templates/:slug — full agent detail incl. parsed definition. Resolves
/// flow-first (matching the runtime's LoadDef) so the workspace shows exactly
/// what runs; falls back to the seeded template. hasOverride flags a seeded
/// agent that has been edited (a FlowDefinition shadows the template).
ClassMethod GetTemplate(slug As %String) As %Status
{
    set tpl = ##class(FAST.Data.Template).SlugIdxOpen(slug)
    set flow = ##class(FAST.Data.FlowDefinition).SlugIdxOpen(slug)
    if '$isobject(tpl) && '$isobject(flow) {
        return ##class(FAST.Util.Response).Error("Template not found: "_slug, "404 Not Found")
    }
    set o = {}
    set o.slug = slug
    if $isobject(flow) {
        set def = ..ParseOrNull(flow.DefinitionJSON)
        set o.name = flow.Name
        set o.category = $select($isobject(def) && (def.category '= ""): def.category, 1: "Custom")
        set o.description = flow.Description
        set o.version = flow.Version
        set o.definition = def
    } else {
        set o.name = tpl.Name
        set o.category = tpl.Category
        set o.description = tpl.Description
        set o.version = tpl.Version
        set o.definition = ..ParseOrNull(tpl.DefinitionJSON)
    }
    set o.isSystemTemplate = $select($isobject(tpl): tpl.IsSystemTemplate, 1: 0)
    set o.hasOverride = ($isobject(tpl) && $isobject(flow))
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// POST /templates/import — create/update a template from a posted definition.
ClassMethod ImportTemplate() As %Status
{
    set body = ##class(FAST.Util.Response).Body()
    if '$isobject(body) || (body.id = "") {
        return ##class(FAST.Util.Response).Error("Body must be a template definition with an 'id'")
    }
    set slug = body.id
    set tpl = ##class(FAST.Data.Template).SlugIdxOpen(slug)
    set created = 0
    if '$isobject(tpl) {
        set tpl = ##class(FAST.Data.Template).%New()
        set tpl.Slug = slug
        set created = 1
    }
    set tpl.Name = body.name
    set tpl.Category = body.category
    set tpl.Description = body.description
    if body.%IsDefined("version") set tpl.Version = body.version
    set tpl.DefinitionJSON = ##class(FAST.Util.JSON).ToString(body, 0)
    set tpl.IsSystemTemplate = 0
    set tpl.UpdatedAt = $zdatetime($ztimestamp, 3)
    set sc = tpl.%Save()
    if $$$ISERR(sc) return ##class(FAST.Util.Response).Error($system.Status.GetErrorText(sc), "500 Internal Server Error")
    set o = {}, o.slug = slug, o.created = created
    return ##class(FAST.Util.Response).WriteJSON(o, $select(created: "201 Created", 1: "200 OK"))
}

/// POST /admin/seed — reload seed data + embeddings.
ClassMethod AdminSeed() As %Status
{
    set sc = ##class(FAST.Seed.SeedLoader).Run()
    set o = {}, o.status = $select($$$ISOK(sc): "ok", 1: "error")
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// GET /flows — list flow metadata.
ClassMethod ListFlows() As %Status
{
    set arr = []
    set sql = "SELECT Slug, Name, Description, Version, Status, SourceTemplateSlug FROM FAST_Data.FlowDefinition ORDER BY UpdatedAt DESC"
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, sql)
    while rs.%Next() {
        set f = {}
        set f.slug = rs.%Get("Slug")
        set f.name = rs.%Get("Name")
        set f.description = rs.%Get("Description")
        set f.version = rs.%Get("Version")
        set f.status = rs.%Get("Status")
        set f.sourceTemplateSlug = rs.%Get("SourceTemplateSlug")
        do arr.%Push(f)
    }
    set o = {}
    set o.flows = arr
    set o.count = arr.%Size()
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// POST /flows/from-template/:templateSlug — create (or return existing) flow.
ClassMethod CreateFlowFromTemplate(templateSlug As %String) As %Status
{
    set tpl = ##class(FAST.Data.Template).SlugIdxOpen(templateSlug)
    if '$isobject(tpl) {
        return ##class(FAST.Util.Response).Error("Template not found: "_templateSlug, "404 Not Found")
    }
    set flow = ##class(FAST.Data.FlowDefinition).SlugIdxOpen(templateSlug)
    set created = 0
    if '$isobject(flow) {
        set flow = ##class(FAST.Data.FlowDefinition).%New()
        set flow.Slug = templateSlug
        set flow.Name = tpl.Name
        set flow.Description = tpl.Description
        set flow.DefinitionJSON = tpl.DefinitionJSON
        set flow.SourceTemplateSlug = templateSlug
        set flow.Status = "draft"
        set sc = flow.%Save()
        if $$$ISERR(sc) return ##class(FAST.Util.Response).Error("Could not create flow: "_$system.Status.GetErrorText(sc), "500 Internal Server Error")
        set created = 1
    }
    set o = {}
    set o.slug = flow.Slug
    set o.name = flow.Name
    set o.status = flow.Status
    set o.sourceTemplateSlug = flow.SourceTemplateSlug
    set o.created = created
    return ##class(FAST.Util.Response).WriteJSON(o, $select(created:"201 Created", 1:"200 OK"))
}

/// GET /flows/:slug — flow metadata + parsed definition.
ClassMethod GetFlow(slug As %String) As %Status
{
    set flow = ##class(FAST.Data.FlowDefinition).SlugIdxOpen(slug)
    if '$isobject(flow) {
        return ##class(FAST.Util.Response).Error("Flow not found: "_slug, "404 Not Found")
    }
    set o = {}
    set o.slug = flow.Slug
    set o.name = flow.Name
    set o.description = flow.Description
    set o.version = flow.Version
    set o.status = flow.Status
    set o.sourceTemplateSlug = flow.SourceTemplateSlug
    set o.definition = ..ParseOrNull(flow.DefinitionJSON)
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// POST /flows/:slug/compile — run the compiler, return artefact names.
ClassMethod CompileFlow(slug As %String) As %Status
{
    set sc = ##class(FAST.Compiler.Compiler).CompileFlow(slug, .errors)
    if $$$ISERR(sc) {
        set o = {}
        set o.error = "Compilation failed"
        set o.details = errors
        return ##class(FAST.Util.Response).WriteJSON(o, "400 Bad Request")
    }
    set names = []
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT ArtifactName FROM FAST_Data.CompiledArtifact WHERE FlowSlug = ? ORDER BY ArtifactName", slug)
    while rs.%Next() { do names.%Push(rs.%Get("ArtifactName")) }
    set o = {}
    set o.slug = slug
    set o.status = "compiled"
    set o.artifacts = names
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// GET /flows/:slug/artifacts — list artefact metadata.
ClassMethod ListArtifacts(slug As %String) As %Status
{
    set arr = []
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT ArtifactName, ArtifactType, ContentType, CreatedAt FROM FAST_Data.CompiledArtifact WHERE FlowSlug = ? ORDER BY ArtifactName", slug)
    while rs.%Next() {
        set a = {}
        set a.name = rs.%Get("ArtifactName")
        set a.type = rs.%Get("ArtifactType")
        set a.contentType = rs.%Get("ContentType")
        set a.createdAt = rs.%Get("CreatedAt")
        do arr.%Push(a)
    }
    set o = {}
    set o.slug = slug
    set o.artifacts = arr
    set o.count = arr.%Size()
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// GET /flows/:slug/artifacts/:name — raw artefact content (native content type).
ClassMethod GetArtifact(slug As %String, name As %String) As %Status
{
    set art = ##class(FAST.Data.CompiledArtifact).FlowArtifactIdxOpen(slug, name)
    if '$isobject(art) {
        return ##class(FAST.Util.Response).Error("Artifact not found: "_slug_"/"_name, "404 Not Found")
    }
    set %response.Status = "200 OK"
    set %response.ContentType = art.ContentType
    write art.Content
    return $$$OK
}

/// GET /flows/:slug/healthconnect-mapping — generate the mapping from the
/// flow or template definition (no prior compile required).
ClassMethod GetMapping(slug As %String) As %Status
{
    set def = ##class(FAST.Runtime.Runtime).LoadDef(slug)
    if '$isobject(def) {
        return ##class(FAST.Util.Response).Error("Not found: "_slug, "404 Not Found")
    }
    set %response.Status = "200 OK"
    set %response.ContentType = "application/json"
    write ##class(FAST.Compiler.MappingGenerator).Mapping(def)
    return $$$OK
}

/// POST /flows/:slug/deploy — register the compiled recipe.
ClassMethod DeployFlow(slug As %String) As %Status
{
    set sc = ##class(FAST.Runtime.Runtime).Deploy(slug)
    if $$$ISERR(sc) return ##class(FAST.Util.Response).Error($system.Status.GetErrorText(sc), "400 Bad Request")
    set o = {}, o.slug = slug, o.status = "deployed"
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// POST /flows/:slug/test — run the flow's configured test case.
ClassMethod TestFlow(slug As %String) As %Status
{
    set resp = ##class(FAST.Runtime.Runtime).RunTest(slug)
    return ##class(FAST.Util.Response).WriteJSON(resp)
}

/// POST /flows/:slug/run — run an agent with the studio's input values.
/// Body: { "inputs": { "<inputKey>": <value>, ... } }. Runs through the real
/// production; the definition's `inputs` split the patient from the context.
ClassMethod RunAgent(slug As %String) As %Status
{
    set body = ##class(FAST.Util.Response).Body()
    set inputs = $select($isobject(body) && $isobject(body.inputs): body.inputs, 1: {})
    set skipCache = $select($isobject(body): +body.skipCache, 1: 0)
    set resp = ##class(FAST.Runtime.Runtime).RunWithInputs(slug, inputs, skipCache)
    return ##class(FAST.Util.Response).WriteJSON(resp)
}

/// GET /options/patients — real Patient resources from the FHIR repository,
/// for the Run panel's patient picker. Each: { ref, label, sex, birthDate }.
ClassMethod OptionPatients() As %Status
{
    set arr = []
    set pts = ##class(FAST.Runtime.FHIRReadOperation).AllOfType("Patient"), it = pts.%GetIterator()
    while it.%GetNext(.k, .o) {
        set res = o.resource
        set p = {}
        set p.ref = "Patient/" _ res.id
        set p.label = ##class(FAST.Runtime.FHIRReadOperation).Display("Patient", res)
        set p.sex = $select(res.gender '= "": res.gender, 1: "")
        set p.birthDate = $select(res.birthDate '= "": res.birthDate, 1: "")
        do arr.%Push(p)
    }
    set o = {}, o.patients = arr, o.count = arr.%Size()
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// GET /options/resources?type=X&patient=Patient/Y — real resources of a type
/// for a patient, for reference pickers. Each: { ref, label }.
ClassMethod OptionResources() As %Status
{
    set type = %request.Get("type"), patient = %request.Get("patient")
    set arr = []
    if (type '= "") && (patient '= "") {
        set rp = ##class(FAST.Runtime.FHIRReadOperation).ResourcesForPatient(patient, type), it = rp.%GetIterator()
        while it.%GetNext(.k, .o) {
            set r = {}
            set r.ref = type _ "/" _ o.resource.id
            set r.label = ##class(FAST.Runtime.FHIRReadOperation).Display(type, o.resource)
            do arr.%Push(r)
        }
    }
    set o = {}, o.resourceType = type, o.resources = arr, o.count = arr.%Size()
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// POST /runtime/run — run an explicit AgentRequest { recipeId, patientId, context }.
ClassMethod RuntimeRun() As %Status
{
    set body = ##class(FAST.Util.Response).Body()
    if '$isobject(body) return ##class(FAST.Util.Response).Error("Invalid JSON body")
    set resp = ##class(FAST.Runtime.Runtime).RunRecipe(body.recipeId, body.patientId, body.context)
    return ##class(FAST.Util.Response).WriteJSON(resp)
}

/// GET /invocations — recent invocations.
ClassMethod ListInvocations() As %Status
{
    set arr = []
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT TOP 50 RequestId, RecipeId, Status, Summary, StartedAt, TraceId FROM FAST_Data.AgentInvocation ORDER BY StartedAt DESC")
    while rs.%Next() {
        set o = {}
        set o.requestId = rs.%Get("RequestId")
        set o.recipeId = rs.%Get("RecipeId")
        set o.status = rs.%Get("Status")
        set o.summary = rs.%Get("Summary")
        set o.startedAt = rs.%Get("StartedAt")
        set o.traceId = rs.%Get("TraceId")
        do arr.%Push(o)
    }
    set o = {}, o.invocations = arr, o.count = arr.%Size()
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// GET /invocations/:requestId — full result incl. response, evidence, actions.
ClassMethod GetInvocation(requestId As %String) As %Status
{
    set inv = ##class(FAST.Data.AgentInvocation).RequestIdxOpen(requestId)
    if '$isobject(inv) {
        return ##class(FAST.Util.Response).Error("Invocation not found: "_requestId, "404 Not Found")
    }
    set o = {}
    set o.requestId = inv.RequestId
    set o.recipeId = inv.RecipeId
    set o.status = inv.Status
    set o.summary = inv.Summary
    set o.traceId = inv.TraceId
    set o.response = ..ParseOrNull(inv.ResponseJSON)
    set actions = []
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT ID, ActionType, ResourceType, Status, RequiresApproval, ResourceJSON FROM FAST_Data.ProposedAction WHERE InvocationId = ?", requestId)
    while rs.%Next() {
        set a = {}
        set a.id = rs.%Get("ID")
        set a.actionType = rs.%Get("ActionType")
        set a.resourceType = rs.%Get("ResourceType")
        set a.status = rs.%Get("Status")
        set a.requiresApproval = rs.%Get("RequiresApproval")
        set a.resource = ..ParseOrNull(rs.%Get("ResourceJSON"))
        do actions.%Push(a)
    }
    set o.proposedActions = actions
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// GET /traces/:traceId — trace steps.
ClassMethod GetTrace(traceId As %String) As %Status
{
    set o = {}
    set o.traceId = traceId
    set o.steps = ##class(FAST.Runtime.TraceStore).AsArray(traceId)
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// ---- Agent authoring (create/update/clone/delete a flow → compile → deploy) ----
ClassMethod SaveFlow() As %Status
{
    return ##class(FAST.API.Authoring).Save()
}

ClassMethod UpdateFlow(slug As %String) As %Status
{
    return ##class(FAST.API.Authoring).Save(slug)
}

ClassMethod DeleteFlow(slug As %String) As %Status
{
    return ##class(FAST.API.Authoring).Delete(slug)
}

ClassMethod CloneFlow(slug As %String) As %Status
{
    return ##class(FAST.API.Authoring).Clone(slug)
}

/// POST /authoring/step-test — run one builder step (real engines, no Ens send).
ClassMethod AuthoringStepTest() As %Status
{
    return ##class(FAST.API.Authoring).StepTest()
}

/// POST /authoring/prompt-preview — the exact prompt the AI step would send.
ClassMethod AuthoringPromptPreview() As %Status
{
    return ##class(FAST.API.Authoring).PromptPreview()
}

/// ---- Approval workflow (commit a draft to FHIR + audit, or reject) ----
ClassMethod ApproveAction(requestId As %String, actionId As %String) As %Status
{
    return ##class(FAST.API.Approval).Approve(requestId, actionId)
}

ClassMethod RejectAction(requestId As %String, actionId As %String) As %Status
{
    return ##class(FAST.API.Approval).Reject(requestId, actionId)
}

ClassMethod GetAudit(requestId As %String) As %Status
{
    return ##class(FAST.API.Approval).AuditTrail(requestId)
}

/// GET /worklists/:key — a cohort-backed list of patients for a clinical worklist.
/// Minimal registry for now (real reverse-chain cohorts); expanded in the Clinical app.
ClassMethod GetWorklist(key As %String) As %Status
{
    // key → { code, resourceType } cohort definition
    set code = "", rt = "Condition"
    if key = "diabetes" set code = "44054006"
    if key = "hypertension" set code = "38341003"
    if key = "ckd" set code = "709044004"
    if key = "heart-failure" set code = "84114007"
    if code = "" return ##class(FAST.Util.Response).Error("Unknown worklist: " _ key, "404 Not Found")
    set cohort = ##class(FAST.Runtime.FHIRTools).CohortByCode(code, rt)
    set o = {}, o.worklist = key, o.code = code, o.patients = cohort.patients, o.count = cohort.count
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// ---- Reusable component CRUD (Prompt/EvidenceSource/ActionTemplate/OutputSchema) ----
/// :entity is one of prompts | evidence-sources | actions | output-schemas.
ClassMethod CompList(entity As %String) As %Status
{
    return ##class(FAST.API.Components).List(entity)
}

ClassMethod CompCreate(entity As %String) As %Status
{
    return ##class(FAST.API.Components).Upsert(entity)
}

ClassMethod CompGet(entity As %String, slug As %String) As %Status
{
    return ##class(FAST.API.Components).Get(entity, slug)
}

ClassMethod CompUpdate(entity As %String, slug As %String) As %Status
{
    return ##class(FAST.API.Components).Upsert(entity, slug)
}

ClassMethod CompDelete(entity As %String, slug As %String) As %Status
{
    return ##class(FAST.API.Components).Delete(entity, slug)
}

/// ---- Explicit FHIR tools (real reads/searches over the FHIR R4 repository) ----
/// GET /fhir/tools/patient-search?name=&gender=&birthDate=&nhs=&mrn=&identifier=
ClassMethod ToolPatientSearch() As %Status
{
    set o = ##class(FAST.Runtime.FHIRTools).PatientSearch(%request.Get("name"), %request.Get("gender"), %request.Get("birthDate"), %request.Get("identifier"), 2000, %request.Get("nhs"), %request.Get("mrn"))
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// GET /care-plan/demo-patients — the cohort the Care Plan Navigator is cached
/// for (syn-pat-0001..0012), for the patient-portal selector. [{id, name}].
ClassMethod CarePlanDemoPatients() As %Status
{
    set read = "FAST.Runtime.FHIRReadOperation"
    set arr = []
    for i = 1:1:12 {
        set id = "syn-pat-" _ $extract("000" _ i, *-3, *)
        set pl = $classmethod(read, "ResourcesForPatient", "Patient/" _ id, "Patient")
        if pl.%Size() = 0 continue
        set p = {}, p.id = id
        set p.name = $classmethod(read, "Display", "Patient", pl.%Get(0).resource)
        do arr.%Push(p)
    }
    set o = {}, o.patients = arr, o.count = arr.%Size()
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// POST /patients/:id/care-plan/tasks { tasks:[{task,owner}] } — accept the
/// navigator's suggested tasks: create real draft FHIR Task resources.
ClassMethod CarePlanCreateTasks(id As %String) As %Status
{
    set body = ##class(FAST.Util.Response).Body()
    set patientRef = "Patient/" _ id
    set created = 0, refs = []
    if $isobject(body) && $isobject(body.tasks) {
        set it = body.tasks.%GetIterator()
        while it.%GetNext(.k, .t) {
            set desc = $select($isobject(t): t.task, 1: t)
            if desc = "" continue
            set seq = $increment(^FAST("ordSeq")), tid = "syn-cptask-" _ seq
            set task = {"resourceType": "Task", "status": "draft", "intent": "order", "priority": "routine"}
            set task.id = tid
            set task.description = desc
            set task.for = {"reference": (patientRef)}
            set task.authoredOn = $translate($zdatetime($ztimestamp, 3), " ", "T") _ "Z"
            if $isobject(t) && (t.owner '= "") set task.requester = {"display": (t.owner)}
            set batch = [], item = {}, item.resourceType = "Task", item.resourceId = tid
            do item.%Set("resource", task)
            do batch.%Push(item)
            do ##class(FAST.Seed.SeedLoader).PutBundle(batch)
            do refs.%Push("Task/" _ tid)
            set created = created + 1
        }
    }
    set o = {}, o.ok = 1, o.created = created, o.refs = refs
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// POST /patients/:id/triage-session { complaint, items:[{question,answer}] } —
/// persist the completed triage conversation to the REAL FHIR repository as a
/// QuestionnaireResponse, so the patient's own answers live in the record.
ClassMethod TriageSaveSession(id As %String) As %Status
{
    set body = ##class(FAST.Util.Response).Body()
    set patientRef = "Patient/" _ id
    set seq = $increment(^FAST("ordSeq")), qid = "syn-triageqr-" _ seq
    set qr = {"resourceType": "QuestionnaireResponse", "status": "completed"}
    set qr.id = qid
    set qr.questionnaire = "https://fhir.fast.health/Questionnaire/triage-conversation"
    set qr.subject = {"reference": (patientRef)}
    set qr.authored = $translate($zdatetime($ztimestamp, 3), " ", "T") _ "Z"
    set qr.item = []
    if $isobject(body) {
        if body.complaint '= "" do qr.item.%Push({"linkId": "complaint", "text": "What brings you in today?", "answer": [{"valueString": (body.complaint)}]})
        if $isobject(body.items) {
            set it = body.items.%GetIterator()
            while it.%GetNext(.k, .qa) {
                if '$isobject(qa) || (qa.question = "") || (qa.answer = "") continue
                do qr.item.%Push({"linkId": ("q" _ (k + 1)), "text": (qa.question), "answer": [{"valueString": (qa.answer)}]})
            }
        }
    }
    set batch = [], item = {}, item.resourceType = "QuestionnaireResponse", item.resourceId = qid
    do item.%Set("resource", qr)
    do batch.%Push(item)
    do ##class(FAST.Seed.SeedLoader).PutBundle(batch)
    set o = {}, o.ok = 1, o.ref = "QuestionnaireResponse/" _ qid
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// GET /options/evidence — everything the agent builder can compose from:
/// FHIR resource types, named SQL queries, vector collections, and the
/// reusable component library (evidence sources, output schemas, prompts).
ClassMethod OptionsEvidence() As %Status
{
    set o = {}
    set o.fhirTypes = ["Patient", "Condition", "Observation", "MedicationRequest", "MedicationStatement", "AllergyIntolerance", "DiagnosticReport", "Encounter", "Procedure", "Immunization", "CarePlan", "Goal", "Task", "ServiceRequest", "Appointment", "Coverage", "QuestionnaireResponse", "DocumentReference", "Flag"]
    set o.sqlQueries = ["active_conditions", "recent_labs", "recent_encounters", "medication_history", "admission_history", "overdue_tasks", "offtrack_goals", "overdue_screenings", "abnormal_result_followup_status", "prior_auth_supporting_evidence", "diabetes_a1c_over_9_last_6_months"]
    set cols = [], rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT DISTINCT %EXACT(Collection) AS Collection FROM FAST_Data.KnowledgeDocument ORDER BY 1")
    while rs.%Next() { do cols.%Push(rs.%Get("Collection")) }
    set o.vectorCollections = cols
    // component library (slug + name) for pickers
    for spec = "evidenceSources$FAST_Data.EvidenceSource", "outputSchemas$FAST_Data.OutputSchema", "prompts$FAST_Data.Prompt", "actionTemplates$FAST_Data.ActionTemplate" {
        set list = [], rs2 = ##class(%SQL.Statement).%ExecDirect(, "SELECT Slug, Name FROM " _ $piece(spec, "$", 2) _ " ORDER BY Slug")
        while rs2.%Next() { do list.%Push({"slug": (rs2.%Get("Slug")), "name": (rs2.%Get("Name"))}) }
        do o.%Set($piece(spec, "$", 1), list)
    }
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// GET /admin/llm — the AI connection state. The key is NEVER returned; only
/// whether one is set and a masked hint.
ClassMethod AdminLLMGet() As %Status
{
    set o = {}
    set key = ##class(FAST.Runtime.LLMClient).Key()
    set o.keySet = (key '= "")
    set o.keyMasked = $select(key = "": "", 1: $extract(key, 1, 4) _ "…" _ $extract(key, *-3, *))
    set o.model = $get(^FAST("llm", "model"))
    set o.endpoint = $get(^FAST("llm", "endpoint"))
    set o.useCache = +$get(^FAST("llm", "useCache"), 1)
    set o.mode = $get(^FAST("llm", "mode"))
    // transparency stats: the bundled-cache corpus + this session's tier counters
    set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(Kind) AS Kind, COUNT(*) AS N FROM FAST_Data.LLMCache GROUP BY Kind")
    set cc = {}
    while rs.%Next() { do cc.%Set(rs.%Get("Kind"), rs.%Get("N")) }
    set o.cacheCounts = cc
    set o.tiers = {"cached": (+$get(^FAST("stats", "tier", "cached"))), "live": (+$get(^FAST("stats", "tier", "live"))), "deterministic": (+$get(^FAST("stats", "tier", "deterministic")))}
    set o.promptVersion = $parameter("FAST.Runtime.AIHubOperation", "PROMPTVERSION")
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// GET /admin/llm/cache?kind=&q=&offset=&limit= — browse the record/replay
/// corpus. Every entry is a REAL model completion generated once and replayed
/// verbatim; opening the corpus for inspection is the "nothing up our sleeves"
/// proof. Prompts are stored truncated (preview) - matching uses the hash key.
ClassMethod AdminLLMCacheList() As %Status
{
    set kind = $get(%request.Data("kind", 1)), q = $get(%request.Data("q", 1))
    set offset = +$get(%request.Data("offset", 1), 0), limit = +$get(%request.Data("limit", 1), 50)
    if (limit < 1) || (limit > 200) set limit = 50
    set sql = "SELECT ID, CacheKey, Kind, Model, PromptVersion, CreatedAt, $LENGTH(OutputJSON) AS Size, $EXTRACT(InputPreview, 1, 220) AS Preview FROM FAST_Data.LLMCache"
    set where = "", args = 0
    if kind '= "" { set where = "Kind = ?", args = args + 1, arg(args) = kind }
    if q '= "" {
        set where = where _ $select(where = "": "", 1: " AND ") _ "(InputPreview LIKE ? OR OutputJSON LIKE ?)"
        set args = args + 1, arg(args) = "%" _ q _ "%"
        set args = args + 1, arg(args) = "%" _ q _ "%"
    }
    if where '= "" set sql = sql _ " WHERE " _ where
    set sql = sql _ " ORDER BY ID DESC"
    set stmt = ##class(%SQL.Statement).%New()
    do stmt.%Prepare(sql)
    if args = 2 { set rs = stmt.%Execute(arg(1), arg(2)) }
    elseif args = 3 { set rs = stmt.%Execute(arg(1), arg(2), arg(3)) }
    elseif args = 1 { set rs = stmt.%Execute(arg(1)) }
    else { set rs = stmt.%Execute() }
    set list = [], n = 0
    while rs.%Next() {
        set n = n + 1
        if n <= offset continue
        if list.%Size() >= limit continue
        do list.%Push({"id": (rs.%Get("ID")), "kind": (rs.%Get("Kind")), "model": (rs.%Get("Model")), "promptVersion": (rs.%Get("PromptVersion")), "createdAt": (rs.%Get("CreatedAt")), "size": (rs.%Get("Size")), "preview": (rs.%Get("Preview")), "cacheKey": (rs.%Get("CacheKey")) })
    }
    return ##class(FAST.Util.Response).WriteJSON({"total": (n), "entries": (list)})
}

/// GET /admin/llm/cache/:id — one corpus entry in full: the truncated prompt
/// preview and the complete stored completion, with generation metadata.
ClassMethod AdminLLMCacheGet(id As %String) As %Status
{
    set rec = ##class(FAST.Data.LLMCache).%OpenId(id)
    if '$isobject(rec) return ##class(FAST.Util.Response).WriteJSON({"error": "not found"})
    set o = {}
    set o.id = id, o.cacheKey = rec.CacheKey, o.kind = rec.Kind, o.model = rec.Model
    set o.promptVersion = rec.PromptVersion, o.createdAt = rec.CreatedAt
    set o.inputPreview = rec.InputPreview
    set o.output = rec.OutputJSON
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// POST /admin/llm { key?, clearKey?, model?, endpoint?, useCache? } — update
/// the AI connection. The key lives ONLY in IRISTEMP (never journaled, never in
/// the durable database, wiped on every instance restart); it is never logged
/// and never echoed back. Model/endpoint/useCache are non-secret config and
/// stay in the durable ^FAST global.
ClassMethod AdminLLMSet() As %Status
{
    set body = ##class(FAST.Util.Response).Body()
    if $isobject(body) {
        if body.key '= "" do ##class(FAST.Runtime.LLMClient).SetKey(body.key)
        if body.clearKey = 1 do ##class(FAST.Runtime.LLMClient).SetKey("")
        if body.model '= "" set ^FAST("llm", "model") = body.model
        if body.endpoint '= "" set ^FAST("llm", "endpoint") = body.endpoint
        if body.%IsDefined("useCache") set ^FAST("llm", "useCache") = +body.useCache
    }
    return ..AdminLLMGet()
}

/// POST /admin/llm/test — one tiny live round-trip to prove the key works.
ClassMethod AdminLLMTest() As %Status
{
    set o = {}
    if ##class(FAST.Runtime.LLMClient).Key() = "" {
        set o.ok = 0, o.error = "No API key is set."
        return ##class(FAST.Util.Response).WriteJSON(o)
    }
    try {
        set msgs = [{"role": "user", "content": "Reply with exactly: OK"}]
        set sc = ##class(FAST.Runtime.LLMClient).Chat(msgs, .content, 0)
        if $$$ISOK(sc) {
            set o.ok = 1, o.model = $get(^FAST("llm", "model")), o.reply = $extract($zstrip(content, "<>WC"), 1, 40)
        } else {
            set o.ok = 0, o.error = $zstrip($system.Status.GetErrorText(sc), "<>W")
        }
    } catch ex {
        set o.ok = 0, o.error = ex.DisplayString()
    }
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// POST /patients/:id/communication { category, text } — record a real FHIR
/// Communication resource (a sent message / shared explanation / discussion
/// note) so the UI's "send"-style actions genuinely land in the record.
ClassMethod SaveCommunication(id As %String) As %Status
{
    set body = ##class(FAST.Util.Response).Body()
    set text = $select($isobject(body): body.text, 1: "")
    if text = "" {
        set e = {}, e.ok = 0, e.error = "text is required"
        return ##class(FAST.Util.Response).WriteJSON(e)
    }
    set seq = $increment(^FAST("ordSeq")), cid = "syn-comm-" _ seq
    set c = {"resourceType": "Communication", "status": "completed"}
    set c.id = cid
    set c.subject = {"reference": ("Patient/" _ id)}
    set c.sent = $translate($zdatetime($ztimestamp, 3), " ", "T") _ "Z"
    if $isobject(body) && (body.category '= "") set c.category = [{"text": (body.category)}]
    set c.payload = [{"contentString": ($extract(text, 1, 2000))}]
    set batch = [], item = {}, item.resourceType = "Communication", item.resourceId = cid
    do item.%Set("resource", c)
    do batch.%Push(item)
    do ##class(FAST.Seed.SeedLoader).PutBundle(batch)
    set o = {}, o.ok = 1, o.ref = "Communication/" _ cid
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// GET /patients/:id/preventative — what this patient is due/overdue for.
ClassMethod PreventativeForPatient(id As %String) As %Status
{
    return ##class(FAST.Util.Response).WriteJSON(##class(FAST.Runtime.Preventative).ForPatient("Patient/" _ id))
}

/// POST /patients/:id/preventative/letter { area } — AI invitation letter draft.
ClassMethod PreventativeLetter(id As %String) As %Status
{
    set body = ##class(FAST.Util.Response).Body()
    set area = $select($isobject(body): body.area, 1: "")
    return ##class(FAST.Util.Response).WriteJSON(##class(FAST.Runtime.Preventative).Letter("Patient/" _ id, area))
}

/// GET /care-rules — all saved preventative-care rules.
ClassMethod CareRulesList() As %Status
{
    set o = {}, o.rules = ##class(FAST.Runtime.CareRules).ListJSON()
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// POST /care-rules { name, description } — author a rule (AI writes the SQL).
ClassMethod CareRulesCreate() As %Status
{
    set body = ##class(FAST.Util.Response).Body()
    set name = $select($isobject(body): body.name, 1: ""), desc = $select($isobject(body): body.description, 1: "")
    return ##class(FAST.Util.Response).WriteJSON(##class(FAST.Runtime.CareRules).Create(name, desc))
}

/// POST /care-rules/:slug/run — execute the rule's SQL and return matches.
ClassMethod CareRulesRun(slug As %String) As %Status
{
    return ##class(FAST.Util.Response).WriteJSON(##class(FAST.Runtime.CareRules).Run(slug))
}

/// GET /care-rules/:slug/worklist — the persisted worklist entries for a rule.
ClassMethod CareRulesWorklist(slug As %String) As %Status
{
    return ##class(FAST.Util.Response).WriteJSON(##class(FAST.Runtime.CareRules).WorklistEntries(slug))
}

/// POST /care-rules/:slug/worklist/update — run the rule, append new matches.
ClassMethod CareRulesWorklistUpdate(slug As %String) As %Status
{
    return ##class(FAST.Util.Response).WriteJSON(##class(FAST.Runtime.CareRules).UpdateWorklist(slug))
}

/// DELETE /care-rules/:slug — remove a rule.
ClassMethod CareRulesDelete(slug As %String) As %Status
{
    return ##class(FAST.Util.Response).WriteJSON(##class(FAST.Runtime.CareRules).Delete(slug))
}

/// GET /orders/catalogue — the demo order catalogue (PA-required items).
ClassMethod OrdersCatalogue() As %Status
{
    set o = {}, o.catalogue = ##class(FAST.Runtime.Orders).CatalogueJSON()
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// GET /patients/:id/orders — the patient's orders with PA status.
ClassMethod OrdersList(id As %String) As %Status
{
    return ##class(FAST.Util.Response).WriteJSON(##class(FAST.Runtime.Orders).ListForPatient("Patient/" _ id))
}

/// POST /patients/:id/orders { itemId } — place an order (assembles the PA).
ClassMethod OrdersPlace(id As %String) As %Status
{
    set body = ##class(FAST.Util.Response).Body()
    set itemId = $select($isobject(body) && (body.itemId '= ""): body.itemId, 1: "")
    return ##class(FAST.Util.Response).WriteJSON(##class(FAST.Runtime.Orders).Place("Patient/" _ id, itemId))
}

/// POST /pa/:claimId/submit — submit the PA and simulate the payer decision.
ClassMethod OrdersSubmit(claimId As %String) As %Status
{
    return ##class(FAST.Util.Response).WriteJSON(##class(FAST.Runtime.Orders).Submit(claimId))
}

/// GET /pa-queue — all prior-authorisation claims across patients, with status.
ClassMethod OrdersQueue() As %Status
{
    return ##class(FAST.Util.Response).WriteJSON(##class(FAST.Runtime.Orders).Queue())
}

/// GET /fhir/tools/everything?patient=Patient/123
ClassMethod ToolEverything() As %Status
{
    set patient = %request.Get("patient")
    if patient = "" return ##class(FAST.Util.Response).Error("A 'patient' reference is required")
    return ##class(FAST.Util.Response).WriteJSON(##class(FAST.Runtime.FHIRTools).Everything(patient))
}

/// GET /fhir/tools/terminology?text=type 2 diabetes&system=SNOMED
ClassMethod ToolTerminology() As %Status
{
    set text = %request.Get("text")
    if text = "" return ##class(FAST.Util.Response).Error("A 'text' value is required")
    return ##class(FAST.Util.Response).WriteJSON(##class(FAST.Runtime.FHIRTools).TerminologyResolve(text, %request.Get("system")))
}

/// GET /fhir/tools/cohort?code=44054006&resourceType=Condition
ClassMethod ToolCohort() As %Status
{
    set code = %request.Get("code")
    if code = "" return ##class(FAST.Util.Response).Error("A 'code' value is required")
    set rt = $select(%request.Get("resourceType") '= "": %request.Get("resourceType"), 1: "Condition")
    return ##class(FAST.Util.Response).WriteJSON(##class(FAST.Runtime.FHIRTools).CohortByCode(code, rt))
}

/// Row count for a SQL table, tolerant of errors.
ClassMethod Count(table As %String) As %Integer
{
    set n = 0
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT COUNT(*) AS N FROM "_table)
    if rs.%Next() set n = rs.%Get("N")
    return +n
}

/// Parse a JSON string to a dynamic object, or return null on empty/invalid.
ClassMethod ParseOrNull(json As %String) As %DynamicAbstractObject
{
    if (json = "") return ""
    try { return ##class(%DynamicAbstractObject).%FromJSON(json) } catch { return "" }
}

}
