/// Business Service: entry point. Receives an AgentRequest and hands it to the
/// orchestrator process. Adapterless — driven programmatically (REST) via Ens.Director.
Class FAST.BS.AgentTriggerService Extends Ens.BusinessService
{

Parameter ADAPTER = "";

Method OnProcessInput(pInput As FAST.Msg.AgentRequest, Output pOutput As FAST.Msg.AgentResponse) As %Status
{
    quit ..SendRequestSync("AgentOrchestrator", pInput, .pOutput)
}

/// Declare the downstream target so the production configuration diagram draws
/// the connection.
ClassMethod OnGetConnections(Output pArray As %String, pItem As Ens.Config.Item)
{
    do ##super(.pArray, pItem)
    set pArray("AgentOrchestrator") = ""
}

}
