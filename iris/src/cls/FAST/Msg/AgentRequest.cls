/// Inbound agent request flowing into the production.
Class FAST.Msg.AgentRequest Extends Ens.Request
{

Property RecipeId As %String(MAXLEN = 100);

Property PatientRef As %String(MAXLEN = 100);

Property ContextJSON As %String(MAXLEN = "");

/// Force this run to bypass the bundled response corpus: with a key the LLM
/// call goes live; without one the run falls back to the deterministic
/// (non-AI) scaffold, honestly labelled. Carried OUTSIDE ContextJSON so it can
/// never enter a prompt (and therefore never shifts a cache key).
Property NoCache As %Boolean [ InitialExpression = 0 ];

}
