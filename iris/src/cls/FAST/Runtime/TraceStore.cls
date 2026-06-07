/// Records and retrieves runtime trace steps (HealthConnect-style audit).
Class FAST.Runtime.TraceStore [ Abstract ]
{

ClassMethod Step(traceId As %String, stepNumber As %Integer, componentType As %String, componentName As %String, status As %String, detail As %String, payloadJSON As %String = "", durationMs As %Integer = 0) As %Status
{
    set t = ##class(FAST.Data.TraceStep).%New()
    set t.TraceId = traceId
    set t.StepNumber = stepNumber
    set t.ComponentType = componentType
    set t.ComponentName = componentName
    set t.Status = status
    set t.Detail = detail
    set t.PayloadJSON = payloadJSON
    set t.DurationMs = durationMs
    set t.CompletedAt = $zdatetime($ztimestamp, 3)
    return t.%Save()
}

ClassMethod AsArray(traceId As %String) As %DynamicArray
{
    set arr = []
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT StepNumber, ComponentType, ComponentName, Status, Detail, DurationMs, PayloadJSON FROM FAST_Data.TraceStep WHERE TraceId = ? ORDER BY StepNumber", traceId)
    while rs.%Next() {
        set o = {}
        set o.step = rs.%Get("StepNumber")
        set o.componentType = rs.%Get("ComponentType")
        set o.componentName = rs.%Get("ComponentName")
        set o.status = rs.%Get("Status")
        set o.detail = rs.%Get("Detail")
        set o.durationMs = rs.%Get("DurationMs")
        set p = rs.%Get("PayloadJSON")
        if p '= "" set o.payload = ##class(FAST.Util.JSON).Parse(p)
        do arr.%Push(o)
    }
    return arr
}

}
