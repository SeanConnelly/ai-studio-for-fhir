/// HealthConnect-style Business Operation: native IRIS Vector Search over
/// KnowledgeDocument. Embeds the query, then ranks chunks with
/// VECTOR_DOT_PRODUCT. No keyword fallback — this is real IRIS Vector Search.
Class FAST.Runtime.VectorSearchOperation [ Abstract ]
{

/// Diagnostic: run the search and report SQLCODE/message/row count.
ClassMethod Probe(collection As %String, queryText As %String) As %String
{
    set qvec = ##class(FAST.Runtime.Embedder).Embed(queryText)
    set dim = ##class(FAST.Runtime.Embedder).Dim()
    set sql = "SELECT TOP 3 DocumentId, VECTOR_DOT_PRODUCT(Embedding, TO_VECTOR(?, double, " _ (+dim) _ ")) AS score FROM FAST_Data.KnowledgeDocument WHERE Collection = ? AND EmbeddingDim > 0 ORDER BY score DESC"
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, sql, qvec, collection)
    set n = 0, top = ""
    while rs.%Next() { set n = n + 1 if n = 1 set top = rs.%Get("DocumentId") _ " @ " _ rs.%Get("score") }
    return "SQLCODE=" _ rs.%SQLCODE _ " msg=[" _ rs.%Message _ "] rows=" _ n _ " top=" _ top
}

/// Return the top-K knowledge chunks in a collection ranked by similarity to
/// queryText. Each element: {documentId, title, chunkText, score}.
ClassMethod Search(collection As %String, queryText As %String, topK As %Integer = 3) As %DynamicArray
{
    set results = []
    set qvec = ##class(FAST.Runtime.Embedder).Embed(queryText)
    set dim = ##class(FAST.Runtime.Embedder).Dim()
    set sql = "SELECT TOP " _ (+topK) _ " DocumentId, Title, ChunkText, "
            _ "VECTOR_DOT_PRODUCT(Embedding, TO_VECTOR(?, double, ?)) AS score "
            _ "FROM FAST_Data.KnowledgeDocument "
            _ "WHERE Collection = ? AND EmbeddingDim > 0 ORDER BY score DESC"
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, sql, qvec, dim, collection)
    while rs.%Next() {
        set o = {}
        set o.documentId = rs.%Get("DocumentId")
        set o.title = rs.%Get("Title")
        set o.chunkText = rs.%Get("ChunkText")
        set o.score = rs.%Get("score")
        do results.%Push(o)
    }
    return results
}

}
