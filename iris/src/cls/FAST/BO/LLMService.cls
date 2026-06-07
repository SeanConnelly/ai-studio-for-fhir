/// Business Operation: the LLM egress, on the standard HealthConnect HTTP
/// plumbing (EnsLib.HTTP.OutboundAdapter - server/port/SSL/timeout are real
/// adapter settings, visible on the production configuration screen). Every
/// agent reasoning call arrives as a FAST.Msg.LLMRequest (the literal HTTP
/// request: URL, masked auth header, JSON body), making the outbound leg a
/// first-class message in the Visual Trace. Resolution is the same three-tier
/// seam as everywhere else, and the response says truthfully which tier answered:
///   cached - the bundled corpus had this exact completion; NO network call is
///            made and the Note says so (the request shown is byte-equivalent
///            to the one that originally produced it live);
///   live   - a real HTTPS call through the adapter (BYO key), with the real
///            HTTP status code on the response;
///   none   - no cache hit and no key: nothing is called, and the caller falls
///            back to the deterministic (non-AI) scaffold.
Class FAST.BO.LLMService Extends Ens.BusinessOperation
{

Parameter ADAPTER = "EnsLib.HTTP.OutboundAdapter";

Parameter INVOCATION = "Queue";

Property Adapter As EnsLib.HTTP.OutboundAdapter;

/// When this operation's job starts (production start, incl. auto-start at
/// container boot), re-arm the bundled demo key — IRISTEMP was wiped on restart.
/// No-op if a key is already in memory. Belt-and-suspenders with EnsureProduction.
Method OnInit() As %Status
{
    do ##class(FAST.Seed.SeedLoader).LoadDemoKey()
    quit $$$OK
}

Method Run(pReq As FAST.Msg.LLMRequest, Output pResp As FAST.Msg.LLMResponse) As %Status
{
    set pResp = ##class(FAST.Msg.LLMResponse).%New()
    set ai = "FAST.Runtime.AIHubOperation"
    $$$TRACE("LLM request for recipe '" _ pReq.RecipeId _ "' (cache key " _ pReq.CacheKey _ ", body " _ $length(pReq.BodyJSON) _ " bytes)" _ $select(+pReq.NoCache: " - CACHE BYPASS requested for this run", 1: ""))

    // Tier 1 - bundled real completion (the key-free demo path): replay, no network.
    if $classmethod(ai, "UseCache") && '+pReq.NoCache {
        set hit = ##class(FAST.Data.LLMCache).KeyIdxOpen(pReq.CacheKey)
        if $isobject(hit) && (hit.OutputJSON '= "") {
            $$$TRACE("CACHE HIT - replaying the bundled real completion (" _ $length(hit.OutputJSON) _ " bytes, generated " _ hit.CreatedAt _ " by " _ hit.Model _ "). NO network call made.")
            set pResp.Source = "cached"
            set pResp.HttpStatus = ""
            set pResp.Note = "Replayed from the bundled response corpus - no network call was made. "
                _ "The request shown is byte-equivalent to the one sent when this completion was "
                _ "originally generated live; the completion is that original model output, stored verbatim."
            set pResp.CompletionJSON = hit.OutputJSON
            quit $$$OK
        }
        $$$TRACE("CACHE MISS - no bundled completion for this exact prompt")
    }

    // Tier 2 - real outbound HTTPS call through the HTTP adapter (bring-your-own key).
    if $classmethod(ai, "HasLiveKey") {
        $$$TRACE("LIVE CALL - POST " _ pReq.Url _ " via EnsLib.HTTP.OutboundAdapter (key configured, Authorization masked)")
        try {
            // the runtime AI connection (Admin / BYO endpoint) is authoritative;
            // copy it onto the adapter so the call uses the configured provider
            set endpoint = $get(^FAST("llm", "endpoint"), "https://api.x.ai/v1")
            set host = $replace($replace(endpoint, "https://", ""), "http://", "")
            set basePath = ""
            if host [ "/" {
                set basePath = "/" _ $piece(host, "/", 2, *)
                set host = $piece(host, "/", 1)
            }
            set ..Adapter.HTTPServer = host
            set ..Adapter.HTTPPort = 443
            set ..Adapter.SSLConfig = ##class(FAST.Runtime.LLMClient).EnsureSSL()
            set ..Adapter.ResponseTimeout = 90

            set httpReq = ##class(%Net.HttpRequest).%New()
            set httpReq.ContentType = "application/json"
            do httpReq.SetHeader("Authorization", "Bearer " _ ##class(FAST.Runtime.LLMClient).Key())
            do httpReq.EntityBody.Write(pReq.BodyJSON)

            set sc = ..Adapter.SendFormDataArray(.httpResp, "POST", httpReq, "", "", basePath _ "/chat/completions")
            if $$$ISOK(sc) && $isobject(httpResp) {
                $$$TRACE("LIVE RESPONSE - HTTP " _ httpResp.StatusCode _ " from " _ host)
            }
            if $$$ISOK(sc) && $isobject(httpResp) && (httpResp.StatusCode = 200) {
                set envelope = ##class(%DynamicAbstractObject).%FromJSON(httpResp.Data)
                set content = ""
                if $isobject(envelope.choices) && (envelope.choices.%Size() > 0) {
                    set content = envelope.choices.%Get(0).message.content
                }
                set pResp.Source = "live (" _ $get(^FAST("llm", "model"), "llm") _ ")"
                set pResp.HttpStatus = httpResp.StatusCode
                set pResp.Note = "Live HTTPS call to " _ pReq.Url _ " via EnsLib.HTTP.OutboundAdapter - HTTP " _ httpResp.StatusCode _ "."
                set pResp.CompletionJSON = content
            } else {
                set code = $select($isobject($get(httpResp)): httpResp.StatusCode, 1: "")
                set pResp.Source = "error"
                set pResp.HttpStatus = code
                set pResp.Error = $select($$$ISERR(sc): $zstrip($system.Status.GetErrorText(sc), "<>W"),
                                          $isobject($get(httpResp)): "HTTP " _ code _ ": " _ httpResp.Data.Read(2000),
                                          1: "no response")
                set reason = $case(code, 401: "the API key was rejected - the shared demo key may be exhausted or rotated",
                                         402: "the account is out of credit - the shared demo budget ($) is spent",
                                         429: "rate-limited - too many requests just now",
                                         : "the provider returned an error")
                set pResp.Note = "Live call to " _ pReq.Url _ " returned HTTP " _ code _ " - " _ reason _ ". "
                    _ "The run falls back to the deterministic (non-AI) scaffold; add your own OpenAI-compatible key in Admin for unlimited live AI."
                $$$TRACE("LIVE CALL FAILED - HTTP " _ code _ " (" _ reason _ "); falling back to deterministic")
            }
        } catch ex {
            set pResp.Source = "error"
            set pResp.Error = ex.DisplayString()
            set pResp.Note = "Live call to " _ pReq.Url _ " failed; the caller falls back."
        }
        quit $$$OK
    }

    // Tier 3 - nothing to call.
    $$$TRACE("NO TIER AVAILABLE - " _ $select(+pReq.NoCache: "cache bypassed by request", 1: "no cached completion") _ " and no API key configured; no call made, caller falls back to the deterministic (non-AI) scaffold")
    set pResp.Source = "none"
    set pResp.Note = "No " _ $select(+pReq.NoCache: "cache lookup was made (bypass requested)", 1: "cached response exists for this exact prompt") _ " and no API key is configured - "
        _ "no call was made. The caller falls back to the deterministic (non-AI) scaffold and labels it honestly."
    quit $$$OK
}

XData MessageMap
{
<MapItems>
  <MapItem MessageType="FAST.Msg.LLMRequest">
    <Method>Run</Method>
  </MapItem>
</MapItems>
}

}
