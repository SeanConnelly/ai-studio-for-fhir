/// Generic operation request sent from the orchestrator to a Business Operation.
Class FAST.Msg.OpRequest Extends Ens.Request
{

Property Op As %String(MAXLEN = 50);

Property PayloadJSON As %String(MAXLEN = "");

}
