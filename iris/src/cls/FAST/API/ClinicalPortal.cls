/// Serves the built Clinical SPA from disk at /clinical/ (mirrors FAST.API.Portal,
/// which serves the Studio at /fhir-agent-studio/). IRIS static CSP apps don't
/// auto-serve a directory index, so we dispatch. The Clinical SPA calls the same
/// REST API at /fhir-agent-studio/api as the Studio.
Class FAST.API.ClinicalPortal Extends %CSP.REST
{

Parameter ROOT = "/usr/irissys/csp/clinical";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/" Method="GET" Call="Index"/>
<Route Url="/index.html" Method="GET" Call="Index"/>
<Route Url="/assets/:file" Method="GET" Call="Asset"/>
<Route Url="/:page" Method="GET" Call="Index"/>
</Routes>
}

ClassMethod Index(page As %String = "") As %Status
{
    return ##class(FAST.API.Portal).ServeFile(..#ROOT _ "/index.html", "text/html; charset=utf-8")
}

ClassMethod Asset(file As %String) As %Status
{
    return ##class(FAST.API.Portal).ServeFile(..#ROOT _ "/assets/" _ file, ##class(FAST.API.Portal).ContentType(file))
}

}
