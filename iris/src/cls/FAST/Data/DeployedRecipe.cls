/// A compiled recipe registered for execution by the runtime.
Class FAST.Data.DeployedRecipe Extends (%Persistent, %JSON.Adaptor)
{

Parameter %JSONIGNORENULL = 1;

Index RecipeIdx On RecipeId [ Unique ];

Index FlowIdx On FlowSlug;

Property RecipeId As %String(MAXLEN = 100) [ Required ];

Property FlowSlug As %String(MAXLEN = 100) [ Required ];

Property RecipeJSON As %String(MAXLEN = "");

Property IsActive As %Boolean [ InitialExpression = 1 ];

Property Version As %String(MAXLEN = 20) [ InitialExpression = "1.0.0" ];

Property DeployedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

}
