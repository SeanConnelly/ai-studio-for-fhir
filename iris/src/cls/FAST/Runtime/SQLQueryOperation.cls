/// HealthConnect-style Business Operation: named, read-only query functions over
/// the REAL IRIS for Health FHIR R4 repository (via FHIRReadOperation, which reads
/// HSFHIR_X0001_R.Rsrc). Each returns structured facts.
Class FAST.Runtime.SQLQueryOperation [ Abstract ]
{

Parameter LOINCA1C = "4548-4";

Parameter SNOMEDDIABETES = "44054006";

/// Dispatch a named query (as referenced in a flow's evidence.sql).
ClassMethod Run(name As %String, patientRef As %String = "") As %DynamicObject
{
    if name = "abnormal_result_followup_status" return ..AbnormalResultFollowupStatus(patientRef)
    if name = "prior_auth_supporting_evidence" return ..PriorAuthSupportingEvidence(patientRef)
    if name = "diabetes_a1c_over_9_last_6_months" return ..DiabetesA1cOver9Last6Months()
    if name = "active_conditions" return ..ActiveConditions(patientRef)
    if name = "recent_labs" return ..RecentLabs(patientRef)
    if name = "recent_encounters" return ..RecentEncounters(patientRef)
    if name = "medication_history" return ..MedicationHistory(patientRef)
    if name = "admission_history" return ..AdmissionHistory(patientRef)
    if name = "overdue_tasks" return ..OpenTasks(patientRef)
    if name = "offtrack_goals" return ..OfftrackGoals(patientRef)
    if name = "overdue_screenings" return ..OverdueScreenings(patientRef)
    if name = "diabetes_a1c_followup" {
        if patientRef '= "" return ..AbnormalResultFollowupStatus(patientRef)
        return ..DiabetesA1cOver9Last6Months()
    }
    set o = {}, o.query = name, o.facts = [], o.note = "no demo implementation"
    return o
}

/// Active conditions (problem list) for a patient.
ClassMethod ActiveConditions(patientRef As %String) As %DynamicObject
{
    set o = {}, o.query = "active_conditions", list = [], read = "FAST.Runtime.FHIRReadOperation"
    set cl = $classmethod(read, "ResourcesForPatient", patientRef, "Condition"), it = cl.%GetIterator()
    while it.%GetNext(.k, .c) {
        set r = c.resource, status = $select($isobject(r.clinicalStatus) && $isobject(r.clinicalStatus.coding) && (r.clinicalStatus.coding.%Size()>0): r.clinicalStatus.coding.%Get(0).code, 1: "")
        set one = {}, one.condition = $classmethod(read, "CodeText", r.code), one.status = status, one.recordedDate = ..DatePart(r.recordedDate)
        do list.%Push(one)
    }
    set o.conditions = list, o.count = list.%Size()
    return o
}

/// Recent laboratory observations (most clinically useful labs) for a patient.
ClassMethod RecentLabs(patientRef As %String) As %DynamicObject
{
    set o = {}, o.query = "recent_labs", list = [], read = "FAST.Runtime.FHIRReadOperation"
    set ol = $classmethod(read, "ResourcesForPatient", patientRef, "Observation"), it = ol.%GetIterator()
    while it.%GetNext(.k, .ob) {
        set r = ob.resource, one = {}
        set one.test = $classmethod(read, "CodeText", r.code)
        set one.value = $select($isobject(r.valueQuantity): r.valueQuantity.value, 1: "")
        set one.unit = $select($isobject(r.valueQuantity): r.valueQuantity.unit, 1: "")
        set one.date = ..DatePart(r.effectiveDateTime)
        set one.abnormal = ..IsAbnormal(r)
        do list.%Push(one)
    }
    set o.labs = list, o.count = list.%Size()
    return o
}

/// Encounter history for a patient.
ClassMethod RecentEncounters(patientRef As %String) As %DynamicObject
{
    set o = {}, o.query = "recent_encounters", list = [], read = "FAST.Runtime.FHIRReadOperation"
    set el = $classmethod(read, "ResourcesForPatient", patientRef, "Encounter"), it = el.%GetIterator()
    while it.%GetNext(.k, .e) {
        set r = e.resource, one = {}
        set one.type = $select($isobject(r.class): r.class.display, 1: "encounter")
        set one.status = r.status
        set one.date = ..DatePart($select($isobject(r.period): r.period.start, 1: ""))
        do list.%Push(one)
    }
    set o.encounters = list, o.count = list.%Size()
    return o
}

/// Medication history (active + past) for a patient.
ClassMethod MedicationHistory(patientRef As %String) As %DynamicObject
{
    set o = {}, o.query = "medication_history", list = [], read = "FAST.Runtime.FHIRReadOperation"
    set ml = $classmethod(read, "ResourcesForPatient", patientRef, "MedicationRequest"), it = ml.%GetIterator()
    while it.%GetNext(.k, .m) {
        // pending administrative artifacts (orders on-hold awaiting prior auth,
        // unsigned drafts) are not active medication history - excluding them also
        // keeps demo order-placement from shifting other agents' cache keys
        if (m.resource.status = "on-hold") || (m.resource.status = "draft") continue
        set r = m.resource, one = {}
        set one.medication = $classmethod(read, "CodeText", r.medicationCodeableConcept)
        set one.status = r.status
        if $isobject(r.note) && (r.note.%Size() > 0) set one.note = r.note.%Get(0).text
        do list.%Push(one)
    }
    set o.medications = list, o.count = list.%Size()
    return o
}

/// Admission / ED encounter history (drives readmission risk).
ClassMethod AdmissionHistory(patientRef As %String) As %DynamicObject
{
    set o = {}, o.query = "admission_history", list = [], read = "FAST.Runtime.FHIRReadOperation"
    set el = $classmethod(read, "ResourcesForPatient", patientRef, "Encounter"), it = el.%GetIterator(), inpatient = 0, ed = 0
    while it.%GetNext(.k, .e) {
        set r = e.resource, cls = $select($isobject(r.class): r.class.code, 1: "")
        if (cls = "IMP") || (cls = "EMER") {
            set one = {}, one.type = $select(cls="IMP":"inpatient admission", 1:"emergency visit"), one.date = ..DatePart($select($isobject(r.period): r.period.start, 1: "")), one.status = r.status
            do list.%Push(one)
            if cls = "IMP" set inpatient = inpatient + 1
            if cls = "EMER" set ed = ed + 1
        }
    }
    set o.admissions = list, o.inpatientCount = inpatient, o.edCount = ed, o.count = list.%Size()
    return o
}

/// Open (not completed/cancelled) Tasks for a patient.
ClassMethod OpenTasks(patientRef As %String) As %DynamicObject
{
    set o = {}, o.query = "overdue_tasks", list = [], read = "FAST.Runtime.FHIRReadOperation"
    set tl = $classmethod(read, "ResourcesForPatient", patientRef, "Task"), it = tl.%GetIterator()
    while it.%GetNext(.k, .t) {
        set r = t.resource
        if (r.status = "completed") || (r.status = "cancelled") continue
        set one = {}, one.description = r.description, one.status = r.status, one.priority = r.priority
        set one.due = $select($isobject(r.restriction) && $isobject(r.restriction.period): $piece(r.restriction.period.end, "T", 1), 1: "")
        do list.%Push(one)
    }
    set o.openTasks = list, o.count = list.%Size()
    return o
}

/// Goals that are not on track (achievement status not improving/achieved).
ClassMethod OfftrackGoals(patientRef As %String) As %DynamicObject
{
    set o = {}, o.query = "offtrack_goals", list = [], read = "FAST.Runtime.FHIRReadOperation"
    set gl = $classmethod(read, "ResourcesForPatient", patientRef, "Goal"), it = gl.%GetIterator()
    while it.%GetNext(.k, .g) {
        set r = g.resource
        set status = $select($isobject(r.achievementStatus) && $isobject(r.achievementStatus.coding) && (r.achievementStatus.coding.%Size()>0): r.achievementStatus.coding.%Get(0).code, 1: "")
        set one = {}, one.goal = $select($isobject(r.description): r.description.text, 1: ""), one.achievementStatus = status
        set one.offTrack = ((status '= "improving") && (status '= "achieved") && (status '= ""))
        do list.%Push(one)
    }
    set o.goals = list, o.count = list.%Size()
    return o
}

/// Overdue preventive screenings for a patient (heuristic over the record): flags
/// missing recent influenza immunization and HbA1c older than ~6 months.
ClassMethod OverdueScreenings(patientRef As %String) As %DynamicObject
{
    set o = {}, o.query = "overdue_screenings", gaps = [], read = "FAST.Runtime.FHIRReadOperation"
    set cutoff = $zdate($zdateh($parameter("FAST.Seed.SyntheticData", "ANCHORDATE"), 3) - 183, 3)
    set yearAgo = $zdate($zdateh($parameter("FAST.Seed.SyntheticData", "ANCHORDATE"), 3) - 365, 3)
    // most recent HbA1c
    set lastA1c = "", ol = $classmethod(read, "ResourcesForPatient", patientRef, "Observation"), it = ol.%GetIterator()
    while it.%GetNext(.k, .ob) {
        if '..HasCode(ob.resource.code, ..#LOINCA1C) continue
        set d = ..DatePart(ob.resource.effectiveDateTime)
        if d ] lastA1c set lastA1c = d
    }
    if (lastA1c = "") || (cutoff ] lastA1c) {
        set g = {}, g.screening = "HbA1c", g.status = "overdue", g.lastDate = lastA1c
        do gaps.%Push(g)
    }
    // influenza immunization within the last year
    set lastFlu = "", il = $classmethod(read, "ResourcesForPatient", patientRef, "Immunization"), it = il.%GetIterator()
    while it.%GetNext(.k, .im) {
        set d = ..DatePart(im.resource.occurrenceDateTime)
        if d ] lastFlu set lastFlu = d
    }
    if (lastFlu = "") || (yearAgo ] lastFlu) {
        set g = {}, g.screening = "Influenza immunization", g.status = "overdue", g.lastDate = lastFlu
        do gaps.%Push(g)
    }
    set o.gaps = gaps, o.count = gaps.%Size()
    return o
}

/// Is there documented follow-up (Task / ServiceRequest / Appointment) for this
/// patient, and what are the abnormal observations?
ClassMethod AbnormalResultFollowupStatus(patientRef As %String) As %DynamicObject
{
    set o = {}, followUps = [], abnormal = []
    set read = "FAST.Runtime.FHIRReadOperation"
    set ptr = 0, types = $listbuild("Task", "ServiceRequest", "Appointment")
    while $listnext(types, ptr, t) {
        set list = $classmethod(read, "ResourcesForPatient", patientRef, t), it = list.%GetIterator()
        while it.%GetNext(.k, .res) { do followUps.%Push(t _ "/" _ res.resourceId) }
    }
    set obs = $classmethod(read, "ResourcesForPatient", patientRef, "Observation"), it = obs.%GetIterator()
    while it.%GetNext(.k, .o2) {
        set ob = o2.resource
        if ..IsAbnormal(ob) {
            set a = {}
            set a.code = $classmethod(read, "CodeText", ob.code)
            set a.value = $select($isobject(ob.valueQuantity): ob.valueQuantity.value, 1: "")
            set a.unit = $select($isobject(ob.valueQuantity): ob.valueQuantity.unit, 1: "")
            set a.date = ..DatePart(ob.effectiveDateTime)
            do abnormal.%Push(a)
        }
    }
    set o.query = "abnormal_result_followup_status"
    set o.hasFollowUp = (followUps.%Size() > 0)
    set o.followUps = followUps
    set o.abnormal = abnormal
    return o
}

/// Gather prior-auth supporting evidence: conditions, medication history with
/// notes, and key observations.
ClassMethod PriorAuthSupportingEvidence(patientRef As %String) As %DynamicObject
{
    set o = {}, conditions = [], meds = [], obsv = []
    set read = "FAST.Runtime.FHIRReadOperation"
    set cl = $classmethod(read, "ResourcesForPatient", patientRef, "Condition"), it = cl.%GetIterator()
    while it.%GetNext(.k, .c) { do conditions.%Push($classmethod(read, "CodeText", c.resource.code)) }
    set ml = $classmethod(read, "ResourcesForPatient", patientRef, "MedicationRequest"), it = ml.%GetIterator()
    while it.%GetNext(.k, .m) {
        set r = m.resource, one = {}
        set one.medication = $classmethod(read, "CodeText", r.medicationCodeableConcept)
        set one.status = r.status
        if $isobject(r.note) && (r.note.%Size() > 0) set one.note = r.note.%Get(0).text
        do meds.%Push(one)
    }
    set ol = $classmethod(read, "ResourcesForPatient", patientRef, "Observation"), it = ol.%GetIterator()
    while it.%GetNext(.k, .ob2) {
        set r = ob2.resource, one = {}
        set one.code = $classmethod(read, "CodeText", r.code)
        set one.value = $select($isobject(r.valueQuantity): r.valueQuantity.value, 1: "")
        set one.unit = $select($isobject(r.valueQuantity): r.valueQuantity.unit, 1: "")
        do obsv.%Push(one)
    }
    set o.query = "prior_auth_supporting_evidence"
    set o.conditions = conditions, o.medications = meds, o.observations = obsv
    return o
}

/// Cohort: diabetic patients with HbA1c > 9 recorded in the last ~6 months.
/// Real FHIR data from the repository. The 6-month window is evaluated as-of the
/// demo dataset's reference date (FAST.Seed.SyntheticData ANCHORDATE), not the wall
/// clock, because the synthetic population is a frozen point-in-time snapshot — so
/// the cohort (and the bundled NL→FHIR LLM cache key) is reproducible on any day.
ClassMethod DiabetesA1cOver9Last6Months() As %DynamicObject
{
    set o = {}, rows = [], read = "FAST.Runtime.FHIRReadOperation"
    set cutoff = $zdate($zdateh($parameter("FAST.Seed.SyntheticData", "ANCHORDATE"), 3) - 183, 3)
    set all = $classmethod(read, "AllOfType", "Observation"), it = all.%GetIterator()
    while it.%GetNext(.k, .ob) {
        set obs = ob.resource
        if '..HasCode(obs.code, ..#LOINCA1C) continue
        if '$isobject(obs.valueQuantity) continue
        set val = obs.valueQuantity.value
        set dt = ..DatePart(obs.effectiveDateTime)
        set pref = $classmethod(read, "PatientRefOf", obs)
        if (val > 9) && (dt ] cutoff) && ..HasDiabetes(pref) {
            set row = {}
            set row.patient = pref
            set row.patientName = ..PatientName(pref)
            set row.a1c = val
            set row.date = dt
            do rows.%Push(row)
        }
    }
    set o.query = "diabetes_a1c_over_9_last_6_months"
    set o.cutoffDate = cutoff
    set o.matches = rows
    set o.count = rows.%Size()
    return o
}

// ---- helpers ----

ClassMethod IsAbnormal(obs As %DynamicObject) As %Boolean
{
    if '$isobject(obs) return 0
    if $isobject(obs.interpretation) && (obs.interpretation.%Size() > 0) {
        set i = obs.interpretation.%Get(0)
        if $isobject(i.coding) && (i.coding.%Size() > 0) {
            set code = i.coding.%Get(0).code
            if (code = "H") || (code = "HH") || (code = "L") || (code = "LL") || (code = "A") return 1
        }
    }
    if $isobject(obs.valueQuantity) && $isobject(obs.referenceRange) && (obs.referenceRange.%Size() > 0) {
        set hi = obs.referenceRange.%Get(0).high
        if $isobject(hi) && (obs.valueQuantity.value > hi.value) return 1
    }
    return 0
}

ClassMethod HasCode(cc As %DynamicObject, code As %String) As %Boolean
{
    if '$isobject(cc) || '$isobject(cc.coding) return 0
    set it = cc.coding.%GetIterator()
    while it.%GetNext(.k, .c) { if c.code = code return 1 }
    return 0
}

ClassMethod HasDiabetes(patientRef As %String) As %Boolean
{
    set cl = ##class(FAST.Runtime.FHIRReadOperation).ResourcesForPatient(patientRef, "Condition"), it = cl.%GetIterator()
    while it.%GetNext(.k, .c) { if ..HasCode(c.resource.code, ..#SNOMEDDIABETES) return 1 }
    return 0
}

ClassMethod PatientName(patientRef As %String) As %String
{
    set pl = ##class(FAST.Runtime.FHIRReadOperation).ResourcesForPatient(patientRef, "Patient")
    if pl.%Size() = 0 return patientRef
    return ##class(FAST.Runtime.FHIRReadOperation).Display("Patient", pl.%Get(0).resource)
}

ClassMethod DatePart(dt As %String) As %String
{
    return $extract(dt, 1, 10)
}

}
