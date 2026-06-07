/// Explicit FHIR tools the agent runtime (and the Clinical app) call against the
/// REAL IRIS for Health FHIR R4 repository — the tool-using, terminology-resolving
/// behaviour the contest rewards. These are honest reads/searches over the FHIR SQL
/// Builder projections (HSFHIR_X0001_S, fast at population scale) and the parsed
/// resource store, never the LLM inventing data:
///   PatientSearch     — name / gender / birthDate / identifier
///   Everything        — compact $everything-style bundle for a patient
///   TerminologyResolve— clinical text → coded concept (before coded searches)
///   CohortByCode      — reverse-chain (_has) cohort discovery
/// All string projection columns carry IRIS collation-prefix bytes; FAST.Util.SqlGuard
/// strips them on output (CleanCell).
Class FAST.Runtime.FHIRTools [ Abstract ]
{

/// Search patients by any combination of name (given/family), gender, birthDate,
/// NHS number, hospital number (MRN), or free identifier. With NO criteria it
/// returns the whole cohort (up to max). Returns
/// { patients: [ {ref,label,given,family,gender,birthDate,nhs,mrn} ], count }.
ClassMethod PatientSearch(name As %String = "", gender As %String = "", birthDate As %String = "", identifier As %String = "", max As %Integer = 2000, nhs As %String = "", mrn As %String = "") As %DynamicObject
{
    // bound args are built as a subscripted array (n + args(1..n)) for %Execute(args...)
    set where = "1=1", n = 0
    if name '= "" {
        // Split a multi-word query ("Sam Tanaka") into tokens; each token must
        // match some name part (AND across tokens) so a full "given family"
        // query resolves, not just a single given/family part.
        set name = $zstrip(name, "<>W")
        for i = 1:1:$length(name, " ") {
            set tok = $piece(name, " ", i)
            if tok = "" continue
            set where = where _ " AND (given LIKE ? OR family LIKE ? OR name LIKE ?)"
            set n = n + 1, args(n) = "%" _ tok _ "%"
            set n = n + 1, args(n) = "%" _ tok _ "%"
            set n = n + 1, args(n) = "%" _ tok _ "%"
        }
    }
    if gender '= "" { set where = where _ " AND gender = ?", n = n + 1, args(n) = $zconvert(gender, "L") }
    if birthDate '= "" { set where = where _ " AND birthdate LIKE ?", n = n + 1, args(n) = birthDate _ "%" }
    // NHS / hospital numbers are packed in the identifier column as "<system>|<value>";
    // match against the specific system marker so each field searches the right id.
    if nhs '= "" { set where = where _ " AND identifier LIKE ?", n = n + 1, args(n) = "%nhs-number|" _ $zstrip(nhs, "*W") _ "%" }
    if mrn '= "" { set where = where _ " AND identifier LIKE ?", n = n + 1, args(n) = "%hospital-number|" _ $zstrip(mrn, "*W") _ "%" }
    if identifier '= "" { set where = where _ " AND identifier LIKE ?", n = n + 1, args(n) = "%" _ identifier _ "%" }
    set args = n

    set sql = "SELECT TOP " _ (+max) _ " Key, _id, given, family, gender, birthdate, identifier FROM HSFHIR_X0001_S.Patient WHERE " _ where _ " ORDER BY family, given"
    set st = ##class(%SQL.Statement).%New()
    set sc = st.%Prepare(sql)
    set arr = []
    if $$$ISERR(sc) { set o = {}, o.patients = arr, o.count = 0, o.error = $system.Status.GetErrorText(sc)  return o }
    set rs = st.%Execute(args...)
    set guard = "FAST.Util.SqlGuard"
    while rs.%Next() {
        set given = $classmethod(guard, "CleanCell", rs.%Get("given"))
        set family = $classmethod(guard, "CleanCell", rs.%Get("family"))
        set p = {}
        set p.ref = rs.%Get("Key")
        set p.given = given, p.family = family
        set p.label = $zstrip(given _ " " _ family, "<>W")
        set p.gender = rs.%Get("gender")
        set p.birthDate = rs.%Get("birthdate")
        set packed = rs.%Get("identifier")
        set p.nhs = ..IdentValue(packed, "nhs-number|")
        set p.mrn = ..IdentValue(packed, "hospital-number|")
        do arr.%Push(p)
    }
    set o = {}, o.patients = arr, o.count = arr.%Size()
    return o
}

/// Pull an identifier value out of the packed projection string. The column
/// stores each identifier as "<system>|<value>" with control-char separators;
/// given a system marker (e.g. "nhs-number|") return the leading digit run after it.
ClassMethod IdentValue(packed As %String, marker As %String) As %String
{
    if (packed = "") || (packed '[ marker) return ""
    set tail = $piece(packed, marker, 2), out = ""
    for i = 1:1:$length(tail) {
        set c = $extract(tail, i)
        if c '? 1N quit
        set out = out _ c
    }
    return out
}

/// A compact $everything-style bundle for a patient: the clinically relevant
/// resource types, field-extracted to short tokens to keep LLM token usage down
/// (per the contest's bundle-reduction guidance). Returns { patient, sections }.
ClassMethod Everything(patientRef As %String) As %DynamicObject
{
    set read = "FAST.Runtime.FHIRReadOperation"
    set o = {}, o.patientRef = patientRef
    set pl = $classmethod(read, "ResourcesForPatient", patientRef, "Patient")
    if pl.%Size() > 0 {
        set pres = pl.%Get(0).resource
        set o.patient = $classmethod(read, "Display", "Patient", pres)
        set o.gender = $select(pres.gender '= "": pres.gender, 1: "")
        set o.birthDate = $select(pres.birthDate '= "": pres.birthDate, 1: "")
        set o.nhsNo = ..Identifier(pres, "nhs-number")
        set o.hospitalNo = ..Identifier(pres, "hospital-number")
        set o.mrn = $select(o.hospitalNo '= "": o.hospitalNo, 1: $piece(patientRef, "/", *))
        set o.address = ..AddressLine(pres)
        if $isobject(pres.generalPractitioner) && (pres.generalPractitioner.%Size() > 0) {
            set o.gp = pres.generalPractitioner.%Get(0).display
        }
    }
    // clinical alerts (FHIR Flag) — surfaced on the banner, distinct from allergies
    set alerts = [], fl = $classmethod(read, "ResourcesForPatient", patientRef, "Flag"), fit = fl.%GetIterator()
    while fit.%GetNext(.fk, .fitem) { do alerts.%Push($classmethod(read, "Display", "Flag", fitem.resource)) }
    set o.alerts = alerts
    set sections = {}
    set types = $listbuild("Condition", "MedicationRequest", "AllergyIntolerance", "Observation", "DiagnosticReport", "Encounter", "Procedure", "Immunization", "CarePlan", "Coverage", "QuestionnaireResponse", "DocumentReference")
    set ptr = 0
    while $listnext(types, ptr, t) {
        set list = $classmethod(read, "ResourcesForPatient", patientRef, t), lines = [], it = list.%GetIterator()
        while it.%GetNext(.k, .item) { do lines.%Push($classmethod(read, "Display", t, item.resource)) }
        if lines.%Size() > 0 do sections.%Set(t, lines)
    }
    set o.sections = sections
    return o
}

/// Compact patient context for interoperability message payloads: who a message
/// is about, in the identifiers an integrator expects (display name, NHS number,
/// MRN) alongside the FHIR logical reference. Shown in Visual Trace / the
/// Studio's trace timeline.
ClassMethod PatientInfo(patientRef As %String) As %DynamicObject
{
    set o = {}
    set pl = ##class(FAST.Runtime.FHIRReadOperation).ResourcesForPatient(patientRef, "Patient")
    if pl.%Size() = 0 return o
    set pres = pl.%Get(0).resource
    set o.display = ##class(FAST.Runtime.FHIRReadOperation).Display("Patient", pres)
    set nhs = ..Identifier(pres, "nhs-number")
    if nhs '= "" set o.nhsNo = $extract(nhs, 1, 3) _ " " _ $extract(nhs, 4, 6) _ " " _ $extract(nhs, 7, 10)
    set mrn = ..Identifier(pres, "hospital-number")
    if mrn '= "" set o.mrn = mrn
    return o
}

/// Pull an identifier value whose system contains the given token (e.g. "nhs-number").
ClassMethod Identifier(pres As %DynamicObject, systemToken As %String) As %String
{
    if '$isobject(pres) || '$isobject(pres.identifier) return ""
    set it = pres.identifier.%GetIterator()
    while it.%GetNext(.k, .id) {
        if $isobject(id) && (id.system [ systemToken) return id.value
    }
    return ""
}

/// Format the patient's home/first address as a single readable line.
ClassMethod AddressLine(pres As %DynamicObject) As %String
{
    if '$isobject(pres) || '$isobject(pres.address) || (pres.address.%Size() = 0) return ""
    set a = pres.address.%Get(0), parts = ""
    if $isobject(a.line) {
        set lit = a.line.%GetIterator()
        while lit.%GetNext(.k, .ln) { if ln '= "" set parts = parts _ $select(parts = "": "", 1: ", ") _ ln }
    }
    if a.city '= "" set parts = parts _ $select(parts = "": "", 1: ", ") _ a.city
    if a.postalCode '= "" set parts = parts _ $select(parts = "": "", 1: ", ") _ a.postalCode
    return parts
}

/// Resolve clinical text to coded concepts via the seeded terminology table.
/// Exact (case-insensitive) match first; otherwise a contains match. Optionally
/// constrained to a code system. Returns { query, concepts: [ {system,code,display} ], count }.
ClassMethod TerminologyResolve(text As %String, system As %String = "") As %DynamicObject
{
    set o = {}, o.query = text, concepts = []
    set lc = $zconvert($zstrip(text, "<>W"), "L")
    if lc = "" { set o.concepts = concepts, o.count = 0  return o }

    // No SELECT DISTINCT: on string columns it returns the collation (upper-cased)
    // form, mangling the display. We dedupe by system|code in code instead.
    set sysClause = $select(system '= "": " AND System = ?", 1: "")
    set seen = ""
    // exact match, then fall back to contains
    set sql = "SELECT System, Code, Display FROM FAST_Data.TerminologyConcept WHERE SearchText = ?" _ sysClause
    set st = ##class(%SQL.Statement).%New()
    if $$$ISERR(st.%Prepare(sql)) { set o.concepts = concepts, o.count = 0  return o }
    set rs = $select(system '= "": st.%Execute(lc, system), 1: st.%Execute(lc))
    do ..Collect(rs, concepts, .seen)
    if concepts.%Size() = 0 {
        set sql2 = "SELECT System, Code, Display FROM FAST_Data.TerminologyConcept WHERE SearchText LIKE ?" _ sysClause
        set st2 = ##class(%SQL.Statement).%New()
        if $$$ISOK(st2.%Prepare(sql2)) {
            set rs2 = $select(system '= "": st2.%Execute("%" _ lc _ "%", system), 1: st2.%Execute("%" _ lc _ "%"))
            do ..Collect(rs2, concepts, .seen)
        }
    }
    set o.concepts = concepts, o.count = concepts.%Size()
    return o
}

/// Push distinct (system|code) concept rows into the array.
ClassMethod Collect(rs As %SQL.StatementResult, concepts As %DynamicArray, ByRef seen)
{
    while rs.%Next() {
        set key = rs.%Get("System") _ "|" _ rs.%Get("Code")
        if $data(seen(key)) continue
        set seen(key) = 1
        set c = {}
        set c.system = rs.%Get("System")
        set c.code = rs.%Get("Code")
        set c.display = rs.%Get("Display")
        do concepts.%Push(c)
    }
}

/// Reverse-chain (_has) cohort discovery: patients who have a resource of
/// resourceType carrying the given code. The projection's coded columns are packed
/// search tokens, so we match the code with LIKE. Returns
/// { code, resourceType, patients: [ {ref} ], count }.
ClassMethod CohortByCode(code As %String, resourceType As %String = "Condition") As %DynamicObject
{
    set o = {}, o.code = code, o.resourceType = resourceType, patients = []
    if code = "" { set o.patients = patients, o.count = 0  return o }
    set table = "HSFHIR_X0001_S." _ resourceType
    set guard = "FAST.Util.SqlGuard"
    // Join to the Patient projection so the worklist carries names, not bare refs.
    // No SELECT DISTINCT (it returns the collation/upper-cased form of string
    // columns) — dedupe by patient ref in code instead.
    set sql = "SELECT t.patient, p.given, p.family, p.gender, p.birthdate FROM " _ table _ " t "
            _ "JOIN HSFHIR_X0001_S.Patient p ON p.Key = t.patient WHERE t.code LIKE ? AND t.patient IS NOT NULL ORDER BY p.family, p.given"
    set st = ##class(%SQL.Statement).%New()
    if $$$ISERR(st.%Prepare(sql)) { set o.patients = patients, o.count = 0, o.error = "cohort query could not be prepared for " _ resourceType  return o }
    set rs = st.%Execute("%" _ code _ "%")
    set seen = ""
    while rs.%Next() {
        set ref = rs.%Get("patient")
        if $data(seen(ref)) continue
        set seen(ref) = 1
        set given = $classmethod(guard, "CleanCell", rs.%Get("given"))
        set family = $classmethod(guard, "CleanCell", rs.%Get("family"))
        set p = {}
        set p.ref = ref
        set p.label = $zstrip(given _ " " _ family, "<>W")
        set p.gender = rs.%Get("gender")
        set p.birthDate = rs.%Get("birthdate")
        do patients.%Push(p)
    }
    set o.patients = patients, o.count = patients.%Size()
    return o
}

}
