/// Business Operation: draft a FHIR write-back (never auto-commit).
/// Wraps FAST.Runtime.FHIRWritebackOperation.
Class FAST.BO.FHIRWriteback Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

Method Run(pReq As FAST.Msg.OpRequest, Output pResp As FAST.Msg.OpResponse) As %Status
{
    set pResp = ##class(FAST.Msg.OpResponse).%New()
    set p = ##class(FAST.Util.JSON).Parse(pReq.PayloadJSON)
    set res = ##class(FAST.Runtime.FHIRWritebackOperation).Draft(p.invocationId, p.actionType, p.resourceType, p.resource)
    $$$TRACE("DRAFTED " _ p.resourceType _ " (status draft, requires human review) - NOT committed to FHIR; a clinician approves or rejects it")
    set pResp.ResultJSON = ##class(FAST.Util.JSON).ToString(res, 0)
    quit $$$OK
}

XData MessageMap
{
<MapItems>
  <MapItem MessageType="FAST.Msg.OpRequest">
    <Method>Run</Method>
  </MapItem>
</MapItems>
}

}
