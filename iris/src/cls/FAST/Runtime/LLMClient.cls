/// Minimal OpenAI-compatible chat client (xAI Grok by default). Reads config
/// from ^FAST("llm",...): endpoint, key, model. Used by
/// AIHubOperation in external mode and by the dev CacheBuilder tooling.
Class FAST.Runtime.LLMClient [ Abstract ]
{

Parameter SSLNAME = "fhiras_ssl";

/// The bring-your-own API key, held ONLY in IRISTEMP (^IRIS.Temp): never
/// journaled, never written to the durable database, wiped on every instance
/// restart. It is never logged, never echoed back to a client (a masked hint
/// only), and is never part of the repo or the baked image.
ClassMethod Key() As %String
{
    return $get(^IRIS.Temp("FAST", "llm", "key"))
}

/// Set ("" clears) the key. Also removes any legacy durable copy - earlier
/// builds stored it in ^FAST("llm","key"), which is journaled; this migrates
/// running containers to the temporary store on the next key update.
ClassMethod SetKey(key As %String)
{
    if key = "" {
        kill ^IRIS.Temp("FAST", "llm", "key")
    } else {
        set ^IRIS.Temp("FAST", "llm", "key") = key
    }
    kill ^FAST("llm", "key")
}

/// Reverse the obscuring on the bundled demo-key blob:
/// blob = Base64(reverse(key))  ->  key = reverse(Base64Decode(blob)).
/// This is OBFUSCATION, not encryption. It defeats casual source scans and
/// naive secret scanners (no literal "xai-" appears, and a single base64 decode
/// yields only the reversed, invalid-looking string), nothing more. The real
/// control on a shipped key is the provider-side hard spend cap - see
/// docs/demo-llm-key.md. Anyone reading this code can recover the key; that is
/// the accepted, deliberate trade for a key-free live-AI demo.
ClassMethod Deobscure(blob As %String) As %String
{
    set blob = $zstrip(blob, "*W")
    if blob = "" return ""
    return $reverse($system.Encryption.Base64Decode(blob))
}

/// Inverse of Deobscure - the dev/rotation helper that produces the blob to
/// write into seed/llm-key.b64. See docs/demo-llm-key.md for the rotation runbook.
ClassMethod Obscure(key As %String) As %String
{
    return $system.Encryption.Base64Encode($reverse(key))
}

/// POST messages to /chat/completions. Returns the assistant message content.
/// jsonMode requests a JSON object response when the provider supports it.
/// httpStatus (optional output) carries the real HTTP status code of the call.
ClassMethod Chat(messages As %DynamicArray, Output content As %String, jsonMode As %Boolean = 1, Output httpStatus As %String) As %Status
{
    set content = "", httpStatus = ""
    set endpoint = $get(^FAST("llm", "endpoint"))
    set key = ..Key()
    set model = $get(^FAST("llm", "model"))
    if (endpoint = "") || (key = "") return $$$ERROR($$$GeneralError, "LLM not configured (endpoint/key)")

    // parse endpoint → host + base path
    set host = endpoint
    set host = $replace(host, "https://", "")
    set host = $replace(host, "http://", "")
    set basePath = ""
    if host [ "/" {
        set basePath = "/" _ $piece(host, "/", 2, *)
        set host = $piece(host, "/", 1)
    }

    set req = ##class(%Net.HttpRequest).%New()
    set req.Server = host
    set req.Https = 1
    set req.Port = 443
    set req.SSLConfiguration = ..EnsureSSL()
    set req.ContentType = "application/json"
    set req.Timeout = 60
    do req.SetHeader("Authorization", "Bearer " _ key)

    set body = {}
    set body.model = model
    set body.messages = messages
    set body.temperature = 0
    if jsonMode set body."response_format" = {"type": "json_object"}
    do req.EntityBody.Write(body.%ToJSON())

    set sc = req.Post(basePath _ "/chat/completions")
    if $$$ISERR(sc) return sc
    set httpStatus = req.HttpResponse.StatusCode
    if (req.HttpResponse.StatusCode '= 200) {
        return $$$ERROR($$$GeneralError, "HTTP " _ req.HttpResponse.StatusCode _ ": " _ req.HttpResponse.Data.Read(2000))
    }
    set resp = ##class(%DynamicAbstractObject).%FromJSON(req.HttpResponse.Data)
    if $isobject(resp.choices) && (resp.choices.%Size() > 0) {
        set content = resp.choices.%Get(0).message.content
    }
    return $$$OK
}

/// Ensure a client SSL/TLS configuration exists; return its name.
ClassMethod EnsureSSL() As %String
{
    new $namespace
    set $namespace = "%SYS"
    set name = ..#SSLNAME
    if '##class(Security.SSLConfigs).Exists(name) {
        do ##class(Security.SSLConfigs).Create(name)
    }
    return name
}

/// Diagnostic: round-trip a trivial prompt.
ClassMethod Probe() As %String
{
    set msgs = [{"role": "user", "content": "Reply with exactly: PONG"}]
    set sc = ..Chat(msgs, .content, 0)
    if $$$ISERR(sc) return "ERR: " _ $system.Status.GetErrorText(sc)
    return "OK content=[" _ content _ "] model=" _ $get(^FAST("llm", "model"))
}

}
