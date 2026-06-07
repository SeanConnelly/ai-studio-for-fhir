/// Business Process: orchestrates the agent run by sending real messages to the
/// Business Operations (FHIR read, SQL, vector search, AI, writeback), records a
/// trace, and assembles the AgentResponse. This is the real interoperability
/// runtime — each step is a genuine Ens message (visible in the Visual Trace).
Class FAST.BP.AgentOrchestrator Extends Ens.BusinessProcess
{

Method OnRequest(pReq As FAST.Msg.AgentRequest, Output pResp As FAST.Msg.AgentResponse) As %Status
{
    set pResp = ##class(FAST.Msg.AgentResponse).%New()
    set recipeId = pReq.RecipeId, patientRef = pReq.PatientRef
    set contextObj = ##class(FAST.Util.JSON).Parse(pReq.ContextJSON)
    if '$isobject(contextObj) set contextObj = {}

    set def = ##class(FAST.Runtime.Runtime).LoadDef(recipeId)
    if '$isobject(def) {
        set e = {}, e.error = "No recipe/flow/template found for: " _ recipeId
        set pResp.ResponseJSON = ##class(FAST.Util.JSON).ToString(e, 0)
        quit $$$OK
    }

    set requestId = "req-" _ $increment(^FAST("ctr", "req"))
    set traceId = "trace-" _ $increment(^FAST("ctr", "trace"))
    set inv = ##class(FAST.Data.AgentInvocation).%New()
    set inv.RequestId = requestId, inv.RecipeId = recipeId, inv.FlowSlug = recipeId
    set inv.TriggerType = def.trigger.type, inv.PatientId = patientRef
    set inv.ContextJSON = ##class(FAST.Util.JSON).ToString(contextObj, 0)
    set inv.Status = "running", inv.TraceId = traceId
    do inv.%Save()

    // who this run is about, in integrator-friendly identifiers (name, NHS
    // number, MRN) - carried on every patient-scoped message payload so the
    // Visual Trace reads like a real hospital integration
    set pinfo = $select(patientRef '= "": ##class(FAST.Runtime.FHIRTools).PatientInfo(patientRef), 1: {})
    set whoText = ""
    if pinfo.display '= "" {
        set whoText = " for " _ pinfo.display
        if pinfo.nhsNo '= "" set whoText = whoText _ " (NHS " _ pinfo.nhsNo _ $select(pinfo.mrn '= "": ", MRN " _ pinfo.mrn, 1: "") _ ")"
    }

    set ts = "FAST.Runtime.TraceStore", step = 0
    set step = step + 1  do $classmethod(ts, "Step", traceId, step, "BusinessService", "AgentTriggerService", "ok", "Received AgentRequest for " _ recipeId _ whoText)
    set step = step + 1  do $classmethod(ts, "Step", traceId, step, "BusinessProcess", "AgentOrchestrator", "ok", "Orchestrating recipe " _ recipeId _ whoText)

    set ctx = {}
    set ctx.recipeId = recipeId, ctx.patientRef = patientRef, ctx.context = contextObj
    // per-run cache bypass: carried OUTSIDE ctx.context (context lines are
    // rendered into prompts; this flag must never shift a cache key)
    if +pReq.NoCache do ctx.%Set("noCache", 1)
    do ctx.%Set("def", def)

    // FHIR evidence
    if ##class(FAST.Util.JSON).ArrSize(def.evidence.fhir) > 0 {
        set p = {}, p.patientRef = patientRef
        if pinfo.display '= "" do p.%Set("patient", pinfo)
        do p.%Set("resourceTypes", def.evidence.fhir)
        do ..CallOp("FHIRRead", "fhirRead", p, .fhir)
        do ctx.%Set("fhir", fhir)
        set step = step + 1  do $classmethod(ts, "Step", traceId, step, "BusinessOperation", "FHIRReadOperation", "ok", "Retrieved " _ fhir.count _ " FHIR resource(s)", ..StepIO(p, fhir))
    }
    // SQL evidence
    if ##class(FAST.Util.JSON).ArrSize(def.evidence.sql) > 0 {
        set sqlres = {}, names = "", it = def.evidence.sql.%GetIterator()
        while it.%GetNext(.k, .nm) {
            set p = {}, p.name = nm, p.patientRef = patientRef
            if pinfo.display '= "" do p.%Set("patient", pinfo)
            do ..CallOp("SQLQuery", "sql", p, .one)
            do sqlres.%Set(nm, one)
            set names = names _ $select(names = "": "", 1: ", ") _ nm
        }
        do ctx.%Set("sql", sqlres)
        set sreq = {"patientRef": (patientRef)}
        if pinfo.display '= "" do sreq.%Set("patient", pinfo)
        do sreq.%Set("queries", def.evidence.sql)
        set step = step + 1  do $classmethod(ts, "Step", traceId, step, "BusinessOperation", "SQLQueryOperation", "ok", "Executed: " _ names, ..StepIO(sreq, sqlres))
    }
    // Vector evidence
    if ##class(FAST.Util.JSON).ArrSize(def.evidence.vector) > 0 {
        set vec = {}, cols = "", qtext = ##class(FAST.Runtime.Runtime).VectorQueryText(def, contextObj, patientRef), it = def.evidence.vector.%GetIterator()
        set topK = $select(+def.evidence.vectorTopK > 0: +def.evidence.vectorTopK, 1: 3)
        while it.%GetNext(.k, .col) {
            set p = {}, p.collection = col, p.queryText = qtext, p.topK = topK
            do ..CallOp("VectorSearch", "vector", p, .chunks)
            do vec.%Set(col, chunks)
            set cols = cols _ $select(cols = "": "", 1: ", ") _ col
        }
        do ctx.%Set("vector", vec)
        set vreq = {"queryText": (qtext)}  do vreq.%Set("collections", def.evidence.vector)
        set step = step + 1  do $classmethod(ts, "Step", traceId, step, "BusinessOperation", "VectorSearchOperation", "ok", "Searched: " _ cols, ..StepIO(vreq, vec))
    }

    // Reusable EvidenceSource components (by slug) — the library is live, not
    // decorative: each slug executes through the generic EvidenceEngine.
    if ##class(FAST.Util.JSON).ArrSize(def.evidence.sources) > 0 {
        set srcs = {}, names = "", it = def.evidence.sources.%GetIterator()
        while it.%GetNext(.k, .sl) {
            set facts = ##class(FAST.Runtime.EvidenceEngine).RunBySlug(sl, patientRef, contextObj)
            do srcs.%Set(sl, facts)
            set names = names _ $select(names = "": "", 1: ", ") _ sl
        }
        do ctx.%Set("sources", srcs)
        set sreq2 = {"patientRef": (patientRef)}
        if pinfo.display '= "" do sreq2.%Set("patient", pinfo)
        do sreq2.%Set("sources", def.evidence.sources)
        set step = step + 1  do $classmethod(ts, "Step", traceId, step, "BusinessProcess", "EvidenceEngine", "ok", "Ran evidence source(s): " _ names, ..StepIO(sreq2, srcs))
    }

    // Agent reasoning — the LLM call. Its full transcript (base prompt, the
    // combined completion request, and the raw response) is captured on this
    // step's payload so "Under the hood" can show exactly what was sent and returned.
    do ..CallOp("AIHub", "aihub", ctx, .resp)
    if '$isobject(resp) set resp = {}
    set aiSource = $select($isobject(resp.aiTrace) && (resp.aiTrace.source '= ""): resp.aiTrace.source, resp.source '= "": resp.source, 1: "deterministic")
    // session tier counters (cached / live / deterministic) - shown on the AI Hub page
    if $increment(^FAST("stats", "tier", $piece(aiSource, " ", 1)))
    set aiPayload = $select($isobject(resp.aiTrace): ##class(FAST.Util.JSON).ToString(resp.aiTrace, 0), 1: "")
    set step = step + 1  do $classmethod(ts, "Step", traceId, step, "BusinessProcess", "AIHubProcess", "ok", "Combined the evidence with the base prompt and called the LLM (source: " _ aiSource _ ")", aiPayload)

    // The LLM egress leg: AIHub -> LLMService travelled as a real Ens message
    // (FAST.Msg.LLMRequest/LLMResponse - also visible in the Visual Trace).
    // Surface it here too: the HTTP request shape and the truthful transport
    // outcome (cached = replayed, no network call; live = real HTTPS status).
    set tr = $select($isobject(resp.aiTrace): resp.aiTrace.%Get("transport"), 1: "")
    if $isobject(tr) {
        set treq = {}
        set treq.method = "POST"
        set treq.url = tr.url
        set treq.headers = {"Authorization": "Bearer ***masked - never logged***", "Content-Type": "application/json"}
        set treq.body = "model + system message + user message (see the AI step's transcript above for the exact text)"
        set tresp = {}
        set tresp.source = tr.source
        set tresp.httpStatus = $select(tr.httpStatus '= "": tr.httpStatus, 1: "(no network call made)")
        set tresp.note = tr.note
        set tdesc = $select(tr.source = "cached": "Outbound LLM request resolved from the bundled response corpus (no network call)",
                            $extract(tr.source, 1, 4) = "live": "Outbound HTTPS call to " _ tr.url _ " (HTTP " _ tr.httpStatus _ ")",
                            1: "Outbound LLM request - no cache entry and no key, fell back to deterministic")
        set step = step + 1  do $classmethod(ts, "Step", traceId, step, "BusinessOperation", "LLMService", "ok", tdesc, ..StepIO(treq, tresp))
    }

    // FHIR write-back (draft only)
    if ($extract(def.action.type, 1, 5) = "draft") && $isobject(resp.proposedAction) {
        set p = {}, p.invocationId = requestId, p.actionType = resp.proposedAction.actionType, p.resourceType = resp.proposedAction.resourceType
        if pinfo.display '= "" do p.%Set("patient", pinfo)
        do p.%Set("resource", resp.proposedAction.resource)
        do ..CallOp("FHIRWriteback", "writeback", p, .draft)
        set step = step + 1  do $classmethod(ts, "Step", traceId, step, "BusinessOperation", "FHIRWritebackOperation", "drafted", "Drafted " _ resp.proposedAction.resourceType _ " (requires human review)", ##class(FAST.Util.JSON).ToString(draft, 0))
    }

    do ##class(FAST.Runtime.Runtime).PersistEvidence(requestId, resp.evidence)

    set inv.Status = resp.status, inv.Summary = resp.summary
    set inv.ResponseJSON = ##class(FAST.Util.JSON).ToString(resp, 0), inv.CompletedAt = $zdatetime($ztimestamp, 3)
    do inv.%Save()

    set resp.requestId = requestId, resp.recipeId = recipeId, resp.traceId = traceId
    // the REAL Ens session id - lets the UI deep-link into the Management
    // Portal's Visual Trace for this exact run (the unfakeable artifact)
    if ..%SessionId '= "" set resp.sessionId = ..%SessionId
    set resp.trace = $classmethod(ts, "AsArray", traceId)
    set pResp.ResponseJSON = ##class(FAST.Util.JSON).ToString(resp, 0)
    set pResp.RequestId = requestId
    set pResp.TraceId = traceId
    quit $$$OK
}

/// A trace-step payload carrying BOTH the request sent to a Business Operation and
/// the response it returned, so "Under the hood" can show the full message flow.
ClassMethod StepIO(request As %DynamicObject, response As %DynamicObject) As %String
{
    set io = {}
    do io.%Set("request", request)
    do io.%Set("response", response)
    return ##class(FAST.Util.JSON).ToString(io, 0)
}

/// Send a generic op request to a Business Operation synchronously; parse its JSON result.
Method CallOp(target As %String, op As %String, payload As %DynamicObject, Output result As %DynamicObject) As %Status
{
    set req = ##class(FAST.Msg.OpRequest).%New()
    set req.Op = op
    set req.PayloadJSON = ##class(FAST.Util.JSON).ToString(payload, 0)
    set sc = ..SendRequestSync(target, req, .opResp)
    if $$$ISERR(sc) { set result = {}  quit sc }
    set result = ##class(FAST.Util.JSON).Parse(opResp.ResultJSON)
    quit $$$OK
}

/// Declare every downstream target so the production configuration diagram
/// draws the orchestrator's connections.
ClassMethod OnGetConnections(Output pArray As %String, pItem As Ens.Config.Item)
{
    do ##super(.pArray, pItem)
    set pArray("FHIRRead") = ""
    set pArray("SQLQuery") = ""
    set pArray("VectorSearch") = ""
    set pArray("AIHub") = ""
    set pArray("FHIRWriteback") = ""
}

}
