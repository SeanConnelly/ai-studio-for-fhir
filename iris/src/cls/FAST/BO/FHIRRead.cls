/// Business Operation: gather FHIR evidence. Wraps FAST.Runtime.FHIRReadOperation.
Class FAST.BO.FHIRRead Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

Method Run(pReq As FAST.Msg.OpRequest, Output pResp As FAST.Msg.OpResponse) As %Status
{
    set pResp = ##class(FAST.Msg.OpResponse).%New()
    set p = ##class(FAST.Util.JSON).Parse(pReq.PayloadJSON)
    set res = ##class(FAST.Runtime.FHIRReadOperation).Gather(p.patientRef, p.resourceTypes)
    $$$TRACE("LIVE read from the FHIR repository for " _ p.patientRef _ " - " _ (+res.count) _ " resource(s). Evidence is always fetched live; only LLM completions use the record/replay cache.")
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
