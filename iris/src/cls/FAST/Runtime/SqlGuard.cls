/// AST-level read-only verification for LLM-generated SQL, via IRIS Embedded
/// Python (sqlparse). Defense in depth behind AIHubOperation.IsReadOnly (the
/// ObjectScript keyword gate): the keyword gate string-matches, this gate
/// actually parses the statement, so it catches what string-matching cannot
/// (comment-smuggled DML, stacked statements, SELECT INTO).
///
/// The Python lives in /usr/irissys/mgr/python/fast_sqlguard.py (repo:
/// iris/python/), installed by the Docker build with the sqlparse package.
///
/// Execution: we run it OUT OF PROCESS via IRIS's bundled `irispython`
/// (launched with $ZF(-100)). The in-process callin bridge (%SYS.Python) is
/// the more usual way to call Embedded Python, but it SIGSEGVs the calling
/// process on the irishealth-community 2026.x images (a real IRIS regression
/// we found and reported - see docs/embedded-python-bug.md). Out-of-process,
/// the same module runs genuinely and cannot take the caller down. The SQL is
/// passed via a temp FILE, never on the command line, so there is no shell
/// injection surface.
///
/// Fail-safe by design: if irispython/sqlparse is unavailable the caller falls
/// back to the ObjectScript gate alone and the run truthfully reports which
/// gates ran (the readOnlyGuard field).
Class FAST.Runtime.SqlGuard Extends %RegisteredObject
{

Parameter PYBIN = "/usr/irissys/bin/irispython";

Parameter PYMOD = "/usr/irissys/mgr/python/fast_sqlguard.py";

/// Never throws. Returns {available: 0|1, ok: 0|1, reason: "..."}.
/// Runs the Python AST gate out-of-process, so it is safe to call directly.
ClassMethod Check(sql As %String) As %DynamicObject
{
    set r = {}
    try {
        set base = "/tmp/fast-sqlguard-" _ $job
        set in = base _ ".in", out = base _ ".out"
        // write the SQL to a file - it never touches the command line, so there
        // is no shell-injection surface (the cmd only names our own temp paths)
        set fs = ##class(%Stream.FileCharacter).%New()
        set fs.Filename = in
        do fs.Write(sql)
        do fs.%Save()
        set fs = ""
        set cmd = ..#PYBIN _ " " _ ..#PYMOD _ " " _ in _ " > " _ out _ " 2>/dev/null"
        set rc = $ZF(-100, "/SHELL", "sh", "-c", cmd)
        set verdict = ""
        if rc = 0 {
            set rs = ##class(%Stream.FileCharacter).%New()
            set rs.Filename = out
            if rs.Size > 0 set verdict = rs.Read(32000)
            set rs = ""
        }
        do ##class(%File).Delete(in)
        do ##class(%File).Delete(out)
        if verdict '= "" return ##class(%DynamicObject).%FromJSON(verdict)
        set r.available = 0, r.ok = 0, r.reason = "irispython returned no verdict (rc=" _ rc _ ")"
        return r
    } catch e {
        set r.available = 0, r.ok = 0
        set r.reason = "Embedded Python (out-of-process) unavailable: " _ e.DisplayString()
        return r
    }
}

/// Is the Embedded Python gate available in this instance boot? Probes once
/// (verdict cached in IRISTEMP, which IRIS wipes on restart, so a baked image
/// can never carry a stale verdict onto another host) by running a trivial
/// check. Out-of-process Python can't crash the prober, so no sacrificial job
/// is needed. Manual override: set ^FAST("config","sqlguard") = 0 or 1.
ClassMethod Armed() As %Boolean
{
    set override = $get(^FAST("config", "sqlguard"))
    if override '= "" return +override
    set cached = $get(^IRIS.Temp("FAST", "sqlguard"))
    if cached '= "" return +cached
    set g = ..Check("SELECT 1")
    set ok = ((+g.available = 1) && (+g.ok = 1))
    set ^IRIS.Temp("FAST", "sqlguard") = ok
    return ok
}

}
