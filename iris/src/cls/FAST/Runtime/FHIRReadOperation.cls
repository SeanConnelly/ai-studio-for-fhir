/// HealthConnect-style Business Operation: reads FHIR evidence from the REAL
/// IRIS for Health FHIR R4 repository (HSFHIR_X0001_R.Rsrc - the resource store
/// behind the /fhir-agent-studio/fhir/r4 endpoint), not a mock JSON table.
Class FAST.Runtime.FHIRReadOperation [ Abstract ]
{

Parameter RSRC = "HSFHIR_X0001_R.Rsrc";

/// Gather resources for a patient. resourceTypes is a %DynamicArray of type
/// names. Returns { resources: [ {resourceType, resourceId, display, resource} ], count }.
ClassMethod Gather(patientRef As %String, resourceTypes As %DynamicArray) As %DynamicObject
{
    set out = {}, all = []
    set it = resourceTypes.%GetIterator()
    while it.%GetNext(.k, .rt) {
        set rp = ..ResourcesForPatient(patientRef, rt), j = rp.%GetIterator()
        while j.%GetNext(.kk, .o) {
            // Agent evidence reflects the ACTIVE clinical record: pending
            // administrative artifacts (orders placed on-hold awaiting prior
            // authorization, unsigned drafts) are excluded. This also keeps
            // demo actions (placing a PA order) from shifting the evidence
            // text - and therefore the LLM cache keys - of every other agent.
            if ((rt = "MedicationRequest") || (rt = "ServiceRequest")) && $isobject(o.resource) && ((o.resource.status = "on-hold") || (o.resource.status = "draft")) continue
            if (rt = "DocumentReference") && $isobject(o.resource) && $isobject(o.resource.type) && (o.resource.type.text [ "Prior Authori") continue
            // saved triage conversations are demo artifacts of the triage agent
            // itself - excluding them keeps completing one conversation from
            // shifting the next conversation's cache keys
            if (rt = "QuestionnaireResponse") && $isobject(o.resource) && (o.resource.questionnaire [ "triage-conversation") continue
            set item = {}
            set item.resourceType = rt
            set item.resourceId = o.resourceId
            set item.display = ..Display(rt, o.resource)
            do item.%Set("resource", o.resource)
            do all.%Push(item)
        }
    }
    set out.resources = all
    set out.count = all.%Size()
    return out
}

/// All resources of a type from the FHIR repository, parsed.
/// Each element: { resourceId, resource }.
ClassMethod AllOfType(resourceType As %String) As %DynamicArray
{
    set arr = []
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT ResourceId, ResourceString FROM " _ ..#RSRC _ " WHERE ResourceType = ? AND Deleted = 0", resourceType)
    while rs.%Next() {
        set res = ##class(FAST.Util.JSON).Parse(rs.%Get("ResourceString"))
        if '$isobject(res) continue
        set o = {}
        set o.resourceId = rs.%Get("ResourceId")
        do o.%Set("resource", res)
        do arr.%Push(o)
    }
    return arr
}

/// Resources of a type belonging to a patient. Scoped in SQL via the FHIR
/// resource store's Compartments column (which carries "Patient/<id>" for every
/// resource in that patient's compartment) so we parse only this patient's
/// resources - not the whole type - which keeps chart loads and the per-patient
/// cache build fast even at population scale. Patient itself is fetched by id.
ClassMethod ResourcesForPatient(patientRef As %String, resourceType As %String) As %DynamicArray
{
    set arr = []
    if resourceType = "Patient" {
        set id = $piece(patientRef, "/", *)
        set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT ResourceId, ResourceString FROM " _ ..#RSRC _ " WHERE ResourceType = ? AND ResourceId = ? AND Deleted = 0", resourceType, id)
    } else {
        // Compartments stores the compartment ref (e.g. "Patient/syn-pat-0001");
        // ids are unique tokens so a substring LIKE is precise. PatientRefOf is a
        // belt-and-braces confirmation for the standard reference fields.
        set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT ResourceId, ResourceString FROM " _ ..#RSRC _ " WHERE ResourceType = ? AND Deleted = 0 AND Compartments LIKE ?", resourceType, "%" _ patientRef _ "%")
    }
    while rs.%Next() {
        set res = ##class(FAST.Util.JSON).Parse(rs.%Get("ResourceString"))
        if '$isobject(res) continue
        set o = {}
        set o.resourceId = rs.%Get("ResourceId")
        do o.%Set("resource", res)
        do arr.%Push(o)
    }
    // Fallback: some resource types (e.g. Task, referenced via `for`) are not
    // compartment-indexed, so the Compartments scan returns nothing. Only when
    // empty, match the patient reference in the resource body instead.
    if (resourceType '= "Patient") && (arr.%Size() = 0) {
        set rs2 = ##class(%SQL.Statement).%New().%ExecDirect(.s2, "SELECT ResourceId, ResourceString FROM " _ ..#RSRC _ " WHERE ResourceType = ? AND Deleted = 0 AND ResourceString LIKE ?", resourceType, "%" _ patientRef _ "%")
        while rs2.%Next() {
            set res = ##class(FAST.Util.JSON).Parse(rs2.%Get("ResourceString"))
            if '$isobject(res) continue
            set o = {}
            set o.resourceId = rs2.%Get("ResourceId")
            do o.%Set("resource", res)
            do arr.%Push(o)
        }
    }
    return arr
}

/// The patient reference a resource points at.
ClassMethod PatientRefOf(res As %DynamicObject) As %String
{
    if '$isobject(res) return ""
    if $isobject(res.subject) && (res.subject.reference '= "") return res.subject.reference
    if $isobject(res.beneficiary) && (res.beneficiary.reference '= "") return res.beneficiary.reference
    if $isobject(res.patient) && (res.patient.reference '= "") return res.patient.reference
    return ""
}

/// A short human-readable label for a resource, used in evidence displays.
ClassMethod Display(resourceType As %String, res As %DynamicObject) As %String
{
    if '$isobject(res) return resourceType
    if resourceType = "Patient" {
        if $isobject(res.name) && (res.name.%Size() > 0) {
            set n = res.name.%Get(0)
            set given = "", prefix = ""
            if $isobject(n.given) && (n.given.%Size() > 0) set given = n.given.%Get(0)
            if $isobject(n.prefix) && (n.prefix.%Size() > 0) set prefix = n.prefix.%Get(0)
            return $zstrip(prefix _ " " _ given _ " " _ n.family, "<>W")
        }
        return "Patient " _ res.id
    }
    if (resourceType = "Observation") {
        set lbl = ..CodeText(res.code)
        if $isobject(res.valueQuantity) set lbl = lbl _ " = " _ res.valueQuantity.value _ " " _ res.valueQuantity.unit
        if res.valueString '= "" set lbl = lbl _ ": " _ res.valueString
        set flag = ..Interp(res)
        if flag '= "" set lbl = lbl _ " [" _ flag _ "]"
        if res.effectiveDateTime '= "" set lbl = lbl _ " (" _ $piece(res.effectiveDateTime, "T", 1) _ ")"
        return lbl
    }
    if resourceType = "Condition" {
        set t = ..CodeText(res.code)
        set st = $select($isobject(res.clinicalStatus): ..CodeFromCoding(res.clinicalStatus), 1: "")
        if (st '= "") && (st '= "active") set t = t _ " (" _ st _ ")"
        return t
    }
    if resourceType = "MedicationRequest" {
        set t = ..CodeText(res.medicationCodeableConcept)
        if res.status '= "" set t = t _ " (" _ res.status _ ")"
        return t
    }
    if resourceType = "Encounter" {
        set t = ""
        if $isobject(res.class) && (res.class.display '= "") set t = res.class.display
        if $isobject(res.reasonCode) && (res.reasonCode.%Size() > 0) {
            set rc = ..CodeText(res.reasonCode.%Get(0))
            if rc '= "" set t = $select(t = "": rc, 1: t _ " - " _ rc)
        }
        if t = "" set t = "Encounter"
        if res.status '= "" set t = t _ " [" _ res.status _ "]"
        set d = $select($isobject(res.period): $piece(res.period.start, "T", 1), 1: "")
        if d '= "" set t = t _ " (" _ d _ ")"
        return t
    }
    if resourceType = "AllergyIntolerance" {
        set t = ..CodeText(res.code)
        if res.criticality '= "" set t = t _ " (" _ res.criticality _ " risk)"
        return t
    }
    if resourceType = "Immunization" {
        set t = ..CodeText(res.vaccineCode)
        if res.occurrenceDateTime '= "" set t = t _ " (" _ $piece(res.occurrenceDateTime, "T", 1) _ ")"
        return t
    }
    if resourceType = "Procedure" {
        set t = ..CodeText(res.code)
        if res.performedDateTime '= "" set t = t _ " (" _ $piece(res.performedDateTime, "T", 1) _ ")"
        return t
    }
    if resourceType = "Task" {
        set t = $select(res.description '= "": res.description, 1: "Task")
        if res.status '= "" set t = t _ " [" _ res.status _ "]"
        set due = $select($isobject(res.restriction) && $isobject(res.restriction.period): res.restriction.period.end, 1: "")
        if due '= "" set t = t _ " (due " _ $piece(due, "T", 1) _ ")"
        return t
    }
    if resourceType = "ServiceRequest" {
        set t = ..CodeText(res.code)
        if (t = "") set t = "Service request"
        if res.status '= "" set t = t _ " (" _ res.status _ ")"
        return t
    }
    if resourceType = "QuestionnaireResponse" {
        // Render the full Q&A so downstream consumers (the LLM evidence, the
        // chart) see the patient's own words, not an opaque resource id.
        set t = $select(res.questionnaire [ "social-needs-screening": "Social needs screening", res.questionnaire [ "triage-conversation": "Triage conversation", 1: "Questionnaire response")
        if res.authored '= "" set t = t _ " (" _ $piece(res.authored, "T", 1) _ ")"
        if $isobject(res.item) {
            set it = res.item.%GetIterator()
            while it.%GetNext(.k, .item) {
                set ans = ""
                if $isobject(item.answer) && (item.answer.%Size() > 0) set ans = item.answer.%Get(0).valueString
                if (item.text = "") || (ans = "") continue
                set t = t _ " | " _ item.text _ " -> " _ ans
            }
        }
        return t
    }
    if resourceType = "Flag" return ..CodeText(res.code)
    if resourceType = "CarePlan" return $select(res.title '= "": res.title, 1: "Care plan") _ $select(res.status '= "": " [" _ res.status _ "]", 1: "")
    if resourceType = "DiagnosticReport" return ..CodeText(res.code) _ $select(res.effectiveDateTime '= "": " (" _ $piece(res.effectiveDateTime, "T", 1) _ ")", 1: "") _ $select(res.conclusion'="":" - "_res.conclusion, 1:"")
    if resourceType = "DocumentReference" {
        set t = $select(..CodeText(res.type) '= "": ..CodeText(res.type), 1: "Document")
        if res.date '= "" set t = t _ " (" _ $piece(res.date, "T", 1) _ ")"
        if res.description '= "" set t = t _ ": " _ $extract(res.description, 1, 600)
        return t
    }
    if resourceType = "Coverage" {
        set p = ""
        if $isobject(res.payor) && (res.payor.%Size() > 0) set p = res.payor.%Get(0).display
        return "Coverage: " _ p
    }
    return resourceType _ "/" _ res.id
}

/// The interpretation flag (H/L/HH/...) of an Observation, if any.
ClassMethod Interp(res As %DynamicObject) As %String
{
    if '$isobject(res.interpretation) || (res.interpretation.%Size() = 0) return ""
    return ..CodeFromCoding(res.interpretation.%Get(0))
}

/// First coding.code from a CodeableConcept-shaped object.
ClassMethod CodeFromCoding(cc As %DynamicObject) As %String
{
    if '$isobject(cc) || '$isobject(cc.coding) || (cc.coding.%Size() = 0) return ""
    return cc.coding.%Get(0).code
}

/// Best-effort text for a CodeableConcept.
ClassMethod CodeText(cc As %DynamicObject) As %String
{
    if '$isobject(cc) return ""
    if cc.text '= "" return cc.text
    if $isobject(cc.coding) && (cc.coding.%Size() > 0) return cc.coding.%Get(0).display
    return ""
}

}
