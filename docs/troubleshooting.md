# Troubleshooting

| Problem | Fix |
|---|---|
| **Port 42773 already in use** | Edit the host port mapping in `docker-compose.yml` (e.g. `"42883:52773"`) and open the new port. 42773 was chosen off IRIS's default ranges to avoid clashes, but any local service can still take it. |
| **Portal shows a blank page** | Run `docker compose logs iris` and confirm the build's IPM step finished (look for `Configure SUCCESS` / `Seeded: 12 templates`). Hard-refresh the browser (assets are content-hashed). |
| **`/fhir-agent-studio/` 404s** | Confirm the build baked the SPA: `docker compose exec iris ls /usr/irissys/csp/fhir-agent-studio` should list `index.html` + `assets/`. The SPA is served by the `FAST.API.Portal` dispatch (IRIS static apps don't auto-serve a directory index). |
| **Templates missing / counts are 0** | In the portal, **Admin → Reload seed data**, or `curl -X POST http://localhost:42773/fhir-agent-studio/api/admin/seed`. |
| **Vector search returns nothing** | Embeddings may not be computed. Reload seed data (it loads the bundled real embeddings then runs `Embedder.EmbedAll`, which replays them). The `KnowledgeDocument.Embedding` column is fixed at 384 dims; a searchable vector column needs a specified length. |
| **Vector results look random for a query you typed yourself** | The bundled embeddings (`seed/llm-cache/embeddings.json`, real `all-minilm` vectors) cover the demo presets. A *novel* query with no live embedding provider falls back to the deterministic hash for that one query, so its ranking is not semantic. To embed novel queries live, run Ollama (`ollama pull all-minilm`) and point `^FAST("llm","embedEndpoint")` at it (default `http://host.docker.internal:11434`). |
| **Container keeps restarting with "Community License expired"** | Your cached base image is stale. `docker pull intersystemsdc/irishealth-community:latest` (and `:2026.1-zpm`) to get a current license, then rebuild. (The misleading "may have exceeded core limit" line usually means *expired*, not cores.) |
| **API returns 401** (dev, Atelier CLI) | You're hitting a *different* IRIS on the same port. The app's own API (`/fhir-agent-studio/api`) is unauthenticated and should never 401; if the npm `iris` CLI 401s, confirm `.env` `IRIS_PORT=42773` points at *this* container, not a host IRIS. |
| **LLM calls fail** | The demo doesn't need a key (it serves bundled cached responses, then falls back to the deterministic agent). To use live calls, set an OpenAI-compatible base URL + model + key (see `.env.example`). |
| **`docker compose up --build` is slow the first time** | It pulls the IRIS image and builds the SPA. Subsequent builds are cached. |

## Logs & shell

```bash
docker compose logs -f iris                                  # container logs
docker compose exec iris iris session iris -U FAST           # IRIS terminal
curl http://localhost:42773/fhir-agent-studio/api/status     # health + counts
```
