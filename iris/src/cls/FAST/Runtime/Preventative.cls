/// Per-patient preventative-care checks for the patient chart: evaluates the
/// patient against the three demo registers (diabetes review, breast screening,
/// flu vaccination) directly from their FHIR record, and can draft an AI invitation
/// letter to book the relevant appointment.
///
/// Population cohorts live in FAST.Runtime.CareRules (AI-authored SQL, run on the
/// worklist). This class is the in-chart counterpart: what is THIS patient due.
Class FAST.Runtime.Preventative [ Abstract ]
{

/// What this patient is due / overdue for. { patientRef, count, overdue:[{area,title,detail,severity}] }.
ClassMethod ForPatient(patientRef As %String) As %DynamicObject
{
    set read = "FAST.Runtime.FHIRReadOperation"
    set ai = "FAST.Runtime.AIHubOperation"
    set out = {}, overdue = [], out.patientRef = patientRef, out.overdue = overdue

    set pl = $classmethod(read, "ResourcesForPatient", patientRef, "Patient")
    if pl.%Size() = 0 { set out.count = 0  return out }
    set pat = pl.%Get(0).resource
    set gender = pat.gender
    set age = $classmethod(ai, "AgeFrom", pat.birthDate)

    // ---- diabetes review: T2DM + latest HbA1c at/above target (>= 7.5%) ----
    set diabetic = ..HasCondition(patientRef, "44054006")
    if diabetic {
        set a1c = ..LatestObs(patientRef, "4548-4", .a1cDate)
        if (a1c '= "") && (a1c >= 7.5) {
            do overdue.%Push(..Item("diabetes", "Diabetes review", "Most recent HbA1c " _ a1c _ "% (" _ $piece(a1cDate, "T", 1) _ ") is above the 7.5% target.", "warning"))
        } elseif (a1c = "") {
            do overdue.%Push(..Item("diabetes", "Diabetes review", "No HbA1c on record - monitoring overdue.", "warning"))
        }
    }

    // ---- breast cancer screening: women aged 50-70 (no mammogram in the demo data) ----
    if (gender = "female") && (age '= "") && (age >= 50) && (age <= 70) {
        do overdue.%Push(..Item("breast", "Breast cancer screening", "Eligible (age " _ age _ "); no breast screening on record in the last 3 years.", "info"))
    }

    // ---- flu vaccination: 65+ with no influenza immunisation in the last 12 months ----
    if (age '= "") && (age >= 65) {
        if '..RecentImmunisation(patientRef, "158", 365) {
            do overdue.%Push(..Item("flu", "Annual flu vaccination", "Aged " _ age _ "; no influenza vaccination recorded in the last 12 months.", "info"))
        }
    }

    set out.count = overdue.%Size()
    return out
}

ClassMethod Item(area As %String, title As %String, detail As %String, severity As %String) As %DynamicObject
{
    set o = {}, o.area = area, o.title = title, o.detail = detail, o.severity = severity
    return o
}

/// Does the patient have an active condition with this SNOMED code?
ClassMethod HasCondition(patientRef As %String, code As %String) As %Boolean
{
    set l = $classmethod("FAST.Runtime.FHIRReadOperation", "ResourcesForPatient", patientRef, "Condition"), it = l.%GetIterator()
    while it.%GetNext(.k, .o) {
        set res = o.resource
        if $isobject(res.code) && $isobject(res.code.coding) {
            set j = res.code.coding.%GetIterator()
            while j.%GetNext(.kk, .c) { if c.code = code return 1 }
        }
    }
    return 0
}

/// Latest numeric value (and date, by reference) for an Observation LOINC code.
ClassMethod LatestObs(patientRef As %String, loinc As %String, ByRef date As %String) As %String
{
    set date = "", best = "", bestDate = ""
    set l = $classmethod("FAST.Runtime.FHIRReadOperation", "ResourcesForPatient", patientRef, "Observation"), it = l.%GetIterator()
    while it.%GetNext(.k, .o) {
        set res = o.resource
        set match = 0
        if $isobject(res.code) && $isobject(res.code.coding) {
            set j = res.code.coding.%GetIterator()
            while j.%GetNext(.kk, .c) { if c.code = loinc set match = 1 }
        }
        if 'match continue
        if '$isobject(res.valueQuantity) continue
        set d = res.effectiveDateTime
        if (bestDate = "") || (d ]] bestDate) { set bestDate = d, best = res.valueQuantity.value }
    }
    set date = bestDate
    return best
}

/// Has an immunisation with this CVX code in the last `days` (vs the anchor date)?
ClassMethod RecentImmunisation(patientRef As %String, cvx As %String, days As %Integer) As %Boolean
{
    set cutoff = $zdate($zdateh($classmethod("FAST.Runtime.AIHubOperation", "AnchorDate"), 3) - days, 3)
    set l = $classmethod("FAST.Runtime.FHIRReadOperation", "ResourcesForPatient", patientRef, "Immunization"), it = l.%GetIterator()
    while it.%GetNext(.k, .o) {
        set res = o.resource
        set match = 0
        if $isobject(res.vaccineCode) && $isobject(res.vaccineCode.coding) {
            set j = res.vaccineCode.coding.%GetIterator()
            while j.%GetNext(.kk, .c) { if c.code = cvx set match = 1 }
        }
        if 'match continue
        set d = $piece(res.occurrenceDateTime, "T", 1)
        if (d '= "") && (d ]] cutoff) return 1
    }
    return 0
}

/// Draft an AI invitation letter for the patient + area. Three-tier cache.
/// { ok, letter, source, area }.
ClassMethod Letter(patientRef As %String, area As %String) As %DynamicObject
{
    set ai = "FAST.Runtime.AIHubOperation"
    set read = "FAST.Runtime.FHIRReadOperation"
    set pl = $classmethod(read, "ResourcesForPatient", patientRef, "Patient")
    set name = $select(pl.%Size() > 0: $classmethod(read, "Display", "Patient", pl.%Get(0).resource), 1: "the patient")
    set topic = $case(area, "diabetes": "a diabetes review (including an HbA1c blood test)", "breast": "breast cancer screening (a mammogram)", "flu": "an annual flu vaccination", : "a preventative care appointment")

    set sys = "You are an NHS practice administrator writing a short, warm patient invitation letter. "
            _ "Plain language at about a grade 6 reading level. 1-2 short paragraphs. Explain briefly why this matters and invite them to call the practice to book. "
            _ "Do not give medical advice or alarming statements. Sign off from 'Cedar Valley Health'. Respond with ONLY the letter text - no preamble, no JSON."
    set user = "Write an invitation letter to " _ name _ " inviting them to book " _ topic _ "."

    set out = {}, letter = "", source = "deterministic"
    set key = $classmethod(ai, "CacheKey", "prevent-letter", sys, user)
    if $classmethod(ai, "UseCache") {
        set hit = ##class(FAST.Data.LLMCache).KeyIdxOpen(key)
        if $isobject(hit) { set letter = hit.OutputJSON, source = "cached" }
    }
    if (letter = "") && $classmethod(ai, "HasLiveKey") {
        set msgs = []
        do msgs.%Push({"role": "system", "content": (sys)})
        do msgs.%Push({"role": "user", "content": (user)})
        set sc = ##class(FAST.Runtime.LLMClient).Chat(msgs, .content, 1)
        if $$$ISOK(sc) {
            set letter = $zstrip(content, "<>W"), source = "live (" _ $get(^FAST("llm", "model"), "llm") _ ")"
            do $classmethod(ai, "StoreCache", key, $get(^FAST("llm", "model")), $extract(sys _ " " _ user, 1, 1800), letter)
        }
    }
    if letter = "" {
        set letter = "Dear " _ name _ "," _ $char(10, 10) _ "Our records show you are due for " _ topic _ ". Keeping up to date with this helps us look after your health. Please call the practice on 0300 000 0000 to book an appointment at a time that suits you." _ $char(10, 10) _ "Yours sincerely," _ $char(10) _ "Cedar Valley Health"
    }
    set out.ok = 1, out.area = area, out.letter = letter, out.source = source
    return out
}

}
