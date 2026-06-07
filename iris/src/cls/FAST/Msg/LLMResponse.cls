/// The LLMService's answer to an LLMRequest. Truthful about transport: when the
/// completion came from the bundled record/replay corpus, Source="cached",
/// HttpStatus is empty and the Note says no network call was made; when a live
/// HTTPS call happened, HttpStatus carries the real status code.
Class FAST.Msg.LLMResponse Extends Ens.Response
{

/// "cached" | "live (<model>)" | "none" (no cache + no key) | "error".
Property Source As %String(MAXLEN = 100);

/// The real HTTP status code for live calls; empty when no call was made.
Property HttpStatus As %String(MAXLEN = 10);

/// Plain-language transport note shown in the Visual Trace payload.
Property Note As %String(MAXLEN = 1000);

/// The completion content (the JSON the model returned). For cached replies
/// this is the original model output, stored verbatim at generation time.
Property CompletionJSON As %String(MAXLEN = "");

Property Error As %String(MAXLEN = 2000);

}
