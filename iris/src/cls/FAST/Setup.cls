/// One-time environment setup: creates the REST web application.
/// Invoked from module.xml (Phase 6) and runnable by hand during dev.
Class FAST.Setup
{

Parameter APIAPP = "/fhir-agent-studio/api";

Parameter SPAAPP = "/fhir-agent-studio";

Parameter CLINICALAPP = "/clinical";

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
