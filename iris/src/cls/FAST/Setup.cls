/// One-time environment setup: creates the REST web application.
/// Invoked from module.xml (Phase 6) and runnable by hand during dev.
Class FAST.Setup
{

Parameter APIAPP = "/fhir-agent-studio/api";

Parameter SPAAPP = "/fhir-agent-studio";

Parameter CLINICALAPP = "/clinical";

/// Password applied to the default privileged accounts (_SYSTEM, SuperUser, Admin)
/// so the public Management Portal cannot be opened with the shipped SYS default.
/// This is a DEMO instance (rebuilt on every deploy), so the password is merely
/// OBFUSCATED (base64), not secret: decoded at runtime. Plaintext decodes to a
/// non-default value, which is the only goal here. To change it:
///   echo -n 'NewPassword' | base64
Parameter ADMINPASSWORDB64 = "U3R1ZDFvLUZBU1QtQWRtIW4tOWsyUXg3";

/// Read-only viewer account: can open the interoperability portal, browse
/// messages and Visual Trace, but cannot edit, start, or stop anything.
/// Deliberately shareable (published in the README's Live Demo section) so judges
/// can explore the Management Portal. The app pages need no login at all.
Parameter VIEWERUSER = "viewer";

Parameter VIEWERPASSWORD = "ReadOnly-Trace-2026";

Parameter VIEWERROLE = "FAST_Viewer";

/// Create / refresh the REST CSP application. Unauthenticated access is
/// enabled so the portal and core API load without any secret (a hard
/// project constraint); this is a local demo container.
ClassMethod CreateRestApp(namespace As %String = {$namespace}) As %Status
{
    new $namespace
    set ns = namespace
    set $namespace = "%SYS"
    set app = ..#APIAPP
    set props("NameSpace") = ns
    set props("DispatchClass") = "FAST.API.Rest"
    set props("AutheEnabled") = 96  // 64 Unauthenticated + 32 Password
    set props("MatchRoles") = ":%All"
    set props("Enabled") = 1
    set props("Recurse") = 1
    set props("CookiePath") = "/fhir-agent-studio/"
    set props("Description") = "FHIR Agent Studio REST API"
    if ##class(Security.Applications).Exists(app) {
        set sc = ##class(Security.Applications).Modify(app, .props)
    } else {
        set sc = ##class(Security.Applications).Create(app, .props)
    }
    return sc
}

/// Create / refresh the SPA dispatch web app (serves the built React app from
/// disk via FAST.API.Portal). Unauthenticated for frictionless demo.
ClassMethod CreateSpaApp(namespace As %String = {$namespace}) As %Status
{
    new $namespace
    set ns = namespace
    set $namespace = "%SYS"
    set app = ..#SPAAPP
    set props("NameSpace") = ns
    set props("DispatchClass") = "FAST.API.Portal"
    set props("AutheEnabled") = 96  // Unauthenticated + Password
    set props("MatchRoles") = ":%All"
    set props("Enabled") = 1
    set props("Recurse") = 1
    set props("CookiePath") = "/fhir-agent-studio/"
    set props("Description") = "FHIR Agent Studio SPA"
    if ##class(Security.Applications).Exists(app) {
        return ##class(Security.Applications).Modify(app, .props)
    }
    return ##class(Security.Applications).Create(app, .props)
}

/// Create / refresh the Clinical SPA dispatch web app (serves the built Clinical
/// React app from disk via FAST.API.ClinicalPortal at /clinical/).
ClassMethod CreateClinicalApp(namespace As %String = {$namespace}) As %Status
{
    new $namespace
    set ns = namespace
    set $namespace = "%SYS"
    set app = ..#CLINICALAPP
    set props("NameSpace") = ns
    set props("DispatchClass") = "FAST.API.ClinicalPortal"
    set props("AutheEnabled") = 96  // Unauthenticated + Password
    set props("MatchRoles") = ":%All"
    set props("Enabled") = 1
    set props("Recurse") = 1
    set props("CookiePath") = "/clinical/"
    set props("Description") = "FAST Clinical SPA"
    if ##class(Security.Applications).Exists(app) {
        return ##class(Security.Applications).Modify(app, .props)
    }
    return ##class(Security.Applications).Create(app, .props)
}

/// Invoked by module.xml at install time: ensure the REST + SPA apps exist,
/// then load seed data + embeddings. seedRoot defaults to the image's /opt/seed.
ClassMethod PostInstall(seedRoot As %String = "/opt/seed") As %Status
{
    // The in-process FHIR load authenticates loopback as _SYSTEM/SYS; ensure
    // the default credential is usable (the image ships it expired).
    do ..UnexpirePasswords()
    set sc = ..CreateRestApp()
    if $$$ISERR(sc) {
        write "PostInstall CreateRestApp failed: ", $system.Status.GetErrorText(sc), !
        return sc
    }
    set sc = ..CreateSpaApp()
    if $$$ISERR(sc) {
        write "PostInstall CreateSpaApp failed: ", $system.Status.GetErrorText(sc), !
        return sc
    }
    set sc = ..CreateClinicalApp()
    if $$$ISERR(sc) {
        write "PostInstall CreateClinicalApp failed: ", $system.Status.GetErrorText(sc), !
        return sc
    }
    set sc = ##class(FAST.Seed.SeedLoader).Run(seedRoot)
    if $$$ISERR(sc) return sc
    // NB: the interoperability production is NOT started here. IPM runs
    // PostInstall inside a transaction, and Ens.Director.StartProduction cannot
    // run in a transaction (<COMMAND> *NoTransaction). The production is started
    // after the module load completes (iris.script), and lazily by
    // FAST.Runtime.Runtime.EnsureProduction on the first recipe run.
    return $$$OK
}

/// Unexpire the default user passwords (loopback FHIR load uses _SYSTEM/SYS).
ClassMethod UnexpirePasswords()
{
    new $namespace
    set $namespace = "%SYS"
    do ##class(Security.Users).UnExpireUserPasswords("*")
}

/// Lock down the instance for a PUBLIC cloud deploy. Run as the FINAL build step
/// (iris.script), AFTER all seeding: the only consumer of the default _SYSTEM/SYS
/// credential is the build-time FHIR load (FAST.Seed.SeedLoader over loopback
/// HTTP); the live runtime reads/writes FHIR in-process, so rotating the password
/// here does NOT affect the demo. The judge-facing apps stay unauthenticated for
/// frictionless access; this only secures the Management Portal / interop portal.
///   1. rotate _SYSTEM / SuperUser / Admin off the shipped SYS password
///   2. create a read-only role (interop view + namespace DB read)
///   3. create the "viewer" account (read-only: productions, messages, traces)
/// The admin password is de-obfuscated (base64) at runtime; the viewer password
/// is shareable plaintext (it ships in the README). Idempotent.
ClassMethod HardenSecurity() As %Status
{
    new $namespace
    set $namespace = "%SYS"
    set adminPw = $system.Encryption.Base64Decode(..#ADMINPASSWORDB64)
    set viewerPw = ..#VIEWERPASSWORD

    // 1. Rotate the default privileged accounts off "SYS".
    set priv = $listbuild("_SYSTEM", "SuperUser", "Admin")
    for i = 1:1:$listlength(priv) {
        set u = $list(priv, i)
        if '##class(Security.Users).Exists(u) continue
        set sc = ##class(Security.Users).Get(u, .p)
        if $$$ISERR(sc) { write "HardenSecurity: cannot read ", u, ": ", $system.Status.GetErrorText(sc), ! continue }
        set p("Password") = adminPw
        set p("PasswordNeverExpires") = 1
        set p("ChangePassword") = 0
        set p("Enabled") = 1
        set sc = ##class(Security.Users).Modify(u, .p)
        if $$$ISERR(sc) { write "HardenSecurity: cannot rotate ", u, ": ", $system.Status.GetErrorText(sc), ! }
        else { write "HardenSecurity: rotated password for ", u, !  }
    }

    // 2. Read-only role.
    set sc = ..EnsureViewerRole()
    if $$$ISERR(sc) return sc

    // 3. Read-only viewer account.
    kill vp
    set vp("Password") = viewerPw
    set vp("FullName") = "FHIR Agent Studio - Read-only Viewer"
    set vp("Comment") = "Read-only: view production, messages, Visual Trace. No edit/start/stop."
    set vp("Roles") = ..#VIEWERROLE
    set vp("Enabled") = 1
    set vp("PasswordNeverExpires") = 1
    set vp("ChangePassword") = 0
    if ##class(Security.Users).Exists(..#VIEWERUSER) {
        set sc = ##class(Security.Users).Modify(..#VIEWERUSER, .vp)
    } else {
        set sc = ##class(Security.Users).Create(..#VIEWERUSER, .vp)
    }
    if $$$ISERR(sc) { write "HardenSecurity: viewer account failed: ", $system.Status.GetErrorText(sc), ! return sc }
    write "HardenSecurity: read-only '", ..#VIEWERUSER, "' account ready.", !
    return $$$OK
}

/// Create / refresh the read-only role: USE on the interop view resources plus
/// READ on the FAST namespace database (where messages and traces live). Adds the
/// predefined %EnsRole_Monitor as a granted role when the image provides it.
ClassMethod EnsureViewerRole() As %Status
{
    new $namespace
    set $namespace = "%SYS"
    // Discover the database backing the FAST namespace's globals, then its resource.
    set dbRes = "%DB_FAST"
    if ##class(Config.Namespaces).Get("FAST", .nsp) {
        set globalsDb = $get(nsp("Globals"))
        if (globalsDb '= "") && ##class(Config.Databases).Get(globalsDb, .dbp) {
            if $get(dbp("Resource")) '= "" set dbRes = dbp("Resource")
        }
    }
    // Interop view resources (USE = view only; start/stop needs %Ens_ProductionRun,
    // which is deliberately NOT granted) + namespace DB read.
    set res = dbRes _ ":R"
    set res = res _ ",%Ens_Portal:U,%Ens_ProductionConfig:U,%Ens_Dashboard:U"
    set res = res _ ",%Ens_MessageHeader:U,%Ens_MessageContent:U"
    set res = res _ ",%Ens_EventLog:U,%Ens_Queues:U,%Ens_Alerts:U"
    set granted = $select(##class(Security.Roles).Exists("%EnsRole_Monitor"): "%EnsRole_Monitor", 1: "")
    set desc = "FHIR Agent Studio read-only viewer (interop view + DB read)"
    if ##class(Security.Roles).Exists(..#VIEWERROLE) {
        set sc = ##class(Security.Roles).Get(..#VIEWERROLE, .rp)
        set rp("Resources") = res
        if granted '= "" set rp("GrantedRoles") = granted
        set sc = ##class(Security.Roles).Modify(..#VIEWERROLE, .rp)
    } else {
        set sc = ##class(Security.Roles).Create(..#VIEWERROLE, desc, res, granted)
    }
    if $$$ISERR(sc) { write "EnsureViewerRole failed: ", $system.Status.GetErrorText(sc), ! }
    else { write "EnsureViewerRole: '", ..#VIEWERROLE, "' grants [", res, "]", $select(granted'="": " + "_granted, 1:""), ! }
    return sc
}

/// Convenience: run the full dev setup.
ClassMethod Install() As %Status
{
    set sc = ..CreateRestApp()
    if $$$ISERR(sc) {
        write "CreateRestApp failed: ", $system.Status.GetErrorText(sc), !
        return sc
    }
    write "REST app ", ..#APIAPP, " ready.", !
    return $$$OK
}

}
