/// Business Operation: native IRIS Vector Search. Wraps FAST.Runtime.VectorSearchOperation.
Class FAST.BO.VectorSearch Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

Method Run(pReq As FAST.Msg.OpRequest, Output pResp As FAST.Msg.OpResponse) As %Status
{
    set pResp = ##class(FAST.Msg.OpResponse).%New()
    set p = ##class(FAST.Util.JSON).Parse(pReq.PayloadJSON)
    set topK = $select(p.topK="": 3, 1: +p.topK)
    set res = ##class(FAST.Runtime.VectorSearchOperation).Search(p.collection, p.queryText, topK)
    // the SQL VECTOR_DOT_PRODUCT ranking is always live; the QUERY embedding
    // resolves through the same record/replay seam as completions
    $$$TRACE("LIVE VECTOR_DOT_PRODUCT search over '" _ p.collection _ "' (top " _ topK _ ") - " _ res.%Size() _ " chunk(s); query embedding source=" _ $get(^FAST("llm", "embedLastSource"), "?"))
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
