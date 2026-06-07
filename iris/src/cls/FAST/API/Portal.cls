/// Serves the built React SPA from disk so the app root (/fhir-agent-studio/)
/// resolves cleanly to index.html and assets load with correct content types.
/// (IRIS static CSP apps don't auto-serve a directory index, so we dispatch.)
Class FAST.API.Portal Extends %CSP.REST
{

Parameter ROOT = "/usr/irissys/csp/fhir-agent-studio";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/" Method="GET" Call="Index"/>
<Route Url="/index.html" Method="GET" Call="Index"/>
<Route Url="/assets/:file" Method="GET" Call="Asset"/>
<Route Url="/:page" Method="GET" Call="Index"/>
</Routes>
}

/// Serves the SPA shell. The optional page arg is the captured segment from the
/// /:page fallback route (client-side routing / refresh on a sub-path); it is
/// ignored — the SPA's router resolves the view.
ClassMethod Index(page As %String = "") As %Status
{
    return ..ServeFile(..#ROOT _ "/index.html", "text/html; charset=utf-8")
}

ClassMethod Asset(file As %String) As %Status
{
    return ..ServeFile(..#ROOT _ "/assets/" _ file, ..ContentType(file))
}

ClassMethod ServeFile(path As %String, contentType As %String) As %Status
{
    if '##class(%File).Exists(path) {
        set %response.Status = "404 Not Found"
        return $$$OK
    }
    set %response.ContentType = contentType
    set stream = ##class(%Stream.FileBinary).%New()
    do stream.LinkToFile(path)
    do stream.OutputToDevice()
    return $$$OK
}

ClassMethod ContentType(file As %String) As %String
{
    set ext = $zconvert($piece(file, ".", *), "l")
    if ext = "js" return "application/javascript; charset=utf-8"
    if ext = "css" return "text/css; charset=utf-8"
    if ext = "json" return "application/json; charset=utf-8"
    if ext = "svg" return "image/svg+xml"
    if ext = "html" return "text/html; charset=utf-8"
    if ext = "ico" return "image/x-icon"
    if (ext = "woff2") return "font/woff2"
    if (ext = "woff") return "font/woff"
    return "application/octet-stream"
}

}
