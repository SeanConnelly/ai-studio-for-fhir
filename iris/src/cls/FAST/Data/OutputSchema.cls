/// The structured result contract an agent's LLM output must satisfy, plus the
/// key of the clinician renderer that displays it. Both SPAs render an agent
/// result by looking up its OutputSchema's RendererKey, so the Studio's run
/// preview shows exactly what the Clinical app shows.
/// JSON field names are camelCase to match the rest of the REST API.
Class FAST.Data.OutputSchema Extends (%Persistent, %JSON.Adaptor)
{

Parameter %JSONIGNORENULL = 1;

Index SlugIdx On Slug [ Unique ];

/// Stable identifier, e.g. "results-followup-result".
Property Slug As %String(%JSONFIELDNAME = "slug", MAXLEN = 100) [ Required ];

Property Name As %String(%JSONFIELDNAME = "name", MAXLEN = 200);

/// JSON Schema (or a simplified field contract) describing the result shape.
Property SchemaJSON As %String(%JSONFIELDNAME = "schemaJson", MAXLEN = "");

/// Which shared result component renders this schema, e.g. "summary",
/// "criteria-checklist", "query-result", "risk-band", "lab-trend".
Property RendererKey As %String(%JSONFIELDNAME = "rendererKey", MAXLEN = 60);

Property Description As %String(%JSONFIELDNAME = "description", MAXLEN = 2000);

/// Seeded schemas are protected from deletion in the UI.
Property IsSystem As %Boolean(%JSONFIELDNAME = "isSystem") [ InitialExpression = 0 ];

Property CreatedAt As %TimeStamp(%JSONFIELDNAME = "createdAt") [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

Property UpdatedAt As %TimeStamp(%JSONFIELDNAME = "updatedAt") [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

}
