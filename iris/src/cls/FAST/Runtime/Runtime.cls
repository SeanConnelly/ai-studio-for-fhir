Include Ensemble

/// Entry point to the real IRIS Interoperability Production. The REST layer
/// calls RunRecipe, which drives FAST.Production via Ens.Director: a real
/// AgentRequest flows through the AgentTriggerService (BS) → AgentOrchestrator
/// (BP) → the Business Operations, and the assembled AgentResponse comes back.
/// Orchestration, trace, evidence and invocation persistence all happen inside
/// the production (FAST.BP.AgentOrchestrator) — this class just drives it.
Class FAST.Runtime.Runtime [ Abstract ]
{

Parameter PRODUCTION = "FAST.Production";

/// Run a recipe for a patient + request context, through the production.
ClassMethod RunRecipe(recipeId As %String, patientRef As %String = "", contextObj As %DynamicObject = "", noCache As %Boolean = 0) As %DynamicObject
{
    do ..EnsureProduction()
    if '$isobject(contextObj) set contextObj = {}
    set req = ##class(FAST.Msg.AgentRequest).%New()
    set req.RecipeId = recipeId
    set req.PatientRef = patientRef
    set req.ContextJSON = ##class(FAST.Util.JSON).ToString(contextObj, 0)
    set req.NoCache = +noCache
    set sc = ##class(Ens.Director).CreateBusinessService("AgentTriggerService", .svc)
    if $$$ISERR(sc) { set e = {}, e.error = "service: " _ $system.Status.GetErrorText(sc)  return e }
    set sc = svc.ProcessInput(req, .resp)
    if $$$ISERR(sc) { set e = {}, e.error = "production: " _ $system.Status.GetErrorText(sc)  return e }
    if '$isobject(resp) { set e = {}, e.error = "no response from production"  return e }
    return ##class(FAST.Util.JSON).Parse(resp.ResponseJSON)
}

/// Ensure FAST.Production is the running production.
ClassMethod EnsureProduction() As %Status
{
    // Re-arm the bundled demo key (no-op if a key is already in memory). The
    // build sets it, but IRISTEMP is wiped on every restart - including the one
    // between image build and container start - so it MUST be reloaded at
    // runtime. EnsureProduction runs at the top of every recipe run, so the key
    // is always present before the first AIHub/LLMService call. Cheap: one
    // global read when a key is already loaded.
    do ##class(FAST.Seed.SeedLoader).LoadDemoKey()
    set tName = "", tState = ""
    do ##class(Ens.Director).GetProductionStatus(.tName, .tState)
    if (tName = ..#PRODUCTION) && (tState = $$$eProductionStateRunning) return $$$OK
    if (tName '= "") && (tName '= ..#PRODUCTION) do ##class(Ens.Director).StopProduction()
    return ##class(Ens.Director).StartProduction(..#PRODUCTION)
}

/// Run a recipe using its definition's testCase.
ClassMethod RunTest(recipeId As %String) As %DynamicObject
{
    set def = ..LoadDef(recipeId)
    if '$isobject(def) { set e = {}, e.error = "Not found: " _ recipeId  return e }
    set patientRef = "", contextObj = {}
    if $isobject(def.testCase) {
        set patientRef = def.testCase.patientId
        if $isobject(def.testCase.context) set contextObj = def.testCase.context
    }
    return ..RunRecipe(recipeId, patientRef, contextObj)
}

/// Run a recipe from a map of input values keyed by input key (what the studio
/// Run panel submits). Uses the definition's `inputs` to split the patient
/// input from the rest (which become the request context). Missing values fall
/// back to each input's declared `default`, so a default-prefilled run
/// reproduces the legacy testCase byte-for-byte (and the LLM cache still hits).
ClassMethod RunWithInputs(recipeId As %String, inputsObj As %DynamicObject = "", noCache As %Boolean = 0) As %DynamicObject
{
    set def = ..LoadDef(recipeId)
    if '$isobject(def) { set e = {}, e.error = "Not found: " _ recipeId  return e }
    if '$isobject(inputsObj) set inputsObj = {}
    set patientRef = "", context = {}
    if $isobject(def.inputs) && (def.inputs.%Size() > 0) {
        set it = def.inputs.%GetIterator()
        while it.%GetNext(.k, .inp) {
            set key = inp.key
            if (key = "") continue
            set val = $select(inputsObj.%IsDefined(key): inputsObj.%Get(key), 1: inp.default)
            if inp.type = "patient" {
                set patientRef = val
            } else {
                do context.%Set(key, val)
            }
        }
    } else {
        // No declared inputs: treat the object as context; pull a patient if present.
        set patientRef = $select(inputsObj.%IsDefined("patient"): inputsObj.patient, 1: "")
        set context = inputsObj
    }
    return ..RunRecipe(recipeId, patientRef, context, noCache)
}

/// Register a compiled flow's recipe.json as a DeployedRecipe.
ClassMethod Deploy(flowSlug As %String) As %Status
{
    set art = ##class(FAST.Data.CompiledArtifact).FlowArtifactIdxOpen(flowSlug, "recipe.json")
    if '$isobject(art) return $$$ERROR($$$GeneralError, "compile the flow first")
    set dr = ##class(FAST.Data.DeployedRecipe).RecipeIdxOpen(flowSlug)
    if '$isobject(dr) {
        set dr = ##class(FAST.Data.DeployedRecipe).%New()
        set dr.RecipeId = flowSlug
        set dr.FlowSlug = flowSlug
    }
    set dr.RecipeJSON = art.Content
    set dr.IsActive = 1
    set dr.DeployedAt = $zdatetime($ztimestamp, 3)
    set sc = dr.%Save()
    set flow = ##class(FAST.Data.FlowDefinition).SlugIdxOpen(flowSlug)
    if $isobject(flow) { set flow.Status = "deployed"  do flow.%Save() }
    return sc
}

// ---- helpers used by FAST.BP.AgentOrchestrator ----

ClassMethod LoadDef(recipeId As %String) As %DynamicObject
{
    set flow = ##class(FAST.Data.FlowDefinition).SlugIdxOpen(recipeId)
    if $isobject(flow) return ##class(FAST.Util.JSON).Parse(flow.DefinitionJSON)
    set tpl = ##class(FAST.Data.Template).SlugIdxOpen(recipeId)
    if $isobject(tpl) return ##class(FAST.Util.JSON).Parse(tpl.DefinitionJSON)
    return ""
}

ClassMethod VectorQueryText(def As %DynamicObject, contextObj As %DynamicObject, patientRef As %String = "") As %String
{
    set q = ""
    if $isobject(contextObj) {
        if contextObj.requestedService '= "" {
            set q = contextObj.requestedService
        } elseif contextObj.question '= "" {
            set q = contextObj.question
        }
    }
    // Screening-driven retrieval: the patient's own positive screening answers
    // become the semantic query, so each patient retrieves resources matched to
    // what THEY reported (e.g. "skipping meals" -> a subsidised meal-box service).
    if $isobject(def.evidence) && (def.evidence.vectorQueryFrom = "social-screening") && (patientRef '= "") {
        set sq = ..ScreeningQueryText(patientRef)
        if sq '= "" return sq
    }
    // Profile-driven retrieval (trial matching): the patient's age/sex, active
    // problems, medications and key results form the query, so each patient
    // retrieves the trials that fit THEIR profile.
    if $isobject(def.evidence) && (def.evidence.vectorQueryFrom = "patient-profile") && (patientRef '= "") {
        set pq = ..ProfileQueryText(patientRef)
        if pq '= "" return pq
    }
    // Abnormal-results retrieval (lab explainer): the patient's flagged results
    // form the query, so the education extracts match THEIR abnormal tests.
    if $isobject(def.evidence) && (def.evidence.vectorQueryFrom = "abnormal-results") && (patientRef '= "") {
        set aq = ..AbnormalResultsQueryText(patientRef)
        if aq '= "" return aq
    }
    return $zstrip(q _ " " _ def.description, "<>W")
}

/// Build vector-query text from the patient's FLAGGED observations (their
/// abnormal results), so patient-education retrieval matches what actually
/// needs explaining for this patient.
ClassMethod AbnormalResultsQueryText(patientRef As %String) As %String
{
    set read = "FAST.Runtime.FHIRReadOperation", q = ""
    set ol = $classmethod(read, "ResourcesForPatient", patientRef, "Observation"), it = ol.%GetIterator()
    while it.%GetNext(.k, .o) {
        set res = o.resource
        set flag = $classmethod(read, "Interp", res)
        if flag = "" continue
        set t = $classmethod(read, "CodeText", res.code)
        if (t '= "") && (q '[ t) {
            set v = $select($isobject(res.valueQuantity): " " _ res.valueQuantity.value _ " " _ res.valueQuantity.unit, 1: "")
            set q = q _ $select(q = "": "", 1: "; ") _ t _ v _ " (" _ $select(flag [ "H": "high", 1: "low") _ ")"
        }
    }
    return q
}

/// Build vector-query text from the patient's clinical profile: demographics,
/// active conditions, active medications, and the latest value of a few key
/// results. Ages use the fixed cohort anchor date so the text (and therefore
/// the LLM cache keys) never drift with the wall clock.
ClassMethod ProfileQueryText(patientRef As %String) As %String
{
    set read = "FAST.Runtime.FHIRReadOperation", q = ""
    // demographics
    set pl = $classmethod(read, "ResourcesForPatient", patientRef, "Patient")
    if pl.%Size() > 0 {
        set pres = pl.%Get(0).resource
        set anchor = ##class(FAST.Seed.SyntheticData).#ANCHORDATE
        set age = ""
        if pres.birthDate '= "" {
            set age = +$piece(anchor, "-", 1) - +$piece(pres.birthDate, "-", 1)
            if (($piece(anchor, "-", 2) _ $piece(anchor, "-", 3)) < ($piece(pres.birthDate, "-", 2) _ $piece(pres.birthDate, "-", 3))) set age = age - 1
        }
        set q = "Patient aged " _ age _ ", " _ pres.gender _ "."
    }
    // active conditions
    set list = "", cl = $classmethod(read, "ResourcesForPatient", patientRef, "Condition"), it = cl.%GetIterator()
    while it.%GetNext(.k, .o) {
        if $classmethod(read, "CodeFromCoding", o.resource.clinicalStatus) '= "active" continue
        set t = $classmethod(read, "CodeText", o.resource.code)
        if t '= "" set list = list _ $select(list = "": "", 1: ", ") _ t
    }
    if list '= "" set q = q _ " Conditions: " _ list _ "."
    // active medications
    set list = "", ml = $classmethod(read, "ResourcesForPatient", patientRef, "MedicationRequest"), it = ml.%GetIterator()
    while it.%GetNext(.k, .o) {
        if o.resource.status '= "active" continue
        set t = $classmethod(read, "CodeText", o.resource.medicationCodeableConcept)
        if t '= "" set list = list _ $select(list = "": "", 1: ", ") _ t
    }
    if list '= "" set q = q _ " Medications: " _ list _ "."
    // latest value of each key result (BMI, HbA1c, eGFR, LDL, systolic BP)
    set list = "", ol = $classmethod(read, "ResourcesForPatient", patientRef, "Observation"), it = ol.%GetIterator()
    kill best
    while it.%GetNext(.k, .o) {
        set res = o.resource
        set code = $classmethod(read, "CodeFromCoding", res.code)
        if '$listfind($listbuild("39156-5", "4548-4", "33914-3", "13457-7", "8480-6"), code) continue
        if '$isobject(res.valueQuantity) continue
        set dt = $piece(res.effectiveDateTime, "T", 1)
        if ('$data(best(code))) || (dt ] best(code, "dt")) {
            set best(code, "dt") = dt
            set best(code, "txt") = $classmethod(read, "CodeText", res.code) _ " " _ res.valueQuantity.value _ " " _ res.valueQuantity.unit
        }
    }
    set code = ""
    for {
        set code = $order(best(code))
        quit:code=""
        set list = list _ $select(list = "": "", 1: "; ") _ best(code, "txt")
    }
    if list '= "" set q = q _ " Key results: " _ list _ "."
    return q
}

/// Build vector-query text from the patient's social-needs screening
/// (QuestionnaireResponse): the question + answer of every REPORTED need.
/// Positive screens carry long-form patient-voice answers; short answers
/// ("No", "Hardly ever") are negative screens and are excluded.
ClassMethod ScreeningQueryText(patientRef As %String) As %String
{
    set q = ""
    set arr = ##class(FAST.Runtime.FHIRReadOperation).ResourcesForPatient(patientRef, "QuestionnaireResponse")
    set it = arr.%GetIterator()
    while it.%GetNext(.k, .o) {
        set res = o.resource
        if '$isobject(res) continue
        if res.questionnaire '[ "social-needs-screening" continue
        if '$isobject(res.item) continue
        set it2 = res.item.%GetIterator()
        while it2.%GetNext(.k2, .item) {
            set ans = ""
            if $isobject(item.answer) && (item.answer.%Size() > 0) set ans = item.answer.%Get(0).valueString
            if $length(ans) < 30 continue
            set q = q _ $select(q = "": "", 1: " ") _ item.text _ " " _ ans
        }
    }
    return q
}

ClassMethod PersistEvidence(invId As %String, evidence As %DynamicArray)
{
    if '$isobject(evidence) return
    set it = evidence.%GetIterator()
    while it.%GetNext(.k, .e) {
        set ei = ##class(FAST.Data.EvidenceItem).%New()
        set ei.InvocationId = invId
        set ei.EvidenceType = e.evidenceType
        set ei.Source = e.source
        set ei.Display = e.display
        set ei.Relevance = e.relevance
        do ei.%Save()
    }
}

}
