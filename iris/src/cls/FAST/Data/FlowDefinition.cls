/// A user-created or template-derived agent flow. Editable; compiles into artefacts.
Class FAST.Data.FlowDefinition Extends (%Persistent, %JSON.Adaptor)
{

Parameter %JSONIGNORENULL = 1;

Index SlugIdx On Slug [ Unique ];

Property Slug As %String(MAXLEN = 100) [ Required ];

Property Name As %String(MAXLEN = 200);

Property Description As %String(MAXLEN = 2000);

Property Version As %String(MAXLEN = 20) [ InitialExpression = "1.0.0" ];

Property DefinitionJSON As %String(MAXLEN = "");

/// Template this flow was created from, if any.
Property SourceTemplateSlug As %String(MAXLEN = 100);

/// draft | compiled | deployed
Property Status As %String(MAXLEN = 30) [ InitialExpression = "draft" ];

Property CreatedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

Property UpdatedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

}
