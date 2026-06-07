/// Record of a template/flow import or export event.
Class FAST.Data.ImportExportJob Extends (%Persistent, %JSON.Adaptor)
{

Parameter %JSONIGNORENULL = 1;

/// import | export
Property JobType As %String(MAXLEN = 20);

/// template | flow | bundle
Property EntityType As %String(MAXLEN = 30);

Property EntitySlug As %String(MAXLEN = 100);

/// ok | error
Property Status As %String(MAXLEN = 30);

Property Message As %String(MAXLEN = 2000);

Property PayloadJSON As %String(MAXLEN = "");

Property CreatedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

}
