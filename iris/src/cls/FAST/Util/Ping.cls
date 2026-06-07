/// Smoke-test class: confirms the docker-exec push/compile/run loop works.
Class FAST.Util.Ping
{

ClassMethod Hello() As %String
{
    return "FHIR Agent Studio backend is alive on "_$zversion
}

}
