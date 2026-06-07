/// Read-only SQL guard, shared by the NL→FHIR agent and the generic EvidenceEngine.
/// A query is only allowed to run if it is a single SELECT with no DML/DDL,
/// procedure call, or second statement. This is the single source of truth for
/// "is this query safe to execute" — both AIHubOperation (LLM-authored NL→FHIR)
/// and EvidenceSource SQL specs delegate here.
Class FAST.Util.SqlGuard [ Abstract ]
{

/// Whitelist guard: a single read-only SELECT, no DML/DDL, no second statement.
ClassMethod IsReadOnly(sql As %String) As %Boolean
{
    set s = $zconvert($zstrip(sql, "<>W"), "U")
    if s = "" return 0
    // must begin with SELECT (optionally inside parentheses)
    set head = $zstrip($translate(s, "(", " "), "<W")
    if $extract(head, 1, 7) '= "SELECT " return 0
    // reject a populated second statement after a ';'
    if (s [ ";") && ($zstrip($piece(s, ";", 2, *), "<>W") '= "") return 0
    // reject any write / DDL / procedure-call keywords
    set padded = " " _ $translate(s, $char(9, 10, 13), "   ") _ " "
    set bad = $listbuild(" INSERT ", " UPDATE ", " DELETE ", " DROP ", " ALTER ", " CREATE ", " TRUNCATE ", " MERGE ", " GRANT ", " REVOKE ", " CALL ", " EXEC ", " INTO ", "%XECUTE")
    set ptr = 0
    while $listnext(bad, ptr, kw) { if padded [ kw return 0 }
    return 1
}

/// Strip the internal collation-prefix control bytes IRIS FHIR search-projection
/// string columns carry, so the real values display cleanly. Numeric cells are
/// left untouched (and typed).
ClassMethod CleanCell(v As %String) As %String
{
    if (v '= "") && '$isvalidnum(v) set v = $zstrip(v, "*C")
    return v
}

}
