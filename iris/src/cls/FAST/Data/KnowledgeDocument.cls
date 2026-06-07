/// A knowledge chunk for native IRIS Vector Search.
/// Embeddings are computed at seed time and stored in the Embedding VECTOR
/// column; queries use VECTOR_DOT_PRODUCT. No keyword fallback — this is the
/// real IRIS Vector Search the contest is partly judged on.
///
/// Populate via SQL INSERT/UPDATE ... TO_VECTOR(<comma-list>, double, 384)
/// and query with VECTOR_DOT_PRODUCT(Embedding, TO_VECTOR(<query-list>, double, 384)).
///
/// LEN is fixed at 384 because VECTOR_DOT_PRODUCT requires a specified-length
/// vector column (a variable-length %Vector stores fine but cannot be searched
/// — SQLCODE -260). 384 is the native dimension of common small/cheap models
/// (e.g. all-MiniLM-L6-v2) and a dimension OpenAI's text-embedding-3 models can
/// also be asked to emit. The chosen provider MUST output 384 dims; if a
/// different dimension is required, change LEN here AND Embedder.MOCKDIM/Dim(),
/// recompile, then re-run SeedLoader + Embedder.EmbedAll().
Class FAST.Data.KnowledgeDocument Extends (%Persistent, %JSON.Adaptor)
{

Parameter %JSONIGNORENULL = 1;

Index CollectionIdx On Collection;

Index DocIdx On (Collection, DocumentId) [ Unique ];

/// e.g. payer_policies, clinical_followup_guidance, patient_education,
/// drug_guidance, trial_criteria, community_resources
Property Collection As %String(MAXLEN = 100) [ Required ];

Property DocumentId As %String(MAXLEN = 100) [ Required ];

Property Title As %String(MAXLEN = 500);

Property ChunkText As %String(MAXLEN = "");

Property MetadataJSON As %String(MAXLEN = "");

/// Native IRIS vector embedding (excluded from JSON projection — large/binary).
Property Embedding As %Vector(DATATYPE = "DOUBLE", LEN = 384, %JSONINCLUDE = "none");

/// Dimension of the stored embedding (0 until embedded in Phase 2).
Property EmbeddingDim As %Integer [ InitialExpression = 0 ];

Property CreatedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

}
