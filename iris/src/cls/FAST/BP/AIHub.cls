/// Business Process: agent reasoning. Assembles the prompt from the gathered
/// evidence, sends the outbound LLM call to the LLMService Business Operation as
/// a real FAST.Msg.LLMRequest (the egress leg in the Visual Trace), and returns
/// the finalized structured result. A PROCESS rather than an operation because it
/// orchestrates a downstream egress operation - the HealthConnect-correct shape:
/// operations talk to external systems; anything that routes onward is a process.
Class FAST.BP.AIHub Extends Ens.BusinessProcess
{

Method OnRequest(pReq As FAST.Msg.OpRequest, Output pResp As FAST.Msg.OpResponse) As %Status
{
    set pResp = ##class(FAST.Msg.OpResponse).%New()
    set ctx = ##class(FAST.Util.JSON).Parse(pReq.PayloadJSON)
    // hand Generate this host so the LLM call itself travels as a REAL Ens
    // message to the LLMService operation (visible in the Visual Trace)
    do ctx.%Set("ensHost", $this)
    set res = ##class(FAST.Runtime.AIHubOperation).Generate(ctx)
    set src = $select($isobject(res.aiTrace): res.aiTrace.source, 1: res.source)
    $$$TRACE("Reasoning complete for '" _ ctx.recipeId _ "' - AI source=" _ src _ $select(src = "deterministic": " (NOT AI - the plain-code fallback, labelled honestly in the UI)", 1: ""))
    set pResp.ResultJSON = ##class(FAST.Util.JSON).ToString(res, 0)
    quit $$$OK
}

/// Declare the downstream target so the production configuration diagram draws
/// the AIHub -> LLMService connection.
ClassMethod OnGetConnections(Output pArray As %String, pItem As Ens.Config.Item)
{
    do ##super(.pArray, pItem)
    set pArray("LLMService") = ""
}

}
