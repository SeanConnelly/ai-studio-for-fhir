/// Loads seed templates + demo data into IRIS persistent classes from a
/// filesystem seed root (the /seed tree, copied into the container): templates,
/// knowledge documents, the real FHIR R4 repository (hero + synthetic patients),
/// the bundled LLM response cache, and the demo LLM defaults. Finishes by
/// computing KnowledgeDocument embeddings so native Vector Search is live.
Class FAST.Seed.SeedLoader
{

Parameter VERSION = "0.1.0";

Parameter SEEDROOT = "/opt/seed";

/// Demo LLM defaults. The model MUST match the model embedded in the bundled
/// cache keys (seed/llm-cache/completions.json) or the cache will miss.
Parameter LLMMODEL = "grok-4.20-0309-non-reasoning";

Parameter LLMENDPOINT = "https://api.x.ai/v1";

/// Entry point (module.xml <Invoke> and dev). Clears system seed extents then
/// reloads, so the result is deterministic on every run.
ClassMethod Run(seedRoot As %String = {..#SEEDROOT}, clear As %Boolean = 1) As %Status
{
    set ^FAST("version") = ..#VERSION
    set ^FAST("seededAt") = $zdatetime($ztimestamp, 3)
    if clear {
        do ##class(FAST.Data.Template).%KillExtent()
        do ##class(FAST.Data.KnowledgeDocument).%KillExtent()
        do ##class(FAST.Data.TerminologyConcept).%KillExtent()
        // only system (seeded) components are cleared; user-authored ones survive
        do ..ClearSystemComponents()
    }
    set nt = ..LoadTemplates(seedRoot _ "/templates")
    set nk = ..LoadKnowledge(seedRoot _ "/demo-data/knowledge-documents.json")
    set nx = ..LoadTerminology(seedRoot _ "/demo-data/terminology.json")
    set ncomp = ..LoadComponents(seedRoot _ "/components")
    set ng = ..LoadFHIRServer(seedRoot _ "/demo-data/fhir-resources.json")
    set ns = ##class(FAST.Seed.SyntheticData).Generate(1000)
    // Load the bundled LLM cache (completions AND embeddings) BEFORE EmbedAll so
    // EmbedAll replays bundled real embeddings instead of needing a live provider.
    set nc = ..LoadLLMCacheDir(seedRoot _ "/llm-cache")
    do ..SetLLMDefaults()
    write "Seeded: ", nt, " templates, ", ncomp, " components, ", nk, " knowledge docs, ", nx, " terminology concepts, ", ng, " hero + ", ns, " synthetic FHIR resources, ", nc, " cached LLM entries.", !
    // Compute embeddings so native Vector Search is ready immediately. In external
    // mode this replays the bundled real vectors (cache hit); with no bundle and a
    // live provider it computes them; otherwise it falls back to the offline hash.
    do ##class(FAST.Runtime.Embedder).EmbedAll()
    // Demo working state that depends on the loaded cache: the 3 preventative-care
    // rules (their SQL regenerates via the bundled completions, keyless), each
    // register's starter worklist entries, and the overdue care-plan tasks the
    // Care Plan Navigator demo cohort is cached against.
    do ..SeedDemoState()
    return $$$OK
}

/// Idempotent demo working state. Each piece checks for existing data first, so
/// reseeding never duplicates and user-created rules/entries survive.
ClassMethod SeedDemoState()
{
    set cr = "FAST.Runtime.CareRules"
    do $classmethod(cr, "SeedRule", "diabetes-review", "Diabetes: HbA1c above target", "Patients with type 2 diabetes whose most recent HbA1c is 7.5% or higher")
    do $classmethod(cr, "SeedRule", "breast-screening", "Breast cancer screening due", "Women aged 50 to 70 with no breast cancer screening recorded in the last 3 years")
    do $classmethod(cr, "SeedRule", "flu-vaccination", "Annual flu vaccination due", "Patients aged 65 or older with no influenza vaccination recorded in the last 12 months")
    for slug = "diabetes-review", "breast-screening", "flu-vaccination" {
        do $classmethod(cr, "SeedWorklistDefaults", slug, 4)
    }
    // overdue care-plan tasks for the navigator demo cohort (syn-cptask-* ids are
    // cleared by every synthetic reseed, so recreate them after Generate)
    do ##class(FAST.Tools.CacheBuilder).SeedCarePlanTasks(12)
    // a starter PA queue: place + submit two orders for the flagship patient
    // (one approves, one pends) through the REAL pipeline - the PA packets
    // replay from the bundled cache, so this works keyless at boot. Idempotent:
    // skipped when any claim already exists. Requires the interoperability
    // production, which is not yet running during the IPM install - iris.script
    // calls SeedDemoState again after EnsureProduction, so the try/catch makes
    // the first (in-install) attempt harmless.
    try {
        set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 ResourceId FROM HSFHIR_X0001_R.Rsrc WHERE ResourceType = ? AND Deleted = 0", "Claim")
        if 'rs.%Next() {
            for item = "test-cgm", "med-adalimumab" {
                set placed = ##class(FAST.Runtime.Orders).Place("Patient/syn-pat-0001", item)
                if $isobject(placed) && (placed.claimId '= "") do ##class(FAST.Runtime.Orders).Submit(placed.claimId)
            }
        }
    } catch ex {
        write "PA queue seeding skipped (production not running yet): ", ex.DisplayString(), !
    }
}

/// Seed the demo LLM defaults so the bundled cache works with NO API key.
/// mode=external makes AIHub consult the cache; the model must equal the model
/// in the bundled cache keys. The demo also ships a budget-capped community key
/// (see LoadDemoKey) so cache-MISS prompts get live AI with no setup; every
/// scripted demo path still replays from the bundle for free. A judge can add
/// their own key (BYO-key) for unlimited use. Existing values are never
/// overwritten, so a deliberately configured dev/judge setup is preserved.
ClassMethod SetLLMDefaults()
{
    if $get(^FAST("llm", "mode")) = "" set ^FAST("llm", "mode") = "external"
    if $get(^FAST("llm", "model")) = "" set ^FAST("llm", "model") = ..#LLMMODEL
    if $get(^FAST("llm", "endpoint")) = "" set ^FAST("llm", "endpoint") = ..#LLMENDPOINT
    // Embeddings: external mode replays the bundled real vectors (cache hit) with
    // no provider needed; a judge can point embedEndpoint at their own Ollama for
    // live embedding of novel queries. embedModel MUST match the model in the
    // bundled embedding cache keys (seed/llm-cache/embeddings.json).
    if $get(^FAST("llm", "embedMode")) = "" set ^FAST("llm", "embedMode") = "external"
    if $get(^FAST("llm", "embedModel")) = "" set ^FAST("llm", "embedModel") = ##class(FAST.Runtime.Embedder).#EMBEDMODEL
    do ..LoadDemoKey()
}

/// Load the bundled, budget-capped community demo key into the memory-only key
/// store (IRISTEMP) so cache-MISS prompts — building a new agent, editing one,
/// custom Ask queries — get live AI with no setup. Re-runs on every boot
/// (IRISTEMP is wiped on restart), so the demo key self-restores while a
/// judge's mid-session BYO key is left untouched until the next restart.
/// Precedence: an explicit FAST_LLM_KEY environment variable wins (a host can
/// override or rotate without rebuilding); otherwise the obscured bundled blob
/// is decoded. OBSCURED, NOT SECURED — the shipped key is effectively public;
/// the real control is its hard provider-side spend cap (docs/demo-llm-key.md).
ClassMethod LoadDemoKey()
{
    // never clobber a key already in memory: a judge's BYO key (set in Admin),
    // or this same demo key loaded earlier this session. Removing the key in
    // Admin empties the store, so the next call re-arms the demo default.
    if ##class(FAST.Runtime.LLMClient).Key() '= "" quit
    set envKey = $system.Util.GetEnviron("FAST_LLM_KEY")
    if envKey '= "" { do ##class(FAST.Runtime.LLMClient).SetKey(envKey)  quit }
    set blob = ..ReadFile(..#SEEDROOT _ "/llm-key.b64")
    if blob = "" quit
    set key = ##class(FAST.Runtime.LLMClient).Deobscure(blob)
    if key '= "" do ##class(FAST.Runtime.LLMClient).SetKey(key)
}

Parameter FHIRBASE = "/fhir-agent-studio/fhir/r4";

/// Load the demo FHIR resources into the REAL IRIS FHIR R4 repository via the
/// real FHIR REST API (loopback PUT, preserving ids + references). The endpoint
/// is unauthenticated in the demo, so no credentials are needed. Returns count.
ClassMethod LoadFHIRServer(path As %String) As %Integer
{
    set content = ..ReadFile(path)
    if content = "" return 0
    set arr = ##class(%DynamicAbstractObject).%FromJSON(content)
    set count = 0, it = arr.%GetIterator()
    while it.%GetNext(.k, .item) {
        if '$isobject(item.resource) continue
        if ..PutFHIR(item.resourceType, item.resourceId, item.resource) set count = count + 1
    }
    write "Loaded ", count, " resources into the FHIR R4 repository.", !
    return count
}

/// PUT one resource into the FHIR R4 repository (loopback, preserving id). 1/0.
ClassMethod PutFHIR(resourceType As %String, id As %String, res As %DynamicObject) As %Boolean
{
    set req = ##class(%Net.HttpRequest).%New()
    set req.Server = "localhost", req.Port = 52773, req.Https = 0
    do req.SetHeader("Authorization", "Basic " _ $system.Encryption.Base64Encode("_SYSTEM:SYS"))
    do req.SetHeader("Accept", "application/fhir+json")
    set req.ContentType = "application/fhir+json"
    do res.%ToJSON(req.EntityBody)
    set sc = req.Put(..#FHIRBASE _ "/" _ resourceType _ "/" _ id)
    if $$$ISERR(sc) return 0
    return (req.HttpResponse.StatusCode = 200) || (req.HttpResponse.StatusCode = 201)
}

/// DELETE one resource from the FHIR R4 repository (loopback). 1/0.
ClassMethod DeleteFHIR(resourceType As %String, id As %String) As %Boolean
{
    set req = ##class(%Net.HttpRequest).%New()
    set req.Server = "localhost", req.Port = 52773, req.Https = 0
    do req.SetHeader("Authorization", "Basic " _ $system.Encryption.Base64Encode("_SYSTEM:SYS"))
    do req.SetHeader("Accept", "application/fhir+json")
    set sc = req.Delete(..#FHIRBASE _ "/" _ resourceType _ "/" _ id)
    if $$$ISERR(sc) return 0
    return (req.HttpResponse.StatusCode = 200) || (req.HttpResponse.StatusCode = 204)
}

/// DELETE many resources in one FHIR batch Bundle (loopback). `refs` is a
/// %DynamicArray of "ResourceType/id" strings. Far fewer round-trips than
/// per-resource DeleteFHIR - used to clear the synthetic population fast.
/// Returns the number of 2xx entries.
ClassMethod DeleteBundle(refs As %DynamicArray) As %Integer
{
    if '$isobject(refs) || (refs.%Size() = 0) return 0
    set bundle = {"resourceType": "Bundle", "type": "batch"}
    set bundle.entry = []
    set it = refs.%GetIterator()
    while it.%GetNext(.k, .url) {
        set e = {}
        set e.request = {"method": "DELETE"}
        set e.request.url = url
        do bundle.entry.%Push(e)
    }
    set req = ##class(%Net.HttpRequest).%New()
    set req.Server = "localhost", req.Port = 52773, req.Https = 0
    do req.SetHeader("Authorization", "Basic " _ $system.Encryption.Base64Encode("_SYSTEM:SYS"))
    do req.SetHeader("Accept", "application/fhir+json")
    set req.ContentType = "application/fhir+json"
    do bundle.%ToJSON(req.EntityBody)
    set sc = req.Post(..#FHIRBASE)
    if $$$ISERR(sc) return 0
    set ok = 0
    try {
        set resp = ##class(%DynamicAbstractObject).%FromJSON(req.HttpResponse.Data)
        if $isobject(resp.entry) {
            set j = resp.entry.%GetIterator()
            while j.%GetNext(.kk, .re) {
                set st = $select($isobject(re.response): re.response.status, 1: "")
                if ($extract(st, 1, 1) = "2") set ok = ok + 1
            }
        }
    } catch { set ok = refs.%Size() }
    return ok
}

/// PUT many resources in one FHIR batch Bundle (loopback), preserving ids. Far
/// fewer HTTP round-trips than per-resource PutFHIR — used to seed the large
/// synthetic population quickly. `entries` is a %DynamicArray of
/// { resourceType, resourceId, resource }. Returns the number of 200/201 entries.
ClassMethod PutBundle(entries As %DynamicArray) As %Integer
{
    if '$isobject(entries) || (entries.%Size() = 0) return 0
    set bundle = {"resourceType": "Bundle", "type": "batch"}
    set bundle.entry = []
    set it = entries.%GetIterator()
    while it.%GetNext(.k, .item) {
        if '$isobject(item.resource) continue
        set e = {}
        do e.%Set("resource", item.resource)
        set e.request = {"method": "PUT"}
        set e.request.url = item.resourceType _ "/" _ item.resourceId
        do bundle.entry.%Push(e)
    }
    set req = ##class(%Net.HttpRequest).%New()
    set req.Server = "localhost", req.Port = 52773, req.Https = 0
    do req.SetHeader("Authorization", "Basic " _ $system.Encryption.Base64Encode("_SYSTEM:SYS"))
    do req.SetHeader("Accept", "application/fhir+json")
    set req.ContentType = "application/fhir+json"
    do bundle.%ToJSON(req.EntityBody)
    set sc = req.Post(..#FHIRBASE)
    if $$$ISERR(sc) return 0
    if (req.HttpResponse.StatusCode '= 200) && (req.HttpResponse.StatusCode '= 201) return 0
    // count successful entries in the response bundle
    set ok = 0
    try {
        set resp = ##class(%DynamicAbstractObject).%FromJSON(req.HttpResponse.Data)
        if $isobject(resp.entry) {
            set j = resp.entry.%GetIterator()
            while j.%GetNext(.kk, .re) {
                set st = $select($isobject(re.response): re.response.status, 1: "")
                if ($extract(st, 1, 1) = "2") set ok = ok + 1
            }
        }
    } catch { set ok = entries.%Size() }
    return ok
}

/// POST one resource into the FHIR R4 repository (loopback, server-assigned id).
/// Returns the created reference "<resourceType>/<id>" on success, else "".
ClassMethod PostFHIR(resourceType As %String, res As %DynamicObject) As %String
{
    set req = ##class(%Net.HttpRequest).%New()
    set req.Server = "localhost", req.Port = 52773, req.Https = 0
    do req.SetHeader("Authorization", "Basic " _ $system.Encryption.Base64Encode("_SYSTEM:SYS"))
    do req.SetHeader("Accept", "application/fhir+json")
    set req.ContentType = "application/fhir+json"
    do res.%ToJSON(req.EntityBody)
    set sc = req.Post(..#FHIRBASE _ "/" _ resourceType)
    if $$$ISERR(sc) return ""
    if (req.HttpResponse.StatusCode '= 200) && (req.HttpResponse.StatusCode '= 201) return ""
    // prefer the id from the returned resource body; fall back to the Location header
    try {
        set body = ##class(%DynamicAbstractObject).%FromJSON(req.HttpResponse.Data)
        if $isobject(body) && (body.id '= "") return resourceType _ "/" _ body.id
    } catch {}
    set loc = req.HttpResponse.GetHeader("LOCATION")
    if loc '= "" {
        set id = $piece($piece(loc, "/_history", 1), "/", *)
        if id '= "" return resourceType _ "/" _ id
    }
    return resourceType _ "/?"
}

/// Delete seeded (IsSystem) reusable components, leaving user-authored ones intact.
ClassMethod ClearSystemComponents()
{
    set classes = $listbuild("FAST.Data.Prompt", "FAST.Data.EvidenceSource", "FAST.Data.ActionTemplate", "FAST.Data.OutputSchema")
    set ptr = 0
    while $listnext(classes, ptr, cls) {
        set table = "FAST_Data." _ $piece(cls, ".", *)
        do ##class(%SQL.Statement).%New().%ExecDirect(.s, "DELETE FROM " _ table _ " WHERE IsSystem = 1")
    }
}

/// Load the seeded reusable-component library (evidence sources / output
/// schemas) into IRIS. Returns the total upserted. Prompt and ActionTemplate
/// seeds were retired with the step builder: an agent's prompt is assembled at
/// run time from its definition (previewable in the builder), and its action is
/// inline on the definition — so there is nothing separate to seed. The purge
/// in ClearSystemComponents still removes any stale seeded rows on reseed.
ClassMethod LoadComponents(dir As %String) As %Integer
{
    set total = 0
    set total = total + ..LoadComponentFile(dir _ "/evidence-sources.json", "FAST.Data.EvidenceSource")
    set total = total + ..LoadComponentFile(dir _ "/output-schemas.json", "FAST.Data.OutputSchema")
    return total
}

/// Load one component JSON array into its persistent class (camelCase %JSONImport).
ClassMethod LoadComponentFile(path As %String, cls As %String) As %Integer
{
    set content = ..ReadFile(path)
    if content = "" return 0
    set arr = ##class(%DynamicAbstractObject).%FromJSON(content)
    set count = 0, it = arr.%GetIterator()
    while it.%GetNext(.k, .item) {
        if item.slug = "" continue
        set obj = $classmethod(cls, "SlugIdxOpen", item.slug)
        if '$isobject(obj) set obj = $classmethod(cls, "%New")
        set sc = obj.%JSONImport(item)
        if $$$ISERR(sc) continue
        set obj.Slug = item.slug
        set obj.IsSystem = 1
        if $$$ISOK(obj.%Save()) set count = count + 1
    }
    return count
}

/// Load seeded terminology concepts (clinical text → coded concept). Returns count.
ClassMethod LoadTerminology(path As %String) As %Integer
{
    set content = ..ReadFile(path)
    if content = "" return 0
    set arr = ##class(%DynamicAbstractObject).%FromJSON(content)
    set count = 0, it = arr.%GetIterator()
    while it.%GetNext(.k, .item) {
        if (item.searchText = "") || (item.code = "") continue
        set c = ##class(FAST.Data.TerminologyConcept).%New()
        set c.SearchText = $zconvert(item.searchText, "L")
        set c.System = item.system
        set c.Code = item.code
        set c.Display = item.display
        if $$$ISOK(c.%Save()) set count = count + 1
    }
    return count
}

/// Load every *.json bundle in the llm-cache dir (completions.json,
/// embeddings.json, …). Returns total rows upserted.
ClassMethod LoadLLMCacheDir(dir As %String) As %Integer
{
    set total = 0
    set rs = ##class(%ResultSet).%New("%File:FileSet")
    do rs.Execute(dir, "*.json")
    while rs.Next() { set total = total + ..LoadLLMCache(rs.Get("Name")) }
    return total
}

/// Load bundled real LLM responses / embeddings into the cache (so the demo
/// serves real Grok output and real vectors with no key). Upserts by cache key.
ClassMethod LoadLLMCache(path As %String) As %Integer
{
    // parse straight from the file stream - the full-cohort bundle exceeds the
    // IRIS maximum string length, so it must never pass through a string
    set stream = ##class(%Stream.FileCharacter).%New()
    if $$$ISERR(stream.LinkToFile(path)) return 0
    if stream.Size = 0 return 0
    set arr = ##class(%DynamicAbstractObject).%FromJSON(stream)
    set count = 0, it = arr.%GetIterator()
    while it.%GetNext(.k, .item) {
        if item.cacheKey = "" continue
        set c = ##class(FAST.Data.LLMCache).KeyIdxOpen(item.cacheKey)
        if '$isobject(c) {
            set c = ##class(FAST.Data.LLMCache).%New()
            set c.CacheKey = item.cacheKey
        }
        set c.Kind = item.kind
        set c.Model = item.model
        set c.PromptVersion = item.promptVersion
        set c.InputPreview = item.inputPreview
        set c.OutputJSON = item.outputJSON
        if $$$ISOK(c.%Save()) set count = count + 1
    }
    return count
}

ClassMethod LoadTemplates(dir As %String) As %Integer
{
    set count = 0
    set rs = ##class(%ResultSet).%New("%File:FileSet")
    do rs.Execute(dir, "*.json")
    while rs.Next() {
        set path = rs.Get("Name")
        set content = ..ReadFile(path)
        if content = "" continue
        set obj = ##class(%DynamicAbstractObject).%FromJSON(content)
        set slug = obj.id
        if slug = "" continue
        set tpl = ##class(FAST.Data.Template).SlugIdxOpen(slug)
        if '$isobject(tpl) {
            set tpl = ##class(FAST.Data.Template).%New()
            set tpl.Slug = slug
        }
        set tpl.Name = obj.name
        set tpl.Category = obj.category
        set tpl.Description = obj.description
        if obj.%IsDefined("version") set tpl.Version = obj.version
        set tpl.DefinitionJSON = content
        set tpl.IsSystemTemplate = 1
        set tpl.UpdatedAt = $zdatetime($ztimestamp, 3)
        if $$$ISOK(tpl.%Save()) set count = count + 1
    }
    return count
}

ClassMethod LoadKnowledge(path As %String) As %Integer
{
    set count = 0
    set content = ..ReadFile(path)
    if content = "" return 0
    set arr = ##class(%DynamicAbstractObject).%FromJSON(content)
    set it = arr.%GetIterator()
    while it.%GetNext(.k, .item) {
        set col = item.collection, did = item.documentId
        if (col = "") || (did = "") continue
        set doc = ##class(FAST.Data.KnowledgeDocument).DocIdxOpen(col, did)
        if '$isobject(doc) {
            set doc = ##class(FAST.Data.KnowledgeDocument).%New()
            set doc.Collection = col
            set doc.DocumentId = did
        }
        set doc.Title = item.title
        set doc.ChunkText = item.chunkText
        if item.%IsDefined("metadata") set doc.MetadataJSON = ..Stringify(item.metadata)
        set doc.EmbeddingDim = 0
        // Phase 2 (post-provider): compute embedding and store via
        // INSERT/UPDATE ... TO_VECTOR(<csv>, double, <dim>); set EmbeddingDim.
        if $$$ISOK(doc.%Save()) set count = count + 1
    }
    return count
}

/// Read an entire text file into a string ("" on failure).
ClassMethod ReadFile(path As %String) As %String
{
    set stream = ##class(%Stream.FileCharacter).%New()
    if $$$ISERR(stream.LinkToFile(path)) return ""
    set content = ""
    while 'stream.AtEnd { set content = content _ stream.Read(32000) }
    return content
}

/// Serialise a dynamic object/array to a JSON string.
ClassMethod Stringify(obj As %DynamicAbstractObject) As %String
{
    if '$isobject(obj) return ""
    set tmp = ##class(%Stream.GlobalCharacter).%New()
    do obj.%ToJSON(tmp)
    do tmp.Rewind()
    set s = ""
    while 'tmp.AtEnd { set s = s _ tmp.Read(32000) }
    return s
}

}
