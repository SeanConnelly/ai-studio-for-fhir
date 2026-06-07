/// Record/replay cache for real LLM responses. Lets the demo serve genuine
/// pre-generated Grok output with NO key and reproducibly. Keyed by a stable
/// hash of (recipe + model + promptVersion + prompt). Bundled as
/// /seed/llm-cache/completions.json and loaded at seed time.
Class FAST.Data.LLMCache Extends (%Persistent, %JSON.Adaptor)
{

Parameter %JSONIGNORENULL = 1;

Index KeyIdx On CacheKey [ Unique ];

Property CacheKey As %String(MAXLEN = 200) [ Required ];

/// completion | embedding
Property Kind As %String(MAXLEN = 20) [ InitialExpression = "completion" ];

Property Model As %String(MAXLEN = 100);

Property PromptVersion As %String(MAXLEN = 20);

/// Truncated prompt, for transparency/debugging (not used for matching).
Property InputPreview As %String(MAXLEN = 2000);

Property OutputJSON As %String(MAXLEN = "");

Property CreatedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

}
