/// A reusable, database-backed agent workflow template.
/// The twelve contest workflows are stored as system templates.
Class FAST.Data.Template Extends (%Persistent, %JSON.Adaptor)
{

Parameter %JSONIGNORENULL = 1;

Index SlugIdx On Slug [ Unique ];

/// Stable identifier, e.g. "results-followup".
Property Slug As %String(MAXLEN = 100) [ Required ];

Property Name As %String(MAXLEN = 200);

Property Category As %String(MAXLEN = 100);

Property Description As %String(MAXLEN = 2000);

Property Version As %String(MAXLEN = 20) [ InitialExpression = "1.0.0" ];

/// Full template definition (trigger/evidence/agent/action/testCase) as JSON text.
Property DefinitionJSON As %String(MAXLEN = "");

Property IsSystemTemplate As %Boolean [ InitialExpression = 1 ];

Property CreatedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

Property UpdatedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

}
