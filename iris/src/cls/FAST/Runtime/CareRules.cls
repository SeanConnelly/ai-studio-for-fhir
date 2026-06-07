/// Preventative-care rules: AI-authored cohort queries over the real FHIR
/// repository, saved and then run on demand from the clinical worklist.
///
/// Authoring (Studio): a plain-English description -> the LLM writes a single
/// read-only SQL SELECT over the IRIS for Health FHIR SQL projections (the same
/// engine as the NL->FHIR hero), returning PatientRef / Patient / Detail columns.
/// The SQL is validated read-only and saved on the rule.
///
/// Running (clinical worklist): the saved SQL is validated again and executed
/// live, returning the matching patients. Nothing is persisted per run.
///
/// Resolution for SQL authoring is the usual three tiers: bundled cache (keyless
/// demo) -> live LLM (BYO key) -> a deterministic fallback query.
Class FAST.Runtime.CareRules [ Abstract ]
{

/// Build a slug from a name.
ClassMethod Slugify(name As %String) As %String
{
    set s = $zconvert($zstrip(name, "<>W"), "L")
    set out = ""
    for i = 1:1:$length(s) {
        set c = $extract(s, i)
        if c?1(1A,1N) { set out = out _ c }
        elseif (c = " ") || (c = "-") || (c = "_") { set out = out _ "-" }
    }
    set out = $zstrip(out, "<>", "-")
    if out = "" set out = "rule-" _ $zcrc(name, 7)
    return out
}

/// List all saved rules as a JSON array (no SQL body, plus a live match count is
/// NOT computed here to keep the list fast).
ClassMethod ListJSON() As %DynamicArray
{
    set arr = []
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT Slug, Name, Description, Explanation, Source, IsSystem, SQL FROM FAST_Data.CareRule ORDER BY IsSystem DESC, CreatedAt")
    while rs.%Next() {
        set o = {}
        set o.slug = rs.%Get("Slug")
        set o.name = rs.%Get("Name")
        set o.description = rs.%Get("Description")
        set o.explanation = rs.%Get("Explanation")
        set o.source = rs.%Get("Source")
        set o.isSystem = (rs.%Get("IsSystem") = 1)
        set o.sql = rs.%Get("SQL")
        do arr.%Push(o)
    }
    return arr
}

/// Author a rule from a name + plain-English description: generate the SQL with
/// the LLM, validate read-only, save it, and return the rule + a sample run.
ClassMethod Create(name As %String, description As %String) As %DynamicObject
{
    if $zstrip(description, "<>W") = "" { set e = {}, e.ok = 0, e.error = "A description is required."  return e }
    if $zstrip(name, "<>W") = "" set name = $extract(description, 1, 60)
    set gen = ..GenerateSQL(description)
    if 'gen.ok { return gen }

    set slug = ..Slugify(name), base = slug, n = 1
    while $isobject(##class(FAST.Data.CareRule).SlugIdxOpen(slug)) { set n = n + 1, slug = base _ "-" _ n }
    set r = ##class(FAST.Data.CareRule).%New()
    set r.Slug = slug, r.Name = name, r.Description = description
    set r.SQL = gen.sql, r.Explanation = gen.explanation, r.Source = gen.source
    set sc = r.%Save()
    if $$$ISERR(sc) { set e = {}, e.ok = 0, e.error = $system.Status.GetErrorText(sc)  return e }

    set out = {}
    set out.ok = 1
    set out.slug = slug
    set out.name = name
    set out.description = description
    set out.sql = gen.sql
    set out.explanation = gen.explanation
    set out.source = gen.source
    set out.sample = ..Execute(gen.sql, 5)
    return out
}

/// Seed a system example rule (used by the seeder). Generates + saves if absent.
ClassMethod SeedRule(slug As %String, name As %String, description As %String) As %Status
{
    if $isobject(##class(FAST.Data.CareRule).SlugIdxOpen(slug)) return $$$OK
    set gen = ..GenerateSQL(description)
    set r = ##class(FAST.Data.CareRule).%New()
    set r.Slug = slug, r.Name = name, r.Description = description, r.IsSystem = 1
    set r.SQL = gen.sql, r.Explanation = gen.explanation, r.Source = gen.source
    return r.%Save()
}

/// Run a saved rule: validate read-only and execute its SQL live, returning the
/// matching patients. { ok, slug, name, count, patients:[{ref,name,detail}] }.
ClassMethod Run(slug As %String) As %DynamicObject
{
    set r = ##class(FAST.Data.CareRule).SlugIdxOpen(slug)
    if '$isobject(r) { set e = {}, e.ok = 0, e.error = "Rule not found: " _ slug  return e }
    set res = ..Execute(r.SQL, 200)
    set res.slug = slug
    set res.name = r.Name
    set res.description = r.Description
    return res
}

/// The persisted worklist entries for a rule (the table shown on the worklist).
/// { ok, slug, name, count, entries:[{ref,id,name,detail}] }.
ClassMethod WorklistEntries(slug As %String) As %DynamicObject
{
    set out = {}, arr = [], out.slug = slug
    set r = ##class(FAST.Data.CareRule).SlugIdxOpen(slug)
    set out.name = $select($isobject(r): r.Name, 1: slug)
    set out.description = $select($isobject(r): r.Description, 1: "")
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT PatientRef, PatientName, Detail FROM FAST_Data.WorklistEntry WHERE RuleSlug = ? ORDER BY AddedAt, ID", slug)
    while rs.%Next() {
        set e = {}
        set e.ref = rs.%Get("PatientRef")
        set e.id = $piece(e.ref, "/", *)
        set e.name = rs.%Get("PatientName")
        set e.detail = rs.%Get("Detail")
        do arr.%Push(e)
    }
    set out.ok = 1, out.entries = arr, out.count = arr.%Size()
    return out
}

/// Add a patient to a rule's worklist if not already present. Returns 1 if added.
ClassMethod AddEntry(slug As %String, ref As %String, name As %String, detail As %String) As %Boolean
{
    if (ref = "") || $isobject(##class(FAST.Data.WorklistEntry).RulePatientIdxOpen(slug, ref)) return 0
    set e = ##class(FAST.Data.WorklistEntry).%New()
    set e.RuleSlug = slug, e.PatientRef = ref, e.PatientName = name, e.Detail = detail
    do e.%Save()
    return 1
}

/// Count current entries for a rule.
ClassMethod EntryCount(slug As %String) As %Integer
{
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT COUNT(*) c FROM FAST_Data.WorklistEntry WHERE RuleSlug = ?", slug)
    if rs.%Next() return rs.%Get("c")
    return 0
}

/// Run the rule and append newly-matching patients to its worklist (up to `cap`
/// total). Returns the refreshed worklist plus how many were added this run.
ClassMethod UpdateWorklist(slug As %String, cap As %Integer = 25) As %DynamicObject
{
    set r = ##class(FAST.Data.CareRule).SlugIdxOpen(slug)
    if '$isobject(r) { set e = {}, e.ok = 0, e.error = "Rule not found: " _ slug  return e }
    set res = ..Execute(r.SQL, 500)
    set have = ..EntryCount(slug), added = 0
    if $isobject(res.patients) {
        set it = res.patients.%GetIterator()
        while it.%GetNext(.k, .p) {
            if (have + added) >= cap quit
            if ..AddEntry(slug, p.ref, p.name, p.detail) set added = added + 1
        }
    }
    set out = ..WorklistEntries(slug)
    set out.added = added
    return out
}

/// Seed a few default entries for a rule (so the worklist isn't empty on open).
/// No-op if the worklist already has entries.
ClassMethod SeedWorklistDefaults(slug As %String, n As %Integer = 4) As %Integer
{
    if ..EntryCount(slug) > 0 return 0
    set r = ##class(FAST.Data.CareRule).SlugIdxOpen(slug)
    if '$isobject(r) return 0
    set res = ..Execute(r.SQL, n * 4), added = 0
    if $isobject(res.patients) {
        set it = res.patients.%GetIterator()
        while it.%GetNext(.k, .p) {
            if added >= n quit
            if ..AddEntry(slug, p.ref, p.name, p.detail) set added = added + 1
        }
    }
    return added
}

/// Validate + execute a cohort SQL; map rows to patients. Returns
/// { ok, count, patients:[{ref,name,detail}], error? }.
ClassMethod Execute(sql As %String, max As %Integer = 200) As %DynamicObject
{
    set out = {}, patients = [], out.patients = patients, out.count = 0
    if (sql = "") || '##class(FAST.Runtime.AIHubOperation).IsReadOnly(sql) {
        set out.ok = 0, out.error = "The rule's query was not a safe read-only SELECT."
        return out
    }
    set st = ##class(%SQL.Statement).%New()
    set sc = st.%Prepare(sql)
    if $$$ISERR(sc) { set out.ok = 0, out.error = "Query could not be prepared: " _ $zstrip($system.Status.GetErrorText(sc), "<>W")  return out }
    set rs = st.%Execute()
    if rs.%SQLCODE < 0 { set out.ok = 0, out.error = "Query error (SQLCODE " _ rs.%SQLCODE _ "): " _ rs.%Message  return out }
    set md = rs.%GetMetadata(), cols = md.columns, n = 0
    while rs.%Next() {
        set n = n + 1  if n > max quit
        set ref = "", name = "", detail = ""
        for i = 1:1:cols.Count() {
            set c = cols.GetAt(i), cn = $zconvert(c.colName, "L")
            set v = rs.%GetData(i)
            if (v '= "") && '$isvalidnum(v) set v = $zstrip(v, "*C")
            if (cn = "patientref") || (cn = "key") { set ref = v }
            elseif (cn = "patient") || (cn = "name") { set name = v }
            elseif (cn = "detail") { set detail = v }
            elseif (ref = "") && ($extract(v, 1, 8) = "Patient/") { set ref = v }
            elseif (detail = "") { set detail = c.colName _ ": " _ v }
        }
        if ref = "" continue
        set p = {}, p.ref = ref, p.id = $piece(ref, "/", *), p.name = $select(name '= "": name, 1: p.id), p.detail = detail
        do patients.%Push(p)
    }
    set out.ok = 1, out.count = patients.%Size()
    return out
}

/// Delete a rule.
ClassMethod Delete(slug As %String) As %DynamicObject
{
    set r = ##class(FAST.Data.CareRule).SlugIdxOpen(slug)
    if $isobject(r) do ##class(FAST.Data.CareRule).%DeleteId(r.%Id())
    set o = {}, o.ok = 1
    return o
}

/// ---- LLM: plain-English cohort description -> read-only cohort SQL ----
ClassMethod GenerateSQL(description As %String) As %DynamicObject
{
    set ai = "FAST.Runtime.AIHubOperation"
    set sys = ..SystemPrompt()
    set user = "Cohort to define: " _ description
    set out = {}, out.ok = 0
    set sql = "", source = "deterministic", expl = ""

    set key = $classmethod(ai, "CacheKey", "care-rule", sys, user)
    // tier 1: cache
    if $classmethod(ai, "UseCache") {
        set hit = ##class(FAST.Data.LLMCache).KeyIdxOpen(key)
        if $isobject(hit) {
            set parsed = ##class(FAST.Util.JSON).Parse(hit.OutputJSON)
            if $isobject(parsed) { set sql = parsed.generatedQuery, expl = parsed.explanation, source = "cached" }
        }
    }
    // tier 2: live
    if (sql = "") && $classmethod(ai, "HasLiveKey") {
        set msgs = []
        do msgs.%Push({"role": "system", "content": (sys)})
        do msgs.%Push({"role": "user", "content": (user)})
        set sc = ##class(FAST.Runtime.LLMClient).Chat(msgs, .content, 1)
        if $$$ISOK(sc) {
            set clean = $classmethod(ai, "StripFences", content)
            set parsed = ##class(FAST.Util.JSON).Parse(clean)
            if $isobject(parsed) && (parsed.generatedQuery '= "") {
                set sql = parsed.generatedQuery, expl = parsed.explanation
                set source = "live (" _ $get(^FAST("llm", "model"), "llm") _ ")"
                do $classmethod(ai, "StoreCache", key, $get(^FAST("llm", "model")), $extract(sys _ " " _ user, 1, 1800), clean)
            }
        }
    }
    // tier 3: deterministic fallback (a valid, illustrative cohort query)
    if sql = "" {
        set sql = ..FallbackSQL()
        set expl = "Patients with type 2 diabetes whose most recent HbA1c is elevated."
        set source = "deterministic"
    }

    set out.ok = 1, out.sql = sql, out.explanation = expl, out.source = source
    return out
}

/// The cohort-SQL system prompt: the FHIR SQL schema + the required output shape.
ClassMethod SystemPrompt() As %String
{
    set nl = $char(10)
    set cutoff = $zdate($zdateh(##class(FAST.Runtime.AIHubOperation).AnchorDate(), 3) - 365, 3)
    return "You are a clinical data analyst. Write a SINGLE read-only SQL SELECT over the InterSystems IRIS for Health FHIR SQL projections that defines the requested preventative-care patient cohort." _ nl _ nl
        _ "Tables:" _ nl
        _ "- HSFHIR_X0001_S.Patient(Key, _id, family, given, gender, birthdate). Key looks like 'Patient/<id>'." _ nl
        _ "- HSFHIR_X0001_S.Condition(Key, code, clinicalStatus, patient). Condition.patient = Patient.Key. SNOMED, e.g. type 2 diabetes = 44054006, essential hypertension = 59621000, chronic kidney disease = 709044004." _ nl
        _ "- HSFHIR_X0001_S.Observation(Key, code, patient, dateStart, status). Observation.patient = Patient.Key. LOINC, e.g. HbA1c = 4548-4, systolic BP = 8480-6, eGFR = 33914-3, LDL = 13457-7." _ nl
        _ "- HSFHIR_X0001_S_Observation.valueQuantity(Key, value, unit). Join valueQuantity.Key = Observation.Key for the numeric value." _ nl
        _ "- HSFHIR_X0001_S.Immunization(Key, vaccineCode, patient, ""date""). Immunization.patient = Patient.Key. CVX code, e.g. influenza = 158. The date-given column is named date, which is a RESERVED WORD - you MUST write it quoted as i.""date""." _ nl _ nl
        _ "Rules:" _ nl
        _ "- IMPORTANT: every coded/status column (code, clinicalStatus, status, vaccineCode) is a PACKED search token - ALWAYS match with LIKE '%value%' (e.g. code LIKE '%44054006%', vaccineCode LIKE '%158%', clinicalStatus LIKE '%active%'), NEVER with =." _ nl
        _ "- A single read-only SELECT only; never write; no second statement." _ nl
        _ "- The dataset is a frozen snapshot anchored at '" _ ##class(FAST.Runtime.AIHubOperation).AnchorDate() _ "'. 'In the last 12 months' means a date >= '" _ cutoff _ "'." _ nl
        _ "- Patient.birthdate is 'YYYY-MM-DD' text. For an age cohort compute the cut-off date from the anchor: e.g. 'aged 65 or older' is birthdate <= '1961-05-25'; 'aged 50 to 70' is birthdate between '1956-05-25' and '1976-05-25'." _ nl
        _ "- For 'overdue' / 'no X recorded' use NOT EXISTS or NOT IN against the relevant table." _ nl
        _ "- gender is stored plainly: gender = 'female' / 'male' is fine." _ nl
        _ "- Return EXACTLY these columns: PatientRef (= p.Key), Patient (= (p.given || ' ' || p.family)), Detail (a short phrase with the matching value/date). Use SELECT DISTINCT." _ nl _ nl
        _ "Respond with ONLY a JSON object: {""generatedQuery"": ""<the SQL>"", ""explanation"": ""<one sentence>""}. No markdown fences, no commentary."
}

ClassMethod FallbackSQL() As %String
{
    return "SELECT DISTINCT p.Key AS PatientRef, (p.given || ' ' || p.family) AS Patient, vq.value AS Detail" _ $char(10)
        _ "FROM HSFHIR_X0001_S.Observation o" _ $char(10)
        _ "JOIN HSFHIR_X0001_S_Observation.valueQuantity vq ON vq.Key = o.Key" _ $char(10)
        _ "JOIN HSFHIR_X0001_S.Patient p ON p.Key = o.patient" _ $char(10)
        _ "WHERE o.code LIKE '%4548-4%' AND vq.value >= 7.5" _ $char(10)
        _ "  AND o.patient IN (SELECT patient FROM HSFHIR_X0001_S.Condition WHERE code LIKE '%44054006%')"
}

}
