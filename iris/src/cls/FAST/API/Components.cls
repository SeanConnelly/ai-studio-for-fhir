/// Generic CRUD for the reusable agent-component model (Prompt, EvidenceSource,
/// ActionTemplate, OutputSchema). All four extend %JSON.Adaptor and share the same
/// shape (unique Slug, Name, IsSystem, timestamps), so one set of generic handlers
/// drives the Studio's Prompt/Evidence/Action/Schema managers. Routes in
/// FAST.API.Rest delegate here with the logical entity name.
Class FAST.API.Components [ Abstract ]
{

/// Map a logical entity name (as used in the REST path) to its persistent class.
ClassMethod ClassFor(entity As %String) As %String
{
    if entity = "prompts" return "FAST.Data.Prompt"
    if entity = "evidence-sources" return "FAST.Data.EvidenceSource"
    if entity = "actions" return "FAST.Data.ActionTemplate"
    if entity = "output-schemas" return "FAST.Data.OutputSchema"
    return ""
}

/// GET /<entity> — list all components of a type as JSON objects.
ClassMethod List(entity As %String) As %Status
{
    set cls = ..ClassFor(entity)
    if cls = "" return ##class(FAST.Util.Response).Error("Unknown component type: " _ entity, "404 Not Found")
    set table = "FAST_Data." _ $piece(cls, ".", *)
    set arr = []
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT ID FROM " _ table _ " ORDER BY Name")
    while rs.%Next() {
        set obj = $classmethod(cls, "%OpenId", rs.%Get("ID"))
        if '$isobject(obj) continue
        do arr.%Push(..Export(obj))
    }
    set o = {}, o.items = arr, o.count = arr.%Size()
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// GET /<entity>/:slug — one component.
ClassMethod Get(entity As %String, slug As %String) As %Status
{
    set cls = ..ClassFor(entity)
    if cls = "" return ##class(FAST.Util.Response).Error("Unknown component type: " _ entity, "404 Not Found")
    set obj = $classmethod(cls, "SlugIdxOpen", slug)
    if '$isobject(obj) return ##class(FAST.Util.Response).Error(entity _ " not found: " _ slug, "404 Not Found")
    return ##class(FAST.Util.Response).WriteJSON(..Export(obj))
}

/// POST /<entity> (create) or PUT /<entity>/:slug (update). Body is the JSON
/// object; %JSONImport maps it onto the persistent class. Slug is required on
/// create; on update the path slug wins.
ClassMethod Upsert(entity As %String, slug As %String = "") As %Status
{
    set cls = ..ClassFor(entity)
    if cls = "" return ##class(FAST.Util.Response).Error("Unknown component type: " _ entity, "404 Not Found")
    set body = ##class(FAST.Util.Response).Body()
    if '$isobject(body) return ##class(FAST.Util.Response).Error("Invalid JSON body")
    if (slug = "") set slug = body.slug
    if (slug = "") return ##class(FAST.Util.Response).Error("A 'slug' is required")

    set obj = $classmethod(cls, "SlugIdxOpen", slug), created = 0
    if '$isobject(obj) {
        set obj = $classmethod(cls, "%New")
        set created = 1
    }
    // ensure the (required) slug is always present for import, even on a PUT whose
    // body omits it — the path/param slug is authoritative
    do body.%Set("slug", slug)
    // import the posted fields, then re-assert identity + bookkeeping fields
    set sc = obj.%JSONImport(body)
    if $$$ISERR(sc) return ##class(FAST.Util.Response).Error("Import failed: " _ $system.Status.GetErrorText(sc), "400 Bad Request")
    set obj.Slug = slug
    set obj.UpdatedAt = $zdatetime($ztimestamp, 3)
    set sc = obj.%Save()
    if $$$ISERR(sc) return ##class(FAST.Util.Response).Error($system.Status.GetErrorText(sc), "500 Internal Server Error")
    set o = ..Export(obj)
    do o.%Set("created", created, "boolean")
    return ##class(FAST.Util.Response).WriteJSON(o, $select(created: "201 Created", 1: "200 OK"))
}

/// DELETE /<entity>/:slug — refuses to delete a seeded (IsSystem) component.
ClassMethod Delete(entity As %String, slug As %String) As %Status
{
    set cls = ..ClassFor(entity)
    if cls = "" return ##class(FAST.Util.Response).Error("Unknown component type: " _ entity, "404 Not Found")
    set obj = $classmethod(cls, "SlugIdxOpen", slug)
    if '$isobject(obj) return ##class(FAST.Util.Response).Error(entity _ " not found: " _ slug, "404 Not Found")
    if obj.IsSystem return ##class(FAST.Util.Response).Error("Cannot delete a system component: " _ slug, "409 Conflict")
    set sc = $classmethod(cls, "%DeleteId", obj.%Id())
    if $$$ISERR(sc) return ##class(FAST.Util.Response).Error($system.Status.GetErrorText(sc), "500 Internal Server Error")
    set o = {}, o.slug = slug, o.deleted = 1
    return ##class(FAST.Util.Response).WriteJSON(o)
}

/// Export one component object to a %DynamicObject (its full JSON projection).
ClassMethod Export(obj As %RegisteredObject) As %DynamicObject
{
    set json = ""
    do obj.%JSONExportToString(.json)
    set parsed = ##class(FAST.Util.JSON).Parse(json)
    return $select($isobject(parsed): parsed, 1: {})
}

}
