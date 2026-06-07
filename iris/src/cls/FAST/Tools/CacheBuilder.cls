/// DEV-ONLY tooling to build + export the bundled LLM response cache.
/// Run once (with a live LLM key configured) to capture real Grok responses,
/// then export to /seed/llm-cache for bundling. Never needs a key at demo time.
Class FAST.Tools.CacheBuilder [ Abstract ]
{

/// Run every template's test case through the live production so the AIHub
/// operation captures (caches) a real LLM response for each. Returns rows cached.
ClassMethod BuildAll() As %Integer
{
    set save = $get(^FAST("llm", "useCache"), 1)
    set ^FAST("llm", "useCache") = 0      // force fresh live calls during the build
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT Slug FROM FAST_Data.Template ORDER BY Slug")
    set n = 0
    while rs.%Next() {
        do ##class(FAST.Runtime.Runtime).RunTest(rs.%Get("Slug"))
        set n = n + 1
    }
    set ^FAST("llm", "useCache") = save
    write "Ran ", n, " recipes; LLMCache now has ", ..Count(), " entries.", !
    return ..Count()
}

/// Build a cached Smart Patient Summary for EVERY patient (synthetic + hero) so
/// the chart's auto-run summary shows a real AI narrative for anyone a judge
/// opens - not just demo patients. Forces live calls (needs a configured key);
/// each result is captured into the bundled cache. Runs with the SAME inputs the
/// chart sends (patient only, role from the definition default) so the demo cache
/// key matches. `limit`=0 means all patients. Returns patients processed.
ClassMethod BuildSummaries(limit As %Integer = 0) As %Integer
{
    set save = $get(^FAST("llm", "useCache"), 1)
    set ^FAST("llm", "useCache") = 0
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT ResourceId FROM HSFHIR_X0001_R.Rsrc WHERE ResourceType = 'Patient' AND Deleted = 0 ORDER BY ResourceId")
    set n = 0
    while rs.%Next() {
        set inputs = {}
        set inputs.patient = "Patient/" _ rs.%Get("ResourceId")
        do ##class(FAST.Runtime.Runtime).RunWithInputs("smart-patient-summary", inputs)
        set n = n + 1
        if (n # 50) = 0 write n, " summaries built...", !
        if limit, n >= limit quit
    }
    set ^FAST("llm", "useCache") = save
    write "Built ", n, " patient summaries; LLMCache now has ", ..Count("completion"), " completion entries.", !
    return n
}

/// With a live embedding provider configured (embedMode=external + Ollama
/// reachable), (re)build the bundled embedding cache: embed every
/// KnowledgeDocument (via EmbedAll) plus the runtime query text of every
/// template's flow (by running its test case, so non-hero vector flows are
/// covered too). All land in LLMCache (Kind="embedding") for export. Returns
/// the embedding-cache row count.
ClassMethod BuildEmbeddings() As %Integer
{
    if ##class(FAST.Runtime.Embedder).Mode() '= "external" {
        write "embedMode is not external — set ^FAST(""llm"",""embedMode"")=""external"" with Ollama up first.", !
        return 0
    }
    do ##class(FAST.Runtime.Embedder).EmbedAll()
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT Slug FROM FAST_Data.Template ORDER BY Slug")
    while rs.%Next() { do ##class(FAST.Runtime.Runtime).RunTest(rs.%Get("Slug")) }
    write "Embedding cache now has ", ..Count("embedding"), " entries.", !
    return ..Count("embedding")
}

/// Export cache rows of a given kind to a JSON file for bundling. Default path
/// is /tmp (writable by the irisowner process); copy it to the repo's
/// seed/llm-cache/ with `docker cp`. The /opt/seed tree is root-owned, so IRIS
/// can't write there. kind "" exports every row.
ClassMethod Export(path As %String = "/tmp/fast-completions.json", kind As %String = "completion") As %Integer
{
    set sql = "SELECT CacheKey, Kind, Model, PromptVersion, InputPreview, OutputJSON FROM FAST_Data.LLMCache"
    if kind '= "" set sql = sql _ " WHERE Kind = '" _ kind _ "'"
    set sql = sql _ " ORDER BY CacheKey"
    // Stream entries to the file one at a time - the full corpus exceeds the
    // IRIS maximum string length, so the array must NEVER be materialised as a
    // single string (<MAXSTRING> in ToString otherwise).
    set stream = ##class(%Stream.FileCharacter).%New()
    set stream.Filename = path
    do stream.Write("[")
    set n = 0
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, sql)
    while rs.%Next() {
        set o = {}
        set o.cacheKey = rs.%Get("CacheKey")
        set o.kind = rs.%Get("Kind")
        set o.model = rs.%Get("Model")
        set o.promptVersion = rs.%Get("PromptVersion")
        set o.inputPreview = rs.%Get("InputPreview")
        set o.outputJSON = rs.%Get("OutputJSON")
        if n > 0 do stream.Write(",")
        do stream.Write(##class(FAST.Util.JSON).ToString(o, 0))
        set n = n + 1
    }
    do stream.Write("]")
    set sc = stream.%Save()
    write "Exported ", n, " ", $select(kind = "": "", 1: kind _ " "), "cache entries to ", path, " (", $select($$$ISOK(sc):"ok",1:$system.Status.GetErrorText(sc)), ")", !
    return n
}

/// Seed a couple of overdue care-plan Tasks for the first n patients so the Care
/// Plan Navigator's "overdue tasks" section is populated. Ids are syn- prefixed
/// (cleared on reseed). Returns tasks created.
ClassMethod SeedCarePlanTasks(n As %Integer = 12) As %Integer
{
    set total = 0
    for i = 1:1:n {
        set pid = "syn-pat-" _ $extract("000" _ i, *-3, *)
        set batch = []
        do ..TaskEntry(batch, pid, "1", "Record daily blood glucose three times a day for two weeks", ##class(FAST.Seed.SyntheticData).DaysBeforeAnchor(11))
        do ..TaskEntry(batch, pid, "2", "Complete the diabetes education module", ##class(FAST.Seed.SyntheticData).DaysBeforeAnchor(21))
        set total = total + ##class(FAST.Seed.SeedLoader).PutBundle(batch)
    }
    write "Seeded ", total, " care-plan tasks across ", n, " patients.", !
    return total
}

ClassMethod TaskEntry(batch As %DynamicArray, pid As %String, suffix As %String, desc As %String, due As %String)
{
    set tid = "syn-cptask-" _ pid _ "-" _ suffix
    set t = {"resourceType": "Task", "status": "ready", "intent": "order", "priority": "routine"}
    set t.id = tid
    set t.description = desc
    set t.for = {"reference": ("Patient/" _ pid)}
    set t.authoredOn = ##class(FAST.Seed.SyntheticData).OldDate()
    set t.restriction = {"period": {"end": (due)}}
    set item = {}, item.resourceType = "Task", item.resourceId = tid
    do item.%Set("resource", t)
    do batch.%Push(item)
}

/// Seed the overdue tasks, then build the care-plan-navigator cache (live calls)
/// for the first n patients so the navigator replays keyless on the demo cohort.
ClassMethod BuildCarePlanNavigator(n As %Integer = 12) As %Integer
{
    do ..SeedCarePlanTasks(n)
    set save = $get(^FAST("llm", "useCache"), 1)
    set ^FAST("llm", "useCache") = 0
    for i = 1:1:n {
        do ##class(FAST.Runtime.Runtime).RunRecipe("care-plan-navigator", "Patient/syn-pat-" _ $extract("000" _ i, *-3, *), {})
    }
    set ^FAST("llm", "useCache") = save
    write "Built care-plan-navigator cache for ", n, " patients.", !
    return n
}

/// Convenience: export completions and embeddings to their bundle filenames.
ClassMethod ExportAll() As %Integer
{
    do ..Export("/tmp/fast-completions.json", "completion")
    do ..Export("/tmp/fast-embeddings.json", "embedding")
    return ..Count("")
}

ClassMethod Count(kind As %String = "") As %Integer
{
    set sql = "SELECT COUNT(*) c FROM FAST_Data.LLMCache"
    if kind '= "" set sql = sql _ " WHERE Kind = '" _ kind _ "'"
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, sql)
    if rs.%Next() return rs.%Get("c")
    return 0
}

}
