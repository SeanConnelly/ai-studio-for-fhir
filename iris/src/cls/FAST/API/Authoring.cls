/// Agent authoring: create / update / clone / delete a FlowDefinition from the
/// Studio's Agent Builder, then validate → compile → deploy in one step so the
/// saved agent is immediately runnable. The definition is the same JSON shape the
/// 12 system templates use (trigger / inputs / evidence / agent / action / testCase),
/// optionally composed from reusable component refs (resolved at compile time).
Class FAST.API.Authoring [ Abstract ]
{

/// Create (POST) or update (PUT) a flow from a posted definition. On success the
/// flow is validated, compiled and deployed. Returns { slug, created, status,
/// compiled, deployed, errors }.
ClassMethod Save(slug As %String = "") As %Status
{
    set body = ##class(FAST.Util.Response).Body()
    if '$isobject(body) return ##class(FAST.Util.Response).Error("Invalid JSON body")
    // accept slug from the path, else body.slug, else body.id
    if slug = "" set slug = $select(body.slug '= "": body.slug, 1: body.id)
    if slug = "" return ##class(FAST.Util.Response).Error("A 'slug' (or 'id') is required")

    set flow = ##class(FAST.Data.FlowDefinition).SlugIdxOpen(slug), created = 0
    if '$isobject(flow) {
        set flow = ##class(FAST.Data.FlowDefinition).%New()
        set flow.Slug = slug
        set created = 1
    }
    set flow.Name = $select(body.name '= "": body.name, 1: flow.Name)
    set flow.Description = $select(body.description '= "": body.description, 1: flow.Description)
    if body.%IsDefined("version") set flow.Version = body.version
    if body.%IsDefined("sourceTemplateSlug") set flow.SourceTemplateSlug = body.sourceTemplateSlug
    // ensure the definition carries its own id (compiler/runtime read it)
    do body.%Set("id", slug)
    set flow.DefinitionJSON = ##class(FAST.Util.JSON).ToString(body, 0)
    set flow.Status = "draft"
    set flow.UpdatedAt = $zdatetime($ztimestamp, 3)
    set sc = flow.%Save()
    if $$$ISERR(sc) return ##class(FAST.Util.Response).Error($system.Status.GetErrorText(sc), "500 Internal Server Error")

    return ..CompileDeployResponse(slug, created)
}

/// Clone an existing flow (or system template) under a new slug. Body: { newSlug,
/// newName }. The clone is compiled + deployed.
ClassMethod Clone(slug As %String) As %Status
{
    set body = ##class(FAST.Util.Response).Body()
    set newSlug = $select($isobject(body) && (body.newSlug '= ""): body.newSlug, 1: slug _ "-copy")
    set newName = $select($isobject(body) && (body.newName '= ""): body.newName, 1: "")

    set def = ##class(FAST.Runtime.Runtime).LoadDef(slug)
    if '$isobject(def) return ##class(FAST.Util.Response).Error("Source not found: " _ slug, "404 Not Found")
    if $isobject(##class(FAST.Data.FlowDefinition).SlugIdxOpen(newSlug)) {
        return ##class(FAST.Util.Response).Error("A flow already exists with slug: " _ newSlug, "409 Conflict")
    }
    do def.%Set("id", newSlug)
    if newName '= "" set def.name = newName
    else  set def.name = $select(def.name '= "": def.name, 1: slug) _ " (copy)"

    set flow = ##class(FAST.Data.FlowDefinition).%New()
    set flow.Slug = newSlug
    set flow.Name = def.name
    set flow.Description = def.description
    set flow.SourceTemplateSlug = slug
    set flow.DefinitionJSON = ##class(FAST.Util.JSON).ToString(def, 0)
    set flow.Status = "draft"
    set sc = flow.%Save()
    if $$$ISERR(sc) return ##class(FAST.Util.Response).Error($system.Status.GetErrorText(sc), "500 Internal Server Error")

    return ..CompileDeployResponse(newSlug, 1)
}

/// Delete a flow + its compiled artefacts + deployed recipe.
ClassMethod Delete(slug As %String) As %Status
{
    set flow = ##class(FAST.Data.FlowDefinition).SlugIdxOpen(slug)
    if '$isobject(flow) return ##class(FAST.Util.Response).Error("Flow not found: " _ slug, "404 Not Found")
    set sc = ##class(FAST.Data.FlowDefinition).%DeleteId(flow.%Id())
    if $$$ISERR(sc) return ##class(FAST.Util.Response).Error($system.Status.GetErrorText(sc), "500 Internal Server Error")
    // clean up artefacts + deployed recipe (best effort)
    &sql(DELETE FROM FAST_Data.CompiledArtifact WHERE FlowSlug = :slug)
    set dr = ##class(FAST.Data.DeployedRecipe).RecipeIdxOpen(slug)
    if $isobject(dr) do ##class(FAST.Data.DeployedRecipe).%DeleteId(dr.%Id())
    set o = {}, o.slug = slug, o.deleted = 1
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// POST /authoring/step-test - execute ONE builder step against a test patient
/// using the SAME engine classmethods the runtime's Business Operations call,
/// and return its real output so an author can test each step as they build.
/// Body: { kind: "fhir"|"sql-named"|"vector"|"source"|"source-spec", patientRef,
///   context?, resourceTypes?, name?, collection?, queryFrom?, queryText?,
///   topK?, description?, slug?, sourceKind?, spec? }
/// Returns { ok, kind, ms, summary, result }.
ClassMethod StepTest() As %Status
{
    set body = ##class(FAST.Util.Response).Body()
    if '$isobject(body) return ##class(FAST.Util.Response).Error("Invalid JSON body")
    set kind = body.kind
    set patientRef = body.patientRef
    set ctxObj = body.%Get("context")
    if '$isobject(ctxObj) set ctxObj = {}
    set o = {}, o.kind = kind
    set t0 = $zhorolog
    try {
        if kind = "fhir" {
            set types = body.%Get("resourceTypes")
            if '$isobject(types) set types = []
            set res = ##class(FAST.Runtime.FHIRReadOperation).Gather(patientRef, types)
            set o.result = res
            set o.summary = +res.count _ " FHIR resource(s)"
        }
        elseif kind = "sql-named" {
            set res = ##class(FAST.Runtime.SQLQueryOperation).Run(body.name, patientRef)
            set o.result = res
            set o.summary = ..FactSummary(res)
        }
        elseif kind = "vector" {
            set topK = $select(+body.topK > 0: +body.topK, 1: 3)
            set qtext = body.queryText
            if qtext = "" {
                // resolve the query text exactly as the runtime will at run time
                set vdef = {}
                set vdef.description = body.description
                set vdef.evidence = {"vectorQueryFrom": (body.queryFrom)}
                set qtext = ##class(FAST.Runtime.Runtime).VectorQueryText(vdef, ctxObj, patientRef)
            }
            set chunks = ##class(FAST.Runtime.VectorSearchOperation).Search(body.collection, qtext, topK)
            set o.result = {"collection": (body.collection), "queryText": (qtext), "chunks": (chunks)}
            set o.summary = chunks.%Size() _ " chunk(s)"
        }
        elseif kind = "source" {
            set res = ##class(FAST.Runtime.EvidenceEngine).RunBySlug(body.slug, patientRef, ctxObj)
            set o.result = res
            set o.summary = ..FactSummary(res)
        }
        elseif kind = "source-spec" {
            set res = ##class(FAST.Runtime.EvidenceEngine).Run(body.sourceKind, body.%Get("spec"), patientRef, ctxObj)
            set o.result = res
            set o.summary = ..FactSummary(res)
        }
        else {
            return ##class(FAST.Util.Response).Error("Unknown step kind: " _ kind)
        }
        set o.ok = 1
    } catch ex {
        set o.ok = 0
        set o.error = ex.DisplayString()
    }
    set o.ms = +$number(($zhorolog - t0) * 1000, 0)
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// POST /authoring/prompt-preview - gather evidence for the POSTED definition
/// (so unsaved edits are reflected) and return the EXACT system + user messages
/// the AI step would send, assembled by the same code path the runtime uses
/// (FAST.Runtime.AIHubOperation.Prompt). No LLM call is made, nothing is cached.
/// Body: { definition, patientRef, context? }.
/// Returns { ok, system, user, evidence: {fhir, sql, vectorChunks, sources}, ms }.
ClassMethod PromptPreview() As %Status
{
    set body = ##class(FAST.Util.Response).Body()
    if '$isobject(body) return ##class(FAST.Util.Response).Error("Invalid JSON body")
    set def = body.%Get("definition")
    if '$isobject(def) return ##class(FAST.Util.Response).Error("A 'definition' object is required")
    set patientRef = body.patientRef
    set ctxObj = body.%Get("context")
    if '$isobject(ctxObj) set ctxObj = {}
    set o = {}, counts = {}
    set t0 = $zhorolog
    try {
        set ctx = {}
        set ctx.recipeId = def.id
        set ctx.patientRef = patientRef
        do ctx.%Set("context", ctxObj)
        do ctx.%Set("def", def)
        set ev = def.%Get("evidence")
        // gather evidence exactly as FAST.BP.AgentOrchestrator does
        if $isobject(ev) {
            if ##class(FAST.Util.JSON).ArrSize(ev.fhir) > 0 {
                set fhir = ##class(FAST.Runtime.FHIRReadOperation).Gather(patientRef, ev.fhir)
                do ctx.%Set("fhir", fhir)
                set counts.fhir = +fhir.count
            }
            if ##class(FAST.Util.JSON).ArrSize(ev.sql) > 0 {
                set sqlres = {}, n = 0, it = ev.sql.%GetIterator()
                while it.%GetNext(.k, .nm) {
                    do sqlres.%Set(nm, ##class(FAST.Runtime.SQLQueryOperation).Run(nm, patientRef))
                    set n = n + 1
                }
                do ctx.%Set("sql", sqlres)
                set counts.sql = n
            }
            if ##class(FAST.Util.JSON).ArrSize(ev.vector) > 0 {
                set vec = {}, qtext = ##class(FAST.Runtime.Runtime).VectorQueryText(def, ctxObj, patientRef)
                set topK = $select(+ev.vectorTopK > 0: +ev.vectorTopK, 1: 3)
                set nch = 0, it = ev.vector.%GetIterator()
                while it.%GetNext(.k, .col) {
                    set chunks = ##class(FAST.Runtime.VectorSearchOperation).Search(col, qtext, topK)
                    do vec.%Set(col, chunks)
                    set nch = nch + chunks.%Size()
                }
                do ctx.%Set("vector", vec)
                set counts.vectorChunks = nch
                set counts.vectorQueryText = qtext
            }
            if ##class(FAST.Util.JSON).ArrSize(ev.sources) > 0 {
                set srcs = {}, n = 0, it = ev.sources.%GetIterator()
                while it.%GetNext(.k, .sl) {
                    do srcs.%Set(sl, ##class(FAST.Runtime.EvidenceEngine).RunBySlug(sl, patientRef, ctxObj))
                    set n = n + 1
                }
                do ctx.%Set("sources", srcs)
                set counts.sources = n
            }
        }
        set prompt = ##class(FAST.Runtime.AIHubOperation).Prompt(ctx)
        set o.ok = 1
        set o.system = prompt.system
        set o.user = prompt.user
        do o.%Set("evidence", counts)
    } catch ex {
        set o.ok = 0
        set o.error = ex.DisplayString()
    }
    set o.ms = +$number(($zhorolog - t0) * 1000, 0)
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// One-line human summary of a facts object (rows / facts / chunks / resources).
ClassMethod FactSummary(res As %DynamicObject) As %String
{
    if '$isobject(res) return ""
    if res.%IsDefined("error") && (res.error '= "") return "error: " _ res.error
    if $isobject(res.rows) return res.rows.%Size() _ " row(s)"
    if $isobject(res.facts) return res.facts.%Size() _ " fact(s)"
    if $isobject(res.chunks) return res.chunks.%Size() _ " chunk(s)"
    if $isobject(res.resources) return res.resources.%Size() _ " resource(s)"
    if res.%IsDefined("count") return res.count _ " item(s)"
    return "ok"
}

/// Compile + deploy a flow and assemble the standard authoring response.
ClassMethod CompileDeployResponse(slug As %String, created As %Boolean) As %Status
{
    set o = {}, o.slug = slug, o.created = created
    set sc = ##class(FAST.Compiler.Compiler).CompileFlow(slug, .errors)
    if $$$ISERR(sc) {
        set o.status = "draft", o.compiled = 0, o.deployed = 0
        set o.errors = $select($isobject(errors): errors, 1: [])
        return ##class(FAST.Util.Response).WriteJSON(o, "400 Bad Request")
    }
    set o.compiled = 1
    set dsc = ##class(FAST.Runtime.Runtime).Deploy(slug)
    set o.deployed = ($$$ISOK(dsc))
    set o.status = $select(o.deployed: "deployed", 1: "compiled")
    set o.errors = []
    return ##class(FAST.Util.Response).WriteJSON(o, $select(created: "201 Created", 1: "200 OK"))
}

}
