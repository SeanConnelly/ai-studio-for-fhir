/// The outbound LLM call as a first-class interoperability message: AIHub sends
/// this to the LLMService Business Operation for every agent reasoning step, so
/// the Visual Trace shows the egress leg explicitly. The properties mirror the
/// real HTTP request (method, URL, headers, JSON body); the Authorization header
/// is always masked - the key is never written to a message, log, or trace.
Class FAST.Msg.LLMRequest Extends Ens.Request
{

/// Always "POST" for /chat/completions.
Property Method As %String(MAXLEN = 10) [ InitialExpression = "POST" ];

/// The full request URL, e.g. https://api.x.ai/v1/chat/completions.
Property Url As %String(MAXLEN = 500);

/// Masked - the real bearer token is held in memory only and never logged.
Property AuthorizationHeader As %String(MAXLEN = 100) [ InitialExpression = "Bearer ***masked - never logged***" ];

Property ContentType As %String(MAXLEN = 50) [ InitialExpression = "application/json" ];

/// The exact OpenAI-compatible JSON body: model, messages, temperature,
/// response_format. This is byte-equivalent to what goes (or originally went)
/// over the wire.
Property BodyJSON As %String(MAXLEN = "");

/// The record/replay cache key derived from this request's prompt - lets the
/// LLMService answer from the bundled corpus when the exact completion exists.
Property CacheKey As %String(MAXLEN = 300);

Property RecipeId As %String(MAXLEN = 100);

/// When set, the LLMService skips its corpus lookup for this call: live HTTPS
/// with a key, otherwise "none" (the caller falls back to deterministic).
Property NoCache As %Boolean [ InitialExpression = 0 ];

/// Build the message from an assembled prompt (system + user), mirroring
/// exactly the body FAST.Runtime.LLMClient.Chat would send.
ClassMethod Build(recipeId As %String, prompt As %DynamicObject, cacheKey As %String, noCache As %Boolean = 0) As FAST.Msg.LLMRequest
{
    set req = ..%New()
    set req.RecipeId = recipeId
    set req.CacheKey = cacheKey
    set req.NoCache = +noCache
    set endpoint = $get(^FAST("llm", "endpoint"), "https://api.x.ai/v1")
    set req.Url = endpoint _ "/chat/completions"
    set body = {}
    set body.model = $get(^FAST("llm", "model"))
    set body.messages = [{"role": "system", "content": (prompt.system)}, {"role": "user", "content": (prompt.user)}]
    set body.temperature = 0
    set body."response_format" = {"type": "json_object"}
    set req.BodyJSON = body.%ToJSON()
    return req
}

}
