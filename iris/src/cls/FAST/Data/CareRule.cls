/// A preventative-care rule: a saved, AI-authored cohort query over the real FHIR
/// repository. Authored in the Studio (a plain-English description -> the NL->FHIR
/// agent writes the read-only SQL), then run on the clinical Preventative Care
/// worklist to surface the matching patients. The SQL is validated read-only and
/// executed live each run.
Class FAST.Data.CareRule Extends (%Persistent, %JSON.Adaptor)
{

Parameter %JSONIGNORENULL = 1;

Index SlugIdx On Slug [ Unique ];

Property Slug As %String(MAXLEN = 100) [ Required ];

Property Name As %String(MAXLEN = 200);

/// The plain-English cohort definition the clinician/admin entered.
Property Description As %String(MAXLEN = 1000);

/// The AI-generated, read-only SQL over the FHIR projections.
Property SQL As %String(MAXLEN = "");

/// One-sentence explanation of what the query returns.
Property Explanation As %String(MAXLEN = 1000);

/// "cached" / "live (...)" / "deterministic" - how the SQL was authored.
Property Source As %String(MAXLEN = 60);

/// Seeded example rules vs user-authored.
Property IsSystem As %Boolean [ InitialExpression = 0 ];

Property CreatedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

}
