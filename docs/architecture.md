# Architecture

FHIR Agent Studio is a single **IRIS for Health** application: an ObjectScript REST
API + compiler + a real IRIS Interoperability production, with a React SPA that IRIS
serves. No separate backend, no non-IRIS database. Everything runs in a dedicated
**`FAST`** namespace (HS-enabled, interoperability on, with a real FHIR R4 endpoint).

## Layers

1. **SPA (React + TypeScript + Vite + shadcn/ui)** — served by IRIS via the
   `FAST.API.Portal` dispatch class. Hash router, so no server-side route rewriting
   is required. Talks only to the REST API.
2. **REST API (`FAST.API.Rest`, `%CSP.REST`)** — JSON over `/fhir-agent-studio/api`.
   Unauthenticated for a frictionless demo.
3. **Compiler (`FAST.Compiler.*`)** — turns a flow definition into seven artefacts,
   persisted as `CompiledArtifact` records.
4. **Runtime — a real `Ens.Production` (`FAST.Production`).** `FAST.Runtime.Runtime`
   drives the production through `Ens.Director`; each recipe run is a genuine
   Business Service → Business Process → Business Operation message flow, fully
   visible in the Management Portal's Visual Trace.
5. **FHIR R4 repository** — a real IRIS for Health FHIR server at
   `/fhir-agent-studio/fhir/r4` (`HSFHIR_X0001_R` storage + FHIR SQL Builder
   projections). This is the clinical source of truth, not a custom table.
6. **Persistence (`FAST.Data.*`, SQL schema `FAST_Data`)** — all durable app state.

## Persistent data model

| Class | Purpose |
|---|---|
| `Template` | The 12 reusable workflow templates (system data) |
| `FlowDefinition` | User/template-derived flows (editable, compilable) |
| `CompiledArtifact` | Compiler outputs (one row per artefact per flow) |
| `DeployedRecipe` | Registered recipe for runtime execution |
| `AgentInvocation` | One runtime execution (request + response) |
| `TraceStep` | Trace steps in Business Service/Process/Operation terms |
| `EvidenceItem` | Evidence gathered during a run |
| `ProposedAction` | Drafted FHIR write-back (never auto-committed) |
| `KnowledgeDocument` | Vector-searchable knowledge chunks (`%Vector` column) |
| `LLMCache` | Bundled real LLM responses (record/replay) for the key-free demo |
| `ImportExportJob` | Import/export audit |

Clinical resources are **not** a FAST class — they live in the real FHIR R4
repository (above) and are read by `FAST.BO.FHIRRead`.

## Compile flow

```
FlowDefinition.DefinitionJSON
  → Validator (shape check)
  → ArtifactGenerator + MappingGenerator
  → 7 CompiledArtifact rows:
      recipe.json, prompt.md, output-schema.json,
      fhir-action-template.json, production-settings.json,
      healthconnect-mapping.json, module.xml
  → FlowDefinition.Status = "compiled"
```

Artefact generation is **definition-driven**: components and mappings appear only when
the matching evidence exists (e.g. no `FAST.BO.VectorSearch` if the flow has no vector
collections; a read-only action emits a "no write-back" template).

## Runtime flow (real production message path)

```
RunRecipe(recipeId, patientRef, context)
  → EnsureProduction (start FAST.Production if not running)
  → create AgentInvocation + trace
  → [BS] FAST.BS.AgentTriggerService   receives the AgentRequest
  → [BP] FAST.BP.AgentOrchestrator     loads recipe, calls operations in order:
       → [BO] FAST.BO.FHIRRead         (if evidence.fhir)   ← reads the FHIR R4 repo
       → [BO] FAST.BO.SQLQuery         (if evidence.sql)    ← over FHIR SQL projections
       → [BO] FAST.BO.VectorSearch     (if evidence.vector) ← native IRIS vectors
       → [BO] FAST.BO.AIHub            cache → BYO-key → deterministic
       → [BO] FAST.BO.FHIRWriteback    (if action is draft-*)  ← drafts only
  → persist evidence, finalize invocation, return AgentResponse + trace
```

Because this is a real production, the same run is also recorded as `Ens.MessageHeader`
records — the Visual Trace in the Management Portal shows the identical flow.

## AIHub LLM resolution (3-tier)

`FAST.BO.AIHub` builds a deterministic, evidence-grounded scaffold, then overlays LLM
reasoning resolved in three tiers:

1. **Cache** (`FAST.Data.LLMCache`) — a bundled real Grok response, keyed by
   `recipeId | model | promptVersion | hash(prompt)`. Needs **no API key**, so the
   demo is fully reproducible offline. (The cohort data and prompt are deterministic
   so the key is stable across reseeds — see `seed/llm-cache/`.)
2. **Live (BYO-key)** — if `^FAST("llm","key")` is set, calls the OpenAI-compatible
   provider over HTTP and caches the result.
3. **Deterministic mock** — the scaffold itself, if neither above applies.

## Vector search

`KnowledgeDocument.Embedding` is a native IRIS `%Vector(DATATYPE="DOUBLE", LEN=384)`
column. Documents are embedded at seed time (`Embedder.EmbedAll`) and queried with
`VECTOR_DOT_PRODUCT(Embedding, TO_VECTOR(<query>, double, 384))`. `LEN` is fixed
because a searchable vector column requires a specified length; 384 matches the
`all-minilm` embedding model used here.

Embeddings are **real model vectors** from **Ollama `all-minilm`** (OpenAI/Ollama-
compatible HTTP). To keep the key-free demo reproducible offline, `Embedder` uses the
same record/replay cache as the LLM (`FAST.Data.LLMCache`, `Kind="embedding"`): a
cache hit returns the bundled real vector (`seed/llm-cache/embeddings.json`), a miss
with a reachable provider embeds live and stores it, and only with neither does it
fall back to a deterministic hash. So `EmbedAll` and the demo-preset queries replay
genuine model embeddings with **no provider needed**; a judge can point
`^FAST("llm","embedEndpoint")` at their own Ollama to embed novel queries live.

## Packaging

The production `Dockerfile` builds the SPA (Node stage), then in the IRIS stage bakes
the whole application into the image layer:

1. `create-fast-namespace.script` (run from `HSLIB`) — creates the `FAST` namespace
   via `HS.Util.Installer.Foundation.Install` and stands up the FHIR R4 endpoint via
   `HS.FHIRServer.Installer.InstallInstance`.
2. `iris.script` — `zpm load` of `module.xml` (IPM), which compiles `FAST.*`, then
   `Invoke`s `FAST.Setup.PostInstall`: unexpire passwords, create the REST + SPA web
   apps, seed templates / knowledge / LLM cache, load hero + synthetic FHIR resources
   into the repository, compute embeddings, and start `FAST.Production`.

The image therefore ships fully provisioned — `docker compose up` is the only step.
