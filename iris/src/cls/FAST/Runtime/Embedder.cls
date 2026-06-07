/// Turns text into an embedding vector for native IRIS Vector Search.
///
/// Mode is read from ^FAST("llm","embedMode") (or "mode"),
/// defaulting to "mock". "external" calls a real embedding provider over HTTP
/// (Ollama all-minilm by default — see EmbedExternal). "mock" is a deterministic,
/// offline-dev fallback that produces a real normalised vector from a hashed bag
/// of words — the VECTOR column and VECTOR_DOT_PRODUCT search are genuine IRIS
/// Vector Search either way; only the source of the numbers differs.
Class FAST.Runtime.Embedder [ Abstract ]
{

/// Must equal KnowledgeDocument.Embedding LEN (the searchable vector length).
Parameter MOCKDIM = 384;

/// Default embedding provider endpoint (Ollama on the host, reached from the
/// container via host.docker.internal). all-minilm emits 384-dim vectors,
/// matching MOCKDIM / the KnowledgeDocument.Embedding column.
Parameter EMBEDENDPOINT = "http://host.docker.internal:11434";

Parameter EMBEDMODEL = "all-minilm";

/// Bump to invalidate bundled embedding-cache entries (changes the cache key).
Parameter EMBEDVERSION = "1";

ClassMethod Mode() As %String
{
    // "external" routes through the embedding cache (bundled real vectors → live
    // provider on miss → mock as a last resort). "mock" forces the offline hash.
    // Defaults to "external" so the bundled real embeddings drive Vector Search
    // even with no provider; the cache fallback keeps it from ever erroring.
    return $get(^FAST("llm", "embedMode"), "external")
}

ClassMethod Dim() As %Integer
{
    // Must match KnowledgeDocument.Embedding LEN (384). External providers
    // should be configured to emit 384-dim vectors (e.g. OpenAI 'dimensions').
    if ..Mode() = "external" return +$get(^FAST("llm", "embedDim"), ..#MOCKDIM)
    return ..#MOCKDIM
}

/// Return a comma-delimited vector string for TO_VECTOR(..., double, Dim()).
/// In external mode this is the record/replay path: bundled real vector (cache
/// hit) → live provider (miss + reachable) → mock (last resort). In mock mode
/// it's the offline hash. Either way it returns a usable 384-dim vector.
ClassMethod Embed(text As %String) As %String
{
    if ..Mode() = "external" return ..EmbedCached(text)
    set ^FAST("llm", "embedLastSource") = "mock"
    return ..EmbedMock(text)
}

/// Cache key for an embedding: model + version + hash(text). Mirrors the LLM
/// completion cache so bundled real embeddings replay with no provider.
ClassMethod EmbedCacheKey(text As %String) As %String
{
    set model = $get(^FAST("llm", "embedModel"), ..#EMBEDMODEL)
    return "embed|" _ model _ "|" _ ..#EMBEDVERSION _ "|" _ $zcrc(text, 7) _ "-" _ $length(text)
}

/// Three-tier external embedding: cached bundled vector → live provider (stored
/// to cache) → deterministic mock. Sets ^FAST("llm","embedLastSource") honestly.
ClassMethod EmbedCached(text As %String) As %String
{
    set key = ..EmbedCacheKey(text)

    // Tier 1 — bundled / previously-cached real embedding (no provider needed).
    set hit = ##class(FAST.Data.LLMCache).KeyIdxOpen(key)
    if $isobject(hit) && (hit.OutputJSON '= "") {
        set ^FAST("llm", "embedLastSource") = "cached"
        return hit.OutputJSON
    }

    // Tier 2 — live provider; store the real vector to the cache on success.
    set vec = ..EmbedExternal(text)
    if $get(^FAST("llm", "embedLastSource")) [ "external" {
        do ..StoreCache(key, vec, text)
        return vec
    }

    // Tier 3 — EmbedExternal already fell back to mock and set the label.
    return vec
}

/// Upsert a real embedding into the LLM cache (Kind="embedding").
ClassMethod StoreCache(key As %String, vec As %String, text As %String)
{
    set c = ##class(FAST.Data.LLMCache).KeyIdxOpen(key)
    if '$isobject(c) {
        set c = ##class(FAST.Data.LLMCache).%New()
        set c.CacheKey = key
    }
    set c.Kind = "embedding"
    set c.Model = $get(^FAST("llm", "embedModel"), ..#EMBEDMODEL)
    set c.PromptVersion = ..#EMBEDVERSION
    set c.InputPreview = $extract(text, 1, 500)
    set c.OutputJSON = vec
    do c.%Save()
}

ClassMethod EmbedMock(text As %String) As %String
{
    set dim = ..#MOCKDIM
    for i = 1:1:dim { set v(i) = 0 }
    // tokenise: keep alphanumeric runs, lowercase
    set clean = "", text = $zconvert(text, "l")
    for i = 1:1:$length(text) {
        set c = $extract(text, i)
        if (c ? 1A) || (c ? 1N) { set clean = clean _ c } else { set clean = clean _ " " }
    }
    for p = 1:1:$length(clean, " ") {
        set tok = $piece(clean, " ", p)
        if $length(tok) < 2 continue
        set idx = ($zcrc(tok, 7) # dim) + 1
        set v(idx) = v(idx) + 1
    }
    set norm = 0
    for i = 1:1:dim { set norm = norm + (v(i) * v(i)) }
    set norm = $select(norm > 0: $zsqr(norm), 1: 1)
    set s = ""
    for i = 1:1:dim { set s = s _ $select(i = 1: "", 1: ",") _ (v(i) / norm) }
    return s
}

/// HTTP call to a real embedding provider (Ollama by default). POSTs the text
/// to {endpoint}/api/embeddings and returns the vector as a comma-delimited
/// string for TO_VECTOR(..., double, Dim()). Config is read from
/// ^FAST("llm","embedEndpoint" / "embedModel") with sensible Ollama defaults.
/// On any failure it falls back to the deterministic mock so seeding never
/// breaks — callers can check ..Mode() / ..LastSource() for the honest label.
ClassMethod EmbedExternal(text As %String) As %String
{
    set endpoint = $get(^FAST("llm", "embedEndpoint"), ..#EMBEDENDPOINT)
    set model = $get(^FAST("llm", "embedModel"), ..#EMBEDMODEL)

    // parse endpoint → host + port + scheme
    set https = ($extract($zconvert(endpoint, "l"), 1, 5) = "https")
    set host = $replace($replace(endpoint, "https://", ""), "http://", "")
    set basePath = ""
    if host [ "/" {
        set basePath = "/" _ $piece(host, "/", 2, *)
        set host = $piece(host, "/", 1)
    }
    set port = $select(host [ ":": $piece(host, ":", 2), https: 443, 1: 80)
    set host = $piece(host, ":", 1)

    try {
        set req = ##class(%Net.HttpRequest).%New()
        set req.Server = host
        set req.Port = port
        set req.Https = https
        if https set req.SSLConfiguration = ##class(FAST.Runtime.LLMClient).EnsureSSL()
        set req.ContentType = "application/json"
        set req.Timeout = 30
        set body = {}
        set body.model = model
        set body.prompt = text
        do req.EntityBody.Write(body.%ToJSON())
        set sc = req.Post(basePath _ "/api/embeddings")
        if $$$ISERR(sc) throw ##class(%Exception.StatusException).CreateFromStatus(sc)
        if (req.HttpResponse.StatusCode '= 200) {
            throw ##class(%Exception.General).%New("HTTP " _ req.HttpResponse.StatusCode)
        }
        set resp = ##class(%DynamicAbstractObject).%FromJSON(req.HttpResponse.Data)
        if '$isobject(resp.embedding) || (resp.embedding.%Size() = 0) {
            throw ##class(%Exception.General).%New("no embedding in response")
        }
        set s = "", it = resp.embedding.%GetIterator()
        while it.%GetNext(.k, .val) { set s = s _ $select(s = "": "", 1: ",") _ val }
        set ^FAST("llm", "embedLastSource") = "external (" _ model _ ")"
        return s
    } catch ex {
        set ^FAST("llm", "embedLastSource") = "mock (external failed: " _ ex.DisplayString() _ ")"
        return ..EmbedMock(text)
    }
}

/// Diagnostic source label for the last external embed (honest reporting).
ClassMethod LastSource() As %String
{
    return $get(^FAST("llm", "embedLastSource"), $select(..Mode() = "external": "external", 1: "mock"))
}

/// Diagnostic: round-trip a trivial text through the configured provider.
ClassMethod Probe() As %String
{
    set vec = ..EmbedExternal("abnormal lab result follow-up")
    return "dims=" _ $length(vec, ",") _ " source=" _ ..LastSource() _ " first=" _ $piece(vec, ",", 1, 3)
}

/// (Re)compute and store embeddings for every KnowledgeDocument.
/// Run after seeding, and again whenever the embedding model changes.
ClassMethod EmbedAll() As %Integer
{
    set dim = ..Dim()
    set upd = ##class(%SQL.Statement).%New()
    set sc = upd.%Prepare("UPDATE FAST_Data.KnowledgeDocument SET Embedding = TO_VECTOR(?, double, ?), EmbeddingDim = ? WHERE ID = ?")
    if $$$ISERR(sc) { write "prepare err: ", $system.Status.GetErrorText(sc), ! return 0 }
    set count = 0
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT ID, Title, ChunkText FROM FAST_Data.KnowledgeDocument")
    while rs.%Next() {
        set vec = ..Embed(rs.%Get("Title") _ " " _ rs.%Get("ChunkText"))
        set r = upd.%Execute(vec, dim, dim, rs.%Get("ID"))
        if r.%SQLCODE >= 0 set count = count + 1
    }
    write "Embedded ", count, " documents at dim ", dim, " (mode=", ..Mode(), ").", !
    return count
}

}
