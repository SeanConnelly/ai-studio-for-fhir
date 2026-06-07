/// Small helpers for consistent JSON REST responses.
Class FAST.Util.Response [ Abstract ]
{

/// Write a %DynamicObject/%DynamicArray as the JSON response body.
ClassMethod WriteJSON(obj As %DynamicAbstractObject, status As %String = "200 OK") As %Status
{
    set %response.Status = status
    set %response.ContentType = "application/json"
    do obj.%ToJSON()
    return $$$OK
}

/// Write a standard error envelope.
ClassMethod Error(message As %String, status As %String = "400 Bad Request") As %Status
{
    set o = {}
    set o.error = message
    return ..WriteJSON(o, status)
}

/// Parse the request body as JSON, returning a %DynamicObject (or "" on failure).
ClassMethod Body() As %DynamicAbstractObject
{
    try {
        if '$isobject(%request.Content) return {}
        return ##class(%DynamicAbstractObject).%FromJSON(%request.Content)
    } catch {
        return ""
    }
}

}
