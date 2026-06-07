/// Orders + Prior Authorisation workflow, driven from the patient chart.
///
/// A clinician places an order from a small demo catalogue; high-cost items
/// require prior authorisation. Placing a PA item:
///   1. writes the order as REAL FHIR (MedicationRequest / ServiceRequest, on-hold),
///   2. runs the prior-auth agent (real evidence + LLM-authored packet),
///   3. writes the evidence packet as a DocumentReference and a Claim
///      (use=preauthorization) referencing the order, coverage and packet.
/// Submitting the PA simulates the payer adjudication: a ClaimResponse is written
/// with outcome/disposition derived honestly from the assembled missing-evidence
/// checklist (empty -> approved; outstanding items -> pended), and the order's
/// status is advanced. Everything is real, openable FHIR; the only simulated part
/// is the payer's decision.
///
/// Resource ids share a sequence so they link without custom references:
///   order  syn-ord-<seq>   claim syn-pa-<seq>
///   packet syn-padoc-<seq> response syn-pacr-<seq>
Class FAST.Runtime.Orders [ Abstract ]
{

/// The demo order catalogue: two medications + two tests, each requiring PA. The
/// last field is the SIMULATED payer decision for the demo (approve / pend) - the
/// only simulated part of the flow; the evidence packet itself is genuine LLM
/// output. Tuple: id $ kind $ display $ system $ code $ requestedService $ outcome
ClassMethod CATALOGUE() [ CodeMode = expression ]
{
$listbuild(
"med-semaglutide$medication$Semaglutide 1mg weekly (GLP-1)$http://www.nlm.nih.gov/research/umls/rxnorm$1991306$Semaglutide (GLP-1 receptor agonist) for weight management$approve",
"med-adalimumab$medication$Adalimumab 40mg (biologic)$http://www.nlm.nih.gov/research/umls/rxnorm$351111$Adalimumab (TNF-inhibitor biologic) therapy$pend",
"test-cgm$test$Continuous glucose monitor (CGM)$http://snomed.info/sct$337388004$Continuous glucose monitoring for poorly-controlled type 2 diabetes$approve",
"test-petct$test$PET-CT whole body$http://snomed.info/sct$82918005$Whole-body PET-CT imaging$pend")
}

/// The catalogue as a JSON array for the UI.
ClassMethod CatalogueJSON() As %DynamicArray
{
    set arr = [], lc = ..CATALOGUE(), ptr = 0
    while $listnext(lc, ptr, row) {
        set o = {}
        set o.id = $piece(row, "$", 1)
        set o.kind = $piece(row, "$", 2)
        set o.display = $piece(row, "$", 3)
        set o.requestedService = $piece(row, "$", 6)
        set o.requiresPA = 1
        do arr.%Push(o)
    }
    return arr
}

/// Look up a catalogue row by id; returns the $-delimited tuple or "".
ClassMethod Item(id As %String) As %String
{
    set lc = ..CATALOGUE(), ptr = 0
    while $listnext(lc, ptr, row) { if $piece(row, "$", 1) = id return row }
    return ""
}

/// Place an order from the catalogue for a patient. Writes the order, runs the
/// prior-auth agent, writes the evidence packet (DocumentReference) + Claim.
/// Returns { ok, orderId, claimId, order:{...}, pa:{...} }.
ClassMethod Place(patientRef As %String, itemId As %String) As %DynamicObject
{
    set row = ..Item(itemId)
    if row = "" { set e = {}, e.ok = 0, e.error = "Unknown catalogue item: " _ itemId  return e }
    set kind = $piece(row, "$", 2), display = $piece(row, "$", 3)
    set system = $piece(row, "$", 4), code = $piece(row, "$", 5), service = $piece(row, "$", 6)
    set pid = $piece(patientRef, "/", *)
    set seq = $increment(^FAST("ordSeq"))

    // 1. the order resource (on hold pending authorisation)
    set orderId = "syn-ord-" _ seq
    if kind = "medication" {
        set ord = {"resourceType": "MedicationRequest", "intent": "order", "status": "on-hold"}
        set ord.id = orderId
        set ord.medicationCodeableConcept = {"coding": [{"system": (system), "code": (code), "display": (display)}], "text": (display)}
        set ord.subject = {"reference": (patientRef)}
        set ord.authoredOn = ..Now()
        set orderType = "MedicationRequest"
    } else {
        set ord = {"resourceType": "ServiceRequest", "intent": "order", "status": "on-hold"}
        set ord.id = orderId
        set ord.code = {"coding": [{"system": (system), "code": (code), "display": (display)}], "text": (display)}
        set ord.subject = {"reference": (patientRef)}
        set ord.authoredOn = ..Now()
        set orderType = "ServiceRequest"
    }
    do ..Put(orderType, orderId, ord)

    // 2. run the prior-auth agent (real evidence + LLM packet)
    set ctx = {}, ctx.requestedService = service
    set pa = ##class(FAST.Runtime.Runtime).RunRecipe("prior-auth", patientRef, ctx)

    // 3. evidence packet -> DocumentReference
    set docId = "syn-padoc-" _ seq
    set doc = {"resourceType": "DocumentReference", "status": "current"}
    set doc.id = docId
    set doc.type = {"text": "Prior Authorisation Evidence Packet"}
    set doc.subject = {"reference": (patientRef)}
    set doc.date = ..Now()
    set doc.description = "Prior authorisation evidence packet for " _ service
    set just = $select($isobject(pa) && (pa.draftJustification '= ""): pa.draftJustification, 1: "")
    set doc.content = [{"attachment": {"contentType": "text/plain", "title": ("Evidence packet - " _ display)}}]
    // base64 requires an 8-bit string; the justification may contain Unicode, so
    // encode its UTF-8 bytes (a wide string would throw <ILLEGAL VALUE>).
    if just '= "" do doc.content.%Get(0).attachment.%Set("data", $system.Encryption.Base64Encode($zconvert(just, "O", "UTF8")))
    do ..Put("DocumentReference", docId, doc)

    // 4. Claim (use=preauthorization), draft, referencing order + coverage + packet
    set claimId = "syn-pa-" _ seq
    set claim = {"resourceType": "Claim", "status": "draft", "use": "preauthorization"}
    set claim.id = claimId
    set claim.type = {"coding": [{"system": "http://terminology.hl7.org/CodeSystem/claim-type", "code": ($select(kind = "medication": "pharmacy", 1: "institutional"))}]}
    set claim.patient = {"reference": (patientRef)}
    set claim.created = ..Now()
    set claim.provider = {"display": "Cedar Valley Health"}
    set claim.priority = {"coding": [{"code": "normal"}]}
    set claim.insurance = [{"sequence": 1, "focal": true, "coverage": {"reference": ("Coverage/" _ pid _ "-cov1")}}]
    set claim.item = [{"sequence": 1, "productOrService": {"coding": [{"system": (system), "code": (code), "display": (display)}], "text": (display)}}]
    // supportingInfo.valueReference accepts any reference, so link both the
    // evidence packet and the originating order here (Claim.referral is typed to
    // ServiceRequest only, so it can't hold a MedicationRequest order).
    set claim.supportingInfo = [{"sequence": 1, "category": {"text": "evidence-packet"}, "valueReference": {"reference": ("DocumentReference/" _ docId)}}, {"sequence": 2, "category": {"text": "order"}, "valueReference": {"reference": (orderType _ "/" _ orderId)}}]
    do ..Put("Claim", claimId, claim)

    set out = {}
    set out.ok = 1
    set out.orderId = orderId
    set out.orderType = orderType
    set out.claimId = claimId
    set out.display = display
    set out.kind = kind
    set out.requestedService = service
    set out.pa = ..PAView(pa)
    return out
}

/// Submit a drafted PA to the payer and simulate the adjudication. Re-runs the
/// prior-auth agent (cache hit -> deterministic) to read the missing-evidence
/// checklist: empty -> approved, otherwise pended. Writes a ClaimResponse and
/// advances the order + claim status. Returns { ok, decision, disposition, ... }.
ClassMethod Submit(claimId As %String) As %DynamicObject
{
    set claim = ..ReadById("Claim", claimId)
    if '$isobject(claim) { set e = {}, e.ok = 0, e.error = "Claim not found: " _ claimId  return e }
    set seq = $piece(claimId, "-", *)
    set patientRef = claim.patient.reference
    set service = "", display = ""
    if $isobject(claim.item) && (claim.item.%Size() > 0) {
        set display = claim.item.%Get(0).productOrService.text
    }
    // recover the requested service from the order/item to re-run the agent
    set row = ..ItemByDisplay(display)
    set service = $select(row '= "": $piece(row, "$", 6), 1: display)
    set approved = ($piece(row, "$", 7) '= "pend")

    set ctx = {}, ctx.requestedService = service
    set pa = ##class(FAST.Runtime.Runtime).RunRecipe("prior-auth", patientRef, ctx)
    set missing = $select($isobject(pa) && $isobject(pa.missingEvidenceChecklist): pa.missingEvidenceChecklist.%Size(), 1: 0)

    // mark the claim submitted
    set claim.status = "active"
    do ..Put("Claim", claimId, claim)

    // ClaimResponse - the simulated payer decision
    set crId = "syn-pacr-" _ seq
    set payer = ..PayerFor(patientRef)
    set cr = {"resourceType": "ClaimResponse", "status": "active", "use": "preauthorization"}
    set cr.id = crId
    set cr.patient = {"reference": (patientRef)}
    set cr.created = ..Now()
    set cr.insurer = {"display": (payer)}
    set cr.request = {"reference": ("Claim/" _ claimId)}
    set cr.type = claim.type
    if approved {
        set cr.outcome = "complete"
        set cr.disposition = "Prior authorisation approved."
        set cr.preAuthRef = "PA-" _ seq
    } else {
        set cr.outcome = "queued"
        set cr.disposition = "Pended - additional information required before a decision can be made."
    }
    do ..Put("ClaimResponse", crId, cr)

    // advance the order status (order shares the claim's sequence; try both types)
    set ord = ..ReadById("MedicationRequest", "syn-ord-" _ seq)
    if '$isobject(ord) set ord = ..ReadById("ServiceRequest", "syn-ord-" _ seq)
    if $isobject(ord) {
        set ord.status = $select(approved: "active", 1: "on-hold")
        do ..Put(ord.resourceType, ord.id, ord)
    }

    set out = {}
    set out.ok = 1
    set out.claimId = claimId
    set out.decision = $select(approved: "approved", 1: "pended")
    set out.outcome = cr.outcome
    set out.disposition = cr.disposition
    set out.payer = payer
    set out.missingCount = missing
    if 'approved && $isobject(pa.missingEvidenceChecklist) set out.missing = pa.missingEvidenceChecklist
    return out
}

/// All orders for a patient, with PA status. Returns { patientRef, orders:[...] }.
ClassMethod ListForPatient(patientRef As %String) As %DynamicObject
{
    set read = "FAST.Runtime.FHIRReadOperation"
    // index claims + responses for this patient by their sequence
    set claims = {}, responses = {}
    set cl = $classmethod(read, "ResourcesForPatient", patientRef, "Claim"), it = cl.%GetIterator()
    while it.%GetNext(.k, .o) { do claims.%Set($piece(o.resource.id, "-", *), o.resource) }
    set rl = $classmethod(read, "ResourcesForPatient", patientRef, "ClaimResponse"), it = rl.%GetIterator()
    while it.%GetNext(.k, .o) { do responses.%Set($piece(o.resource.request.reference, "-", *), o.resource) }

    set orders = []
    do ..CollectOrders(patientRef, "MedicationRequest", claims, responses, orders)
    do ..CollectOrders(patientRef, "ServiceRequest", claims, responses, orders)

    set out = {}, out.patientRef = patientRef, out.orders = orders
    return out
}

ClassMethod CollectOrders(patientRef As %String, type As %String, claims As %DynamicObject, responses As %DynamicObject, orders As %DynamicArray)
{
    set read = "FAST.Runtime.FHIRReadOperation"
    set l = $classmethod(read, "ResourcesForPatient", patientRef, type), it = l.%GetIterator()
    while it.%GetNext(.k, .o) {
        set res = o.resource
        set row = {}
        set row.id = res.id
        set row.kind = $select(type = "MedicationRequest": "medication", 1: "test")
        set row.display = $classmethod(read, "Display", type, res)
        set row.status = res.status
        set row.date = $piece($select(type = "MedicationRequest": res.authoredOn, 1: res.authoredOn), "T", 1)
        // link a PA claim by shared sequence (syn-ord-<seq> <-> syn-pa-<seq>)
        set seq = $piece(res.id, "-", *)
        if (res.id [ "syn-ord-") && $isobject(claims.%Get(seq)) {
            set claim = claims.%Get(seq)
            set pa = {}
            set pa.claimId = claim.id
            set resp = responses.%Get(seq)
            if $isobject(resp) {
                set pa.status = $select(resp.outcome = "complete": "approved", 1: "pended")
                set pa.disposition = resp.disposition
            } else {
                set pa.status = $select(claim.status = "active": "submitted", 1: "draft")
            }
            set row.pa = pa
        }
        do orders.%Push(row)
    }
}

/// The PA queue across all patients: every preauthorisation Claim with its status.
ClassMethod Queue() As %DynamicObject
{
    set read = "FAST.Runtime.FHIRReadOperation"
    set all = $classmethod(read, "AllOfType", "Claim")
    // index responses by claim sequence
    set responses = {}, rl = $classmethod(read, "AllOfType", "ClaimResponse"), it = rl.%GetIterator()
    while it.%GetNext(.k, .o) { do responses.%Set($piece(o.resource.request.reference, "-", *), o.resource) }
    set rows = [], it = all.%GetIterator()
    while it.%GetNext(.k, .o) {
        set c = o.resource
        if c.use '= "preauthorization" continue
        set seq = $piece(c.id, "-", *)
        set row = {}
        set row.claimId = c.id
        set row.patientRef = c.patient.reference
        set row.patientId = $piece(c.patient.reference, "/", *)
        set row.item = $select($isobject(c.item) && (c.item.%Size() > 0): c.item.%Get(0).productOrService.text, 1: "")
        set resp = responses.%Get(seq)
        if $isobject(resp) {
            set row.status = $select(resp.outcome = "complete": "approved", 1: "pended")
            set row.disposition = resp.disposition
        } else {
            set row.status = $select(c.status = "active": "submitted", 1: "draft")
        }
        set row.patientName = ..PatientName(c.patient.reference)
        do rows.%Push(row)
    }
    set out = {}, out.queue = rows, out.count = rows.%Size()
    return out
}

// ---- helpers ----

/// Normalise the agent result to the fields the UI needs.
ClassMethod PAView(pa As %DynamicObject) As %DynamicObject
{
    set v = {}
    if '$isobject(pa) { set v.available = 0  return v }
    set v.available = $select(pa.source [ "deterministic": 0, 1: 1)
    set v.source = pa.source
    set v.summary = pa.summary
    set v.requestedService = pa.requestedService
    set v.draftJustification = pa.draftJustification
    set v.policyCriteriaMatched = $select($isobject(pa.policyCriteriaMatched): pa.policyCriteriaMatched, 1: [])
    set v.missingEvidenceChecklist = $select($isobject(pa.missingEvidenceChecklist): pa.missingEvidenceChecklist, 1: [])
    return v
}

/// The catalogue tuple whose display matches, or "".
ClassMethod ItemByDisplay(display As %String) As %String
{
    set lc = ..CATALOGUE(), ptr = 0
    while $listnext(lc, ptr, row) { if $piece(row, "$", 3) = display return row }
    return ""
}

ClassMethod PayerFor(patientRef As %String) As %String
{
    set cov = $classmethod("FAST.Runtime.FHIRReadOperation", "ResourcesForPatient", patientRef, "Coverage")
    if cov.%Size() > 0 {
        set c = cov.%Get(0).resource
        if $isobject(c.payor) && (c.payor.%Size() > 0) && (c.payor.%Get(0).display '= "") return c.payor.%Get(0).display
    }
    return "NHS England"
}

ClassMethod PatientName(patientRef As %String) As %String
{
    set pl = $classmethod("FAST.Runtime.FHIRReadOperation", "ResourcesForPatient", patientRef, "Patient")
    if pl.%Size() > 0 return $classmethod("FAST.Runtime.FHIRReadOperation", "Display", "Patient", pl.%Get(0).resource)
    return patientRef
}

/// Read a single resource by type + id from the FHIR repository.
ClassMethod ReadById(type As %String, id As %String) As %DynamicObject
{
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT ResourceString FROM HSFHIR_X0001_R.Rsrc WHERE ResourceType = ? AND ResourceId = ? AND Deleted = 0", type, id)
    if rs.%Next() return ##class(FAST.Util.JSON).Parse(rs.%Get("ResourceString"))
    return ""
}

/// PUT one resource into the FHIR repository (loopback), preserving the id.
ClassMethod Put(type As %String, id As %String, res As %DynamicObject)
{
    set batch = []
    set item = {}, item.resourceType = type, item.resourceId = id
    do item.%Set("resource", res)
    do batch.%Push(item)
    do ##class(FAST.Seed.SeedLoader).PutBundle(batch)
}

ClassMethod Now() As %String
{
    return $translate($zdatetime($ztimestamp, 3), " ", "T") _ "Z"
}

}
