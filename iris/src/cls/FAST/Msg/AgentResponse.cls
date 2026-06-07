/// The assembled agent response returned from the production.
Class FAST.Msg.AgentResponse Extends Ens.Response
{

Property ResponseJSON As %String(MAXLEN = "");

Property RequestId As %String(MAXLEN = 100);

Property TraceId As %String(MAXLEN = 100);

}
