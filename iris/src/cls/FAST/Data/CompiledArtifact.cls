/// One compiler output (recipe.json, prompt.md, module.xml, ...) for a flow.
Class FAST.Data.CompiledArtifact Extends (%Persistent, %JSON.Adaptor)
{

Parameter %JSONIGNORENULL = 1;

Index FlowIdx On FlowSlug;

Index FlowArtifactIdx On (FlowSlug, ArtifactName) [ Unique ];

Property FlowSlug As %String(MAXLEN = 100) [ Required ];

/// e.g. recipe.json, prompt.md, output-schema.json, fhir-action-template.json,
/// production-settings.json, healthconnect-mapping.json, module.xml
Property ArtifactName As %String(MAXLEN = 100) [ Required ];

/// json | markdown | xml
Property ArtifactType As %String(MAXLEN = 30);

Property ContentType As %String(MAXLEN = 100) [ InitialExpression = "application/json" ];

Property Content As %String(MAXLEN = "");

Property Version As %String(MAXLEN = 20) [ InitialExpression = "1.0.0" ];

Property CreatedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

}
