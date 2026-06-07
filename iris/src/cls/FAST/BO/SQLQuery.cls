/// Business Operation: run a named SQL/cohort query. Wraps FAST.Runtime.SQLQueryOperation.
Class FAST.BO.SQLQuery Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

Method Run(pReq As FAST.Msg.OpRequest, Output pResp As FAST.Msg.OpResponse) As %Status
{
    set pResp = ##class(FAST.Msg.OpResponse).%New()
    set p = ##class(FAST.Util.JSON).Parse(pReq.PayloadJSON)
    set res = ##class(FAST.Runtime.SQLQueryOperation).Run(p.name, p.patientRef)
    $$$TRACE("LIVE query '" _ p.name _ "' over the FHIR repository" _ $select(res.%IsDefined("count"): " - " _ (+res.count) _ " fact(s)", 1: "") _ ". Evidence is always fetched live; only LLM completions use the record/replay cache.")
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
