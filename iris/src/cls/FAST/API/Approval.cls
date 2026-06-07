/// Human-in-the-loop approval of agent-proposed (draft) FHIR write-backs. Approving
/// commits the draft to the REAL FHIR R4 repository (guarded, server-assigned id),
/// writes a FHIR Provenance linking the committed resource to the agent activity,
/// and records a FAST.Data.ApprovalAudit row. Rejecting records the decision only.
/// Nothing is ever committed without an explicit approve call.
Class FAST.API.Approval [ Abstract ]
{

/// POST /invocations/:id/actions/:actionId/approve
/// Body (optional): { reviewer, note, resource } — `resource` overrides the draft
/// (the reviewer edited it before approving → decision "edited").
ClassMethod Approve(invocationId As %String, actionId As %String) As %Status
{
    set pa = ##class(FAST.Data.ProposedAction).%OpenId(actionId)
    if '$isobject(pa) return ##class(FAST.Util.Response).Error("Proposed action not found: " _ actionId, "404 Not Found")
    if pa.InvocationId '= invocationId return ##class(FAST.Util.Response).Error("Action does not belong to invocation " _ invocationId, "400 Bad Request")
    if pa.Status = "approved" return ##class(FAST.Util.Response).Error("This action was already approved", "409 Conflict")

    set body = ##class(FAST.Util.Response).Body()
    set reviewer = $select($isobject(body) && (body.reviewer '= ""): body.reviewer, 1: "clinician")
    set note = $select($isobject(body): body.note, 1: "")
    set edited = ($isobject(body) && $isobject(body.resource))
    set res = $select(edited: body.resource, 1: ##class(FAST.Util.JSON).Parse(pa.ResourceJSON))
    if '$isobject(res) return ##class(FAST.Util.Response).Error("Draft resource is not valid JSON", "400 Bad Request")

    // normalise any "YYYY-MM-DD HH:MM:SS" values to valid FHIR dateTime so a draft
    // (incl. bundled cached drafts) commits cleanly to the validating FHIR server
    do ..NormalizeDateTimes(res)

    // commit to the real FHIR repository (server-assigned id)
    set ref = ##class(FAST.Seed.SeedLoader).PostFHIR(pa.ResourceType, res)
    if (ref = "") || (ref [ "/?") return ##class(FAST.Util.Response).Error("FHIR commit failed for " _ pa.ResourceType, "502 Bad Gateway")

    // Provenance: link the committed resource to the agent activity
    do ..WriteProvenance(ref, invocationId, reviewer)

    set pa.Status = "approved"
    set pa.ResourceJSON = ##class(FAST.Util.JSON).ToString(res, 0)
    do pa.%Save()

    set decision = $select(edited: "edited", 1: "approved")
    do ..Audit(invocationId, actionId, decision, reviewer, ref, note, pa.ResourceJSON)

    set o = {}, o.invocationId = invocationId, o.actionId = actionId
    set o.decision = decision, o.committedResourceRef = ref, o.status = "approved"
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// POST /invocations/:id/actions/:actionId/reject — records the decision only.
ClassMethod Reject(invocationId As %String, actionId As %String) As %Status
{
    set pa = ##class(FAST.Data.ProposedAction).%OpenId(actionId)
    if '$isobject(pa) return ##class(FAST.Util.Response).Error("Proposed action not found: " _ actionId, "404 Not Found")
    if pa.InvocationId '= invocationId return ##class(FAST.Util.Response).Error("Action does not belong to invocation " _ invocationId, "400 Bad Request")
    set body = ##class(FAST.Util.Response).Body()
    set reviewer = $select($isobject(body) && (body.reviewer '= ""): body.reviewer, 1: "clinician")
    set note = $select($isobject(body): body.note, 1: "")

    set pa.Status = "rejected"
    do pa.%Save()
    do ..Audit(invocationId, actionId, "rejected", reviewer, "", note, "")

    set o = {}, o.invocationId = invocationId, o.actionId = actionId, o.decision = "rejected", o.status = "rejected"
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// GET /invocations/:id/audit — the audit trail for an invocation.
ClassMethod AuditTrail(invocationId As %String) As %Status
{
    set arr = []
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT ActionId, Decision, Reviewer, CommittedResourceRef, Note, Timestamp FROM FAST_Data.ApprovalAudit WHERE InvocationId = ? ORDER BY Timestamp", invocationId)
    while rs.%Next() {
        set a = {}
        set a.actionId = rs.%Get("ActionId")
        set a.decision = rs.%Get("Decision")
        set a.reviewer = rs.%Get("Reviewer")
        set a.committedResourceRef = rs.%Get("CommittedResourceRef")
        set a.note = rs.%Get("Note")
        set a.timestamp = rs.%Get("Timestamp")
        do arr.%Push(a)
    }
    set o = {}, o.invocationId = invocationId, o.audit = arr, o.count = arr.%Size()
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// Recursively normalise FHIR dateTime-ish string values: "YYYY-MM-DD HH:MM:SS"
/// → "YYYY-MM-DDTHH:MM:SSZ" (the validating FHIR server rejects the space form).
/// Walks objects and arrays in place.
ClassMethod NormalizeDateTimes(node As %DynamicAbstractObject)
{
    if '$isobject(node) return
    set it = node.%GetIterator()
    while it.%GetNext(.key, .val) {
        if $isobject(val) {
            do ..NormalizeDateTimes(val)
        } elseif ($isvalidnum(val) = 0) && ($length(val) = 19) && ($extract(val, 11) = " ") {
            // shape "0000-00-00 00:00:00"
            if $extract(val, 5) = "-", $extract(val, 8) = "-", $extract(val, 14) = ":", $extract(val, 17) = ":" {
                do node.%Set(key, $translate(val, " ", "T") _ "Z")
            }
        }
    }
}

/// Write an ApprovalAudit row.
ClassMethod Audit(invocationId As %String, actionId As %String, decision As %String, reviewer As %String, ref As %String, note As %String, committedJson As %String)
{
    set au = ##class(FAST.Data.ApprovalAudit).%New()
    set au.InvocationId = invocationId
    set au.ActionId = actionId
    set au.Decision = decision
    set au.Reviewer = reviewer
    set au.CommittedResourceRef = ref
    set au.Note = note
    set au.CommittedJSON = committedJson
    do au.%Save()
}

/// Commit a FHIR Provenance resource recording that an agent activity (reviewed by
/// `reviewer`) produced the committed resource. Best-effort.
ClassMethod WriteProvenance(targetRef As %String, invocationId As %String, reviewer As %String)
{
    set prov = {}
    set prov.resourceType = "Provenance"
    set prov.target = [ {} ]
    do prov.target.%Get(0).%Set("reference", targetRef)
    set prov.recorded = $translate($zdatetime($ztimestamp, 3), " ", "T") _ "Z"
    set prov.activity = {}
    set prov.activity.text = "Agent-proposed draft, approved by human reviewer (invocation " _ invocationId _ ")"
    set agent = {}
    set agent.who = {}
    set agent.who.display = reviewer
    set prov.agent = [ (agent) ]
    do ##class(FAST.Seed.SeedLoader).PostFHIR("Provenance", prov)
}

}
