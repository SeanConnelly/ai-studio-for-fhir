/// Generic, safe executor for a reusable EvidenceSource component. Given an
/// EvidenceSource (by slug or spec), a patient reference, and the agent's input
/// values, it gathers real evidence — replacing the hardcoded per-recipe query
/// switch with a data-driven, mixable step. Every SQL path is guarded read-only by
/// FAST.Util.SqlGuard; FHIR/vector/terminology paths delegate to the real tools.
/// Param binding: {{patientRef}} and {{input.<key>}} placeholders in a spec are
/// substituted from the bound context before execution.
Class FAST.Runtime.EvidenceEngine [ Abstract ]
{

/// Execute an EvidenceSource by slug. Returns a facts %DynamicObject (shape
/// depends on Kind) or an { error } object. inputs is a %DynamicObject of the
/// agent's input values.
ClassMethod RunBySlug(slug As %String, patientRef As %String = "", inputs As %DynamicObject = "") As %DynamicObject
{
    set src = ##class(FAST.Data.EvidenceSource).SlugIdxOpen(slug)
    if '$isobject(src) { set e = {}, e.error = "Unknown evidence source: " _ slug  return e }
    return ..Run(src.Kind, ##class(FAST.Util.JSON).Parse(src.Spec), patientRef, inputs)
}

/// Execute a kind + spec directly. spec is a %DynamicObject (kind-specific).
ClassMethod Run(kind As %String, spec As %DynamicObject = "", patientRef As %String = "", inputs As %DynamicObject = "") As %DynamicObject
{
    if '$isobject(spec) set spec = {}
    if '$isobject(inputs) set inputs = {}
    if kind = "fhir-gather" return ..RunFhirGather(spec, patientRef)
    if kind = "everything" return ##class(FAST.Runtime.FHIRTools).Everything(patientRef)
    if kind = "sql" return ..RunSql(spec, patientRef, inputs)
    if kind = "vector" return ..RunVector(spec, patientRef, inputs)
    if kind = "terminology" return ..RunTerminology(spec, inputs)
    set e = {}, e.error = "Unknown evidence kind: " _ kind
    return e
}

/// fhir-gather: read named resource types for the patient.
/// spec = { "resourceTypes": ["Observation","Condition", ...] }
ClassMethod RunFhirGather(spec As %DynamicObject, patientRef As %String) As %DynamicObject
{
    set types = spec.resourceTypes
    if '$isobject(types) set types = []
    return ##class(FAST.Runtime.FHIRReadOperation).Gather(patientRef, types)
}

/// sql: parameterised read-only query, guarded by FAST.Util.SqlGuard, executed via
/// %SQL.Statement. spec = { "sql": "SELECT ... WHERE patient = {{patientRef}}", ... }
/// Placeholders are substituted (and SQL-escaped) before the read-only check.
ClassMethod RunSql(spec As %DynamicObject, patientRef As %String, inputs As %DynamicObject) As %DynamicObject
{
    set o = {}, o.kind = "sql", o.rows = []
    set sql = ..Substitute(spec.sql, patientRef, inputs)
    set o.sql = sql
    if (sql = "") || '##class(FAST.Util.SqlGuard).IsReadOnly(sql) {
        set o.validationStatus = "rejected"
        set o.error = "Evidence SQL was not a single safe read-only SELECT."
        return o
    }
    set o.validationStatus = "approved"
    set st = ##class(%SQL.Statement).%New()
    set sc = st.%Prepare(sql)
    if $$$ISERR(sc) { set o.error = "prepare failed: " _ $zstrip($system.Status.GetErrorText(sc), "<>W")  return o }
    set rs = st.%Execute()
    if rs.%SQLCODE < 0 { set o.error = "SQLCODE " _ rs.%SQLCODE _ ": " _ rs.%Message  return o }
    set md = rs.%GetMetadata(), cols = md.columns, n = 0
    while rs.%Next() {
        set n = n + 1  if n > 100 quit
        set row = {}
        for i = 1:1:cols.Count() {
            set c = cols.GetAt(i)
            do row.%Set(c.colName, ##class(FAST.Util.SqlGuard).CleanCell(rs.%GetData(i)))
        }
        do o.rows.%Push(row)
    }
    set o.matchCount = o.rows.%Size()
    return o
}

/// vector: native IRIS Vector Search over a KnowledgeDocument collection.
/// spec = { "collection": "payer_policies", "queryFrom": "input.question", "topK": 5 }
ClassMethod RunVector(spec As %DynamicObject, patientRef As %String, inputs As %DynamicObject) As %DynamicObject
{
    set o = {}, o.kind = "vector"
    set col = spec.collection
    set topK = $select(spec.topK '= "": +spec.topK, 1: 3)
    set qtext = ..Resolve(spec.queryFrom, patientRef, inputs)
    if qtext = "" set qtext = spec.queryText
    set o.collection = col, o.queryText = qtext
    set o.chunks = ##class(FAST.Runtime.VectorSearchOperation).Search(col, qtext, topK)
    return o
}

/// terminology: resolve clinical text to coded concepts.
/// spec = { "textFrom": "input.term", "system": "SNOMED" }
ClassMethod RunTerminology(spec As %DynamicObject, inputs As %DynamicObject) As %DynamicObject
{
    set text = ..Resolve(spec.textFrom, "", inputs)
    if text = "" set text = spec.text
    return ##class(FAST.Runtime.FHIRTools).TerminologyResolve(text, spec.system)
}

/// Resolve a "source path" to a value: "input.<key>" → inputs.<key>, "patientRef"
/// → patientRef, anything else → the literal string.
ClassMethod Resolve(path As %String, patientRef As %String, inputs As %DynamicObject) As %String
{
    if path = "" return ""
    if path = "patientRef" return patientRef
    if $extract(path, 1, 6) = "input." {
        set key = $extract(path, 7, *)
        if $isobject(inputs) && inputs.%IsDefined(key) return inputs.%Get(key)
        return ""
    }
    return path
}

/// Substitute {{patientRef}} and {{input.<key>}} placeholders in a template string.
/// Values are escaped for safe single-quoted SQL literal use.
ClassMethod Substitute(tmpl As %String, patientRef As %String, inputs As %DynamicObject) As %String
{
    if tmpl = "" return ""
    set tmpl = $replace(tmpl, "{{patientRef}}", ..SqlEscape(patientRef))
    // replace any {{input.key}} occurrences
    for  {
        set s = $find(tmpl, "{{input.")
        if s = 0 quit
        set e = $find(tmpl, "}}", s)
        if e = 0 quit
        set key = $extract(tmpl, s, e - 3)
        set val = $select($isobject(inputs) && inputs.%IsDefined(key): inputs.%Get(key), 1: "")
        set tmpl = $extract(tmpl, 1, s - 9) _ ..SqlEscape(val) _ $extract(tmpl, e, *)
    }
    return tmpl
}

/// Escape a value for use inside a single-quoted SQL literal (double up quotes,
/// strip control chars). The SqlGuard read-only check is still applied afterwards.
ClassMethod SqlEscape(v As %String) As %String
{
    return $replace($zstrip(v, "*C"), "'", "''")
}

}
