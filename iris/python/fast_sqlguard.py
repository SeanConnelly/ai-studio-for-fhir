"""AST-level read-only verification for LLM-generated SQL.

Runs on IRIS's bundled Python (sqlparse) as the second gate behind the
ObjectScript keyword check (AIHubOperation.IsReadOnly): the keyword gate
string-matches, this gate actually parses the statement with sqlparse, so it
catches what string-matching cannot (comment-smuggled DML, stacked statements,
SELECT INTO).

Two ways to call it, both exercised by FAST.Runtime.SqlGuard:
  - in-process via %SYS.Python (mod.check(sql)) where the callin bridge is
    healthy;
  - out-of-process via `irispython fast_sqlguard.py <file>` (the __main__
    entrypoint below) on images where the in-process bridge SIGSEGVs
    (irishealth-community 2026.x - see docs/embedded-python-bug.md). Either
    way it is genuinely IRIS Embedded Python running real sqlparse.

Returns a JSON string {"available": 0|1, "ok": 0|1, "reason": "..."} so the
ObjectScript side never has to marshal Python objects.
"""

import json

BANNED = {"INTO", "GRANT", "REVOKE", "CALL", "EXECUTE", "EXEC", "MERGE",
          "REPLACE", "TRUNCATE"}


def _result(available, ok, reason):
    return json.dumps({"available": 1 if available else 0,
                       "ok": 1 if ok else 0,
                       "reason": reason})


def check(sql):
    try:
        import sqlparse
        from sqlparse import tokens as T
    except ImportError:
        return _result(False, False, "sqlparse is not installed")

    try:
        stmts = [s for s in sqlparse.parse(sql or "")
                 if s.token_first(skip_cm=True) is not None]
        if len(stmts) != 1:
            return _result(True, False,
                           "expected exactly one SQL statement, found %d"
                           % len(stmts))
        stmt = stmts[0]
        stype = stmt.get_type()
        if stype != "SELECT":
            return _result(True, False,
                           "statement type is %s; only SELECT is allowed"
                           % stype)
        for tok in stmt.flatten():
            if tok.ttype is T.Keyword.DML and tok.value.upper() != "SELECT":
                return _result(True, False,
                               "found write keyword %s" % tok.value.upper())
            if tok.ttype is T.Keyword.DDL:
                return _result(True, False,
                               "found DDL keyword %s" % tok.value.upper())
            if tok.ttype in T.Keyword and tok.value.upper() in BANNED:
                return _result(True, False,
                               "found disallowed keyword %s"
                               % tok.value.upper())
        return _result(True, True,
                       "parsed as a single read-only SELECT statement "
                       "(sqlparse)")
    except Exception as e:  # never raise into ObjectScript
        return _result(True, False,
                       "could not parse the statement: %s" % str(e))


if __name__ == "__main__":
    # Out-of-process entrypoint for `irispython fast_sqlguard.py <sqlfile>`
    # (or SQL on stdin). Prints the JSON verdict to stdout. Used by
    # FAST.Runtime.SqlGuard on images where the in-process callin bridge
    # crashes, so the Embedded Python gate still runs for real.
    import sys
    _src = open(sys.argv[1]).read() if len(sys.argv) > 1 else sys.stdin.read()
    sys.stdout.write(check(_src))
