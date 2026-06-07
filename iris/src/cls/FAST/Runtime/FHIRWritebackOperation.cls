/// HealthConnect-style Business Operation: drafts a FHIR write-back as a
/// ProposedAction. Never commits — drafts require human review.
Class FAST.Runtime.FHIRWritebackOperation [ Abstract ]
{

/// Persist a proposed action and return a summary object.
ClassMethod Draft(invocationId As %String, actionType As %String, resourceType As %String, resource As %DynamicObject, requiresApproval As %Boolean = 1) As %DynamicObject
{
    set pa = ##class(FAST.Data.ProposedAction).%New()
    set pa.InvocationId = invocationId
    set pa.ActionType = actionType
    set pa.ResourceType = resourceType
    set pa.RequiresApproval = requiresApproval
    set pa.Status = $select(requiresApproval: "needs_review", 1: "draft")
    set pa.ResourceJSON = ##class(FAST.Util.JSON).ToString(resource, 0)
    do pa.%Save()
    set o = {}
    set o.actionType = actionType
    set o.resourceType = resourceType
    set o.requiresApproval = requiresApproval
    set o.status = pa.Status
    set o.resource = resource
    return o
}

}
