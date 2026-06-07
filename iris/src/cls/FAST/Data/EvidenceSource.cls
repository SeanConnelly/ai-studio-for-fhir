/// A reusable, parameter-bound evidence-gathering step. The generic
/// FAST.Runtime.EvidenceEngine executes one of these given a patient reference and
/// the agent's input values; an agent composes an ordered list of EvidenceSource
/// refs (with input bindings) in its definition. This replaces the hardcoded
/// per-recipe query switch with a data-driven, mixable component.
/// JSON field names are camelCase to match the rest of the REST API.
Class FAST.Data.EvidenceSource Extends (%Persistent, %JSON.Adaptor)
{

Parameter %JSONIGNORENULL = 1;

Index SlugIdx On Slug [ Unique ];

/// Stable identifier, e.g. "abnormal-observations" or "payer-policy-search".
Property Slug As %String(%JSONFIELDNAME = "slug", MAXLEN = 100) [ Required ];

Property Name As %String(%JSONFIELDNAME = "name", MAXLEN = 200);

/// How this evidence is gathered:
///   fhir-gather  — read named resource types for the patient
///   fhir-search  — FHIR search expression
///   sql          — parameterised read-only SQL (guarded by FAST.Util.SqlGuard)
///   vector       — native IRIS Vector Search over a KnowledgeDocument collection
///   terminology  — resolve clinical text to coded concepts
///   everything   — compact $everything-style bundle for the patient
Property Kind As %String(%JSONFIELDNAME = "kind", MAXLEN = 30) [ Required ];

/// Kind-specific spec as JSON text. Examples:
///   fhir-gather  { "resourceTypes": ["Observation","Condition"] }
///   sql          { "sql": "SELECT ... WHERE patient = :patientRef", "binds": ["patientRef"] }
///   vector       { "collection": "payer_policies", "queryFrom": "input.question", "topK": 5 }
///   terminology  { "textFrom": "input.term", "system": "SNOMED" }
Property Spec As %String(%JSONFIELDNAME = "spec", MAXLEN = "");

Property Description As %String(%JSONFIELDNAME = "description", MAXLEN = 2000);

/// Seeded sources are protected from deletion in the UI.
Property IsSystem As %Boolean(%JSONFIELDNAME = "isSystem") [ InitialExpression = 0 ];

Property CreatedAt As %TimeStamp(%JSONFIELDNAME = "createdAt") [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

Property UpdatedAt As %TimeStamp(%JSONFIELDNAME = "updatedAt") [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

}
