/// A seeded clinical-terminology concept: free-text synonyms mapped to a coded
/// concept (SNOMED CT / LOINC / RxNorm / ICD-10). FAST.Runtime.FHIRTools resolves
/// clinical text to codes against this table BEFORE running coded FHIR searches —
/// the terminology-resolution step the contest rewards. Seeded from
/// seed/demo-data/terminology.json; extensible without code changes.
Class FAST.Data.TerminologyConcept Extends (%Persistent, %JSON.Adaptor)
{

Parameter %JSONIGNORENULL = 1;

/// Lower-cased search text (synonym or display) used for matching.
Property SearchText As %String(%JSONFIELDNAME = "searchText", MAXLEN = 300);

/// Code system, e.g. "SNOMED", "LOINC", "RxNorm", "ICD-10".
Property System As %String(%JSONFIELDNAME = "system", MAXLEN = 40);

/// The code, e.g. "44054006".
Property Code As %String(%JSONFIELDNAME = "code", MAXLEN = 60);

/// Human-readable display, e.g. "Type 2 diabetes mellitus".
Property Display As %String(%JSONFIELDNAME = "display", MAXLEN = 300);

Index SearchIdx On SearchText;

Index CodeIdx On (System, Code);

}
