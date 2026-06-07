/// Audit record of a human review decision on a proposed (draft) FHIR action.
/// Every approve/reject/edit of a draft write-back is recorded here, and an
/// approved commit also writes a FHIR Provenance resource. This is the audit
/// trail the contest asks for around agent-proposed data changes.
/// JSON field names are camelCase to match the rest of the REST API.
Class FAST.Data.ApprovalAudit Extends (%Persistent, %JSON.Adaptor)
{

Parameter %JSONIGNORENULL = 1;

Index InvocationIdx On InvocationId;

/// The AgentInvocation.RequestId that produced the action.
Property InvocationId As %String(%JSONFIELDNAME = "invocationId", MAXLEN = 100);

/// The ProposedAction this decision applies to.
Property ActionId As %String(%JSONFIELDNAME = "actionId", MAXLEN = 100);

/// approved | rejected | edited
Property Decision As %String(%JSONFIELDNAME = "decision", MAXLEN = 20);

/// Who reviewed it (free text / user id for the demo).
Property Reviewer As %String(%JSONFIELDNAME = "reviewer", MAXLEN = 200);

/// Reference of the resource committed to the FHIR repo on approval, e.g.
/// "Task/123". Empty for rejected.
Property CommittedResourceRef As %String(%JSONFIELDNAME = "committedResourceRef", MAXLEN = 200);

/// Reviewer note / justification.
Property Note As %String(%JSONFIELDNAME = "note", MAXLEN = 2000);

/// The resource JSON as committed (post-edit), for the audit record.
Property CommittedJSON As %String(%JSONFIELDNAME = "committedJson", MAXLEN = "");

Property Timestamp As %TimeStamp(%JSONFIELDNAME = "timestamp") [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

}
