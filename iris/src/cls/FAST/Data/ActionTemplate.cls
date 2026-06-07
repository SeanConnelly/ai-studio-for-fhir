/// A reusable draft FHIR-action template. The LLM authors the values; the
/// runtime fills this skeleton to produce a draft resource that ALWAYS requires
/// human review before it can be committed to the FHIR repository. Agents
/// reference an ActionTemplate by slug (action.templateRef).
/// JSON field names are camelCase to match the rest of the REST API.
Class FAST.Data.ActionTemplate Extends (%Persistent, %JSON.Adaptor)
{

Parameter %JSONIGNORENULL = 1;

Index SlugIdx On Slug [ Unique ];

/// Stable identifier, e.g. "followup-task" or "prior-auth-documentreference".
Property Slug As %String(%JSONFIELDNAME = "slug", MAXLEN = 100) [ Required ];

Property Name As %String(%JSONFIELDNAME = "name", MAXLEN = 200);

/// FHIR resource type produced, e.g. "Task", "ServiceRequest", "DocumentReference".
Property ResourceType As %String(%JSONFIELDNAME = "resourceType", MAXLEN = 60);

/// Draft FHIR resource skeleton as JSON text, with {{variable}} placeholders the
/// LLM/runtime fills.
Property TemplateJSON As %String(%JSONFIELDNAME = "templateJson", MAXLEN = "");

/// Whether committing the resulting draft requires human approval. Always true
/// for clinical/administrative write-backs (kept as a property for transparency).
Property ApprovalRequired As %Boolean(%JSONFIELDNAME = "approvalRequired") [ InitialExpression = 1 ];

Property Description As %String(%JSONFIELDNAME = "description", MAXLEN = 2000);

/// Seeded templates are protected from deletion in the UI.
Property IsSystem As %Boolean(%JSONFIELDNAME = "isSystem") [ InitialExpression = 0 ];

Property CreatedAt As %TimeStamp(%JSONFIELDNAME = "createdAt") [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

Property UpdatedAt As %TimeStamp(%JSONFIELDNAME = "updatedAt") [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

}
