/// A patient on a preventative-care worklist (register). Entries persist between
/// visits; "Update worklist" runs the rule and appends any newly-matching patients
/// not already on the list. One row per (rule, patient).
Class FAST.Data.WorklistEntry Extends (%Persistent, %JSON.Adaptor)
{

Index RulePatientIdx On (RuleSlug, PatientRef) [ Unique ];

Index RuleIdx On RuleSlug;

Property RuleSlug As %String(MAXLEN = 100) [ Required ];

Property PatientRef As %String(MAXLEN = 100);

Property PatientName As %String(MAXLEN = 200);

Property Detail As %String(MAXLEN = 500);

Property AddedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

}
