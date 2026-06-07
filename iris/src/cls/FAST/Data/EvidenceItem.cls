/// A piece of evidence gathered during an invocation (FHIR / SQL / vector / context).
Class FAST.Data.EvidenceItem Extends (%Persistent, %JSON.Adaptor)
{

Parameter %JSONIGNORENULL = 1;

Index InvocationIdx On InvocationId;

Property InvocationId As %String(MAXLEN = 100) [ Required ];

Property EvidenceId As %String(MAXLEN = 100);

/// FHIR_RESOURCE | SQL_FACT | KNOWLEDGE_CHUNK | CONTEXT
Property EvidenceType As %String(MAXLEN = 50);

Property Source As %String(MAXLEN = 200);

Property Display As %String(MAXLEN = 2000);

Property Relevance As %String(MAXLEN = 1000);

Property PayloadJSON As %String(MAXLEN = "");

}
