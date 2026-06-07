/// One step in a runtime trace, styled around HealthConnect Business
/// Service / Process / Operation vocabulary.
Class FAST.Data.TraceStep Extends (%Persistent, %JSON.Adaptor)
{

Parameter %JSONIGNORENULL = 1;

Index TraceIdx On TraceId;

Index TraceStepIdx On (TraceId, StepNumber);

Property TraceId As %String(MAXLEN = 100) [ Required ];

Property StepNumber As %Integer;

/// BusinessService | BusinessProcess | BusinessOperation
Property ComponentType As %String(MAXLEN = 50);

/// e.g. AgentTriggerService, FHIRReadOperation
Property ComponentName As %String(MAXLEN = 100);

/// ok | drafted | warning | error
Property Status As %String(MAXLEN = 30);

Property Detail As %String(MAXLEN = 4000);

Property PayloadJSON As %String(MAXLEN = "");

Property StartedAt As %TimeStamp;

Property CompletedAt As %TimeStamp;

Property DurationMs As %Integer;

}
