/// A drafted FHIR write-back proposed by an invocation. Never auto-committed.
Class FAST.Data.ProposedAction Extends (%Persistent, %JSON.Adaptor)
{

Parameter %JSONIGNORENULL = 1;

Index InvocationIdx On InvocationId;

Property InvocationId As %String(MAXLEN = 100) [ Required ];

/// FHIR_CREATE | FHIR_UPDATE | READ_ONLY
Property ActionType As %String(MAXLEN = 50);

Property ResourceType As %String(MAXLEN = 50);

Property RequiresApproval As %Boolean [ InitialExpression = 1 ];

/// draft | needs_review | approved | rejected
Property Status As %String(MAXLEN = 30) [ InitialExpression = "draft" ];

Property ResourceJSON As %String(MAXLEN = "");

Property CreatedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

}
