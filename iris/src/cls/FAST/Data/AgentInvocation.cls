/// One runtime execution of a deployed recipe (the AgentRequest/AgentResponse record).
Class FAST.Data.AgentInvocation Extends (%Persistent, %JSON.Adaptor)
{

Parameter %JSONIGNORENULL = 1;

Index RequestIdx On RequestId [ Unique ];

Index FlowIdx On FlowSlug;

Property RequestId As %String(MAXLEN = 100) [ Required ];

Property RecipeId As %String(MAXLEN = 100);

Property FlowSlug As %String(MAXLEN = 100);

Property TriggerType As %String(MAXLEN = 50);

Property PatientId As %String(MAXLEN = 100);

Property ContextJSON As %String(MAXLEN = "");

/// running | needs_review | completed | error
Property Status As %String(MAXLEN = 30);

Property Summary As %String(MAXLEN = 4000);

Property ResponseJSON As %String(MAXLEN = "");

Property TraceId As %String(MAXLEN = 100);

Property StartedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

Property CompletedAt As %TimeStamp;

}
