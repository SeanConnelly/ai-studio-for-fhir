# FHIR Agent Studio

**Build, run, and inspect AI agents for FHIR workflows on a single InterSystems IRIS
for Health container, with every step traceable.**

A developer portal that compiles healthcare AI agent workflows into runtime recipes,
runs them on a real IRIS Interoperability Production, and shows the full
**evidence → recommendation → FHIR action** loop for every run. It comes with a
clinician facing app and a patient phone app over the same backend.

Built for the InterSystems **"AI Agents for FHIR"** programming contest
([Open Exchange contest 46](https://openexchange.intersystems.com/contest/46)).

> This file is the single source of truth for the whole entry. If you only do two
> things: run the one command in [Quick start](#quick-start), then open the
> [guided demo](#start-with-the-guided-demo).

---

## Demo video

▶️ **Main demo  coming soon_.**

---

## What it is

AI is going to change healthcare, but only if clinicians can trust it and developers
can build it without reinventing the plumbing every time. FHIR Agent Studio is an
attempt at both: a place to build AI agents for FHIR workflows from reusable building
blocks, run them on a real InterSystems IRIS for Health backend, and inspect exactly
what each one did at every step.

It ships with **twelve working agents** over a synthetic FHIR repository of around
1,000 patients and 20,000 resources. The goal was a studio rather than a single demo:
somewhere you can design, run, and inspect many agents, and then build your own.
Everything runs on one container, with one command.

Every agent is a small clinical workflow described as data, a pipeline you can read
from left to right:

```
Trigger → Evidence (FHIR · SQL · Vector Search) → Agent (LLM) → Action (draft FHIR) → Trace
```

### Start with the guided demo

If you only do one thing, open the **guided demo**. It is a tour of all twelve agents,
each with a plain language description, a "Try it" link straight to the right screen,
and a note on what to watch for. You do not need to know anything about the project to
explore the whole thing in a few minutes.

![The guided demo: all twelve agents, each with a description and a Try it link](docs/screenshots/The%20Demo%20Page.png)

### Build agents in the Studio

The Studio is the developer portal. Every agent lives in one gallery: open one to run
it, inspect how it was compiled, or edit it. Creating a new agent starts from a blank
canvas or a ready made starter, and deploys in a single click.

![The Studio gallery, where every agent can be opened, run, inspected, or edited](docs/screenshots/FHIR%20Agent%20Studio%20Agents%20Page.png)

Building an agent is the standout feature. Instead of a wall of configuration, you get
the agent as a **pipeline of steps**, in the exact order the runtime executes them, and
you can **test each step on its own** against a real patient before you ever run the
whole thing. Read the FHIR record and see what comes back. Run the vector search and
see what it retrieves. You can even **preview the exact prompt** the agent will send to
the model, assembled from the evidence above it, before any AI call is made. When you
save, the studio compiles seven runtime artifacts and deploys them.

![The Build view: an agent as a pipeline of steps you can test one at a time, with a preview of the exact prompt](docs/screenshots/FHIR%20Agent%20Studio%20Build%20View%20-%20Smart%20Patient%20Summary%20Generator.png)

### Decision support where clinicians work

The same agents appear inside **Cedar Valley Health**, a clinician facing EHR. They are
not a separate "AI tab" bolted on the side; they surface as decision support in the
places a clinician already looks: a patient's chart, the problem list, the medication
list, and the worklists that flag who needs attention. Anything an agent proposes
arrives as a clear card the clinician can sign or decline. Nothing is written to the
record without a human saying yes.

![Cedar Valley Health: a patient chart with AI decision support woven into the clinician's workflow](docs/screenshots/Ceder%20Vally%20Health%20Patient%20Records.png)

### The same intelligence, written for patients

The third surface is a patient phone app. It runs the same agents, but speaks plain
language: lab results explained in everyday terms, a personal care plan, local support
services, and a simple symptom check. An agent's output is just structured data, so the
same result can be shown to a specialist one way and to a patient another.

![The patient portal: results, care plan, and support in plain language on a phone](docs/screenshots/Patient%20Portal%20Mobile%20Application.png)

---

## Quick start

**Prerequisites:** Docker and Git. Nothing else, and no API key. Give Docker about 8 GB
of RAM and 10 GB of disk. The first build pulls IRIS for Health (around 3 to 4 GB) and
bakes the entire demo (the SPA build, the ObjectScript, 1,000 FHIR patients, and real
embeddings), so it takes several minutes. Every later start is seconds.

```bash
git clone https://github.com/<your-org>/fhir-agent-studio.git
cd fhir-agent-studio
docker compose up --build
```

That single command builds the React apps, creates the IRIS `FAST` namespace and a
FHIR R4 endpoint, loads and compiles the ObjectScript via IPM, generates the synthetic
patient population and vector embeddings, and starts the interoperability production.
When it settles, open:

| Open this | URL |
|---|---|
| 🚀 **The demo** (start here: a guided tour of all 12 agents) | `http://localhost:42773/clinical/#/demo` |
| **Studio** (developer portal: build, run, inspect agents) | `http://localhost:42773/fhir-agent-studio/` |
| **Clinical** (clinician EHR) | `http://localhost:42773/clinical/` |
| **Patient portal** (patient phone app) | `http://localhost:42773/clinical/#/portal` |
| **API status** (health and record counts) | `http://localhost:42773/fhir-agent-studio/api/status` |

> Port **42773** is deliberately off IRIS's usual ranges so the demo won't collide with
> any IRIS a judge already runs. Change it in `docker-compose.yml` if needed.

---

## Getting started (your first 5 minutes)

1. **Open [the demo](http://localhost:42773/clinical/#/demo).** It is the guided tour:
   all 12 agents as numbered cards, each with a one line "what it does", a **Try it**
   link to the exact screen, and a "what to notice". Follow it in order.
2. **Try three agents from the worklists.** Imaging & Results Follow-Up (catches an
   abnormal result with no follow-up and drafts a Task), Prior Authorization (matches
   payer policy via Vector Search), and Natural Language to FHIR Query (turns a question
   into a validated read-only SQL query). Each shows a clinician result; expand
   **Under the hood** for the exact prompt, the evidence, and the live IRIS trace.
3. **Browse patients.** In the Clinical app open **Patients**. The rows marked with a
   ✨ are pre-loaded with full AI decision support; click one for a chart that lights up
   with a summary, medication safety, a care plan, and lab explanations.
4. **Build a new agent yourself.** In the Studio, the **Walkthrough** page (left nav)
   builds a brand new agent step by step in about three minutes: testing each evidence
   step, previewing the prompt, and getting a real cached AI result on the first run,
   with no key.
5. **Look under the hood.** See [Transparency](#transparency-every-run-shows-its-work).

New to the Studio? It has built in **Help** and **Walkthrough** pages (left nav).

---

## What we're demonstrating (scope)

The thesis: an agent platform is more than a model call. This entry shows the whole
lifecycle, three ways, all on IRIS:

- **A real authoring experience.** Compose an agent from reusable, discoverable parts
  (FHIR reads, named queries, your own read-only SQL, vector collections, output
  contracts), test every step, compile to seven runtime artifacts, and deploy to a live
  production. No code required, but nothing hand-waved.
- **A real runtime.** Every run is a genuine `Ens.Production` message flow (Business
  Service to Process to Operations), with native Vector Search, a real FHIR R4
  repository, a real LLM over HTTP, and a Visual Trace you can open in the Management
  Portal.
- **A real, safe clinical surface.** Agents surfaced as decision support for clinicians
  and patients, with every write-back a human reviewed draft.

In scope: the 12 suggested workflows end to end, the authoring studio, the two front
ends, and the IRIS substrate. Out of scope: production grade auth, multi-tenancy, and
real patient data. The population is synthetic and clearly labelled.

---

## A prototype, not a product

I want to be straight about what this is. FHIR Agent Studio is demoware. It was built
the way you build a prototype: quickly, to try out a set of ideas and see whether they
hold together. This first version is far from production ready, in both code quality and
design, and the patient data is synthetic for a reason. It is a demo, not a product.

What it does do well is make a case: that InterSystems IRIS is an excellent platform for
building an agent studio. Having the FHIR repository, the vector search, the
interoperability runtime, and the audit trail all in one place is what let an ambitious
idea become something that could actually be stood up and shown in the time a contest
allows. It is a starting point that, with more time, could grow into a comprehensive,
production grade design and implementation.

---

## How it works

An **agent definition** (JSON) names its trigger, the evidence to gather, the AI
instruction and output contract, and the draft action. The studio's ObjectScript
**compiler** turns it into seven artifacts (recipe, prompt, output schema, FHIR action
template, production settings, HealthConnect mapping, and IPM `module.xml`) and deploys
it. Each run flows through the production:

```
┌──────────────────────────────────────────────────────────────────────┐
│ React/Vite SPAs, served by IRIS at /fhir-agent-studio/ and /clinical/  │
├──────────────────────────────────────────────────────────────────────┤
│ ObjectScript REST API (FAST.API.Rest) at /fhir-agent-studio/api/       │
├──────────────────────────────────────────────────────────────────────┤
│ Compiler  →  7 CompiledArtifact records per agent                      │
├──────────────────────────────────────────────────────────────────────┤
│ REAL Ens.Production (FAST.Production), live message flow:               │
│   BS AgentTriggerService → BP AgentOrchestrator → BOs                   │
│     FHIRRead · SQLQuery · VectorSearch · (BP AIHub → BO LLMService)     │
│     · FHIRWriteback                                                     │
│   LLMService rides EnsLib.HTTP.OutboundAdapter (real HTTP egress)       │
├──────────────────────────────────────────────────────────────────────┤
│ AI: three tiers, bundled real cache → live (your key) → deterministic  │
│ Vector: native VECTOR_DOT_PRODUCT over real all-MiniLM embeddings       │
│ FHIR: real IRIS for Health FHIR R4 repository (HSFHIR_X0001_R)          │
└──────────────────────────────────────────────────────────────────────┘
```

**How each portal concept maps to a real Interoperability component** (visible in the
Studio's *HealthConnect Mapping* view and runnable in the Management Portal's Visual
Trace, as live components, not labels):

| Portal concept | IRIS Interoperability component |
|---|---|
| Trigger | `FAST.BS.AgentTriggerService` (Business Service) |
| Evidence · FHIR / SQL / Vector | `FAST.BO.FHIRRead` · `FAST.BO.SQLQuery` · `FAST.BO.VectorSearch` |
| Agent reasoning | `FAST.BP.AIHub` (Business Process) |
| LLM egress | `FAST.BO.LLMService` on `EnsLib.HTTP.OutboundAdapter` |
| FHIR action (draft) | `FAST.BO.FHIRWriteback` |
| Orchestration | `FAST.BP.AgentOrchestrator` (Business Process) |

More detail: [`docs/architecture.md`](docs/architecture.md) and
[`docs/use-cases.md`](docs/use-cases.md) (every agent, its evidence, and its trace).

---

## Why InterSystems IRIS is the right platform for AI Agents

Building reliable AI agents usually means stitching together a pile of separate
services: a database, a vector store, a workflow engine, an integration layer, a FHIR
server. IRIS for Health gives you all of that in **one platform**, and this project
leans on every part of it:

- **An orchestration layer.** The runtime is a real IRIS Interoperability Production.
  Each agent run is an actual Business Service to Business Process to Business
  Operations message flow, the same engine hospitals already use to move data between
  systems, here pointed at orchestrating and auditing AI agents. That is where the
  Visual Trace comes from, for free.
- **One database, with native vector search.** The same database holds the application
  data and the embeddings. Retrieval is real native `VECTOR_DOT_PRODUCT` over a vector
  column, with no separate vector store to run and no data to keep in sync.
- **A real FHIR server.** Clinical data lives in the IRIS for Health FHIR R4
  repository, queried through the FHIR SQL projections and written back as draft FHIR
  resources, not a JSON file dressed up as FHIR.
- **Packaging and deployment.** It installs as a package (IPM and `module.xml`) and runs
  from one Docker command.

---

## Contest bonuses: what's included and where to see it

| Bonus | Where it lives | See it |
|---|---|---|
| **Suggested task** | All 12 implemented; the featured one is the **Imaging & Results Follow-Up Tracker** | The demo, card 1 |
| **InterSystems FHIR server** | Real IRIS for Health FHIR R4 repo (`HSFHIR_X0001_R`), around 1,000 patients and 20k resources, served at `/fhir-agent-studio/fhir/r4` | Any chart; `/api/status` counts |
| **Native Vector Search** | `VECTOR_DOT_PRODUCT` over real all-MiniLM embeddings, grounding prior-auth, social prescribing, trials, and the lab explainer | Prior Auth, then "Under the hood", then evidence |
| **LLM / AI** | Every result authored by a real LLM (xAI Grok, OpenAI compatible HTTP) via `FAST.BO.LLMService` | Any run, then "Under the hood", then transcript |
| **Embedded Python** | A read-only SQL gate parses LLM generated SQL with `sqlparse` on IRIS's bundled Python; it runs out of process because we found an in-process callin crash on the 2026.x image (reported) | NL to FHIR run, `readOnlyGuard: objectscript+sqlparse` |
| **Interoperability** | Real `Ens.Production`, BS/BP/BO message flow, Visual Trace, HTTP outbound adapter | Studio Inspect; Management Portal Visual Trace |
| **IPM / module.xml** | Package first; `zpm load` provisions everything at build | `module.xml`; build log |
| **Docker** | One command `docker compose up --build` | [Quick start](#quick-start) |
| **Bug found and reported** | Reproducible in-process Embedded Python crash on `irishealth-community` 2026.x (a regression vs 2025.3) | [`docs/embedded-python-bug.md`](docs/embedded-python-bug.md) |
| **Online demo / videos / articles** | _Links added as they go live_ | This section |

---

## The twelve agents

| Agent | Category | Suggested task |
|---|---|---|
| Abnormal Results Follow-Up | Patient Safety | Imaging & Results Follow-Up Tracker |
| Prior Authorization Evidence | Administrative | FHIR Prior Authorization Copilot |
| Natural Language to FHIR Query | Developer Experience | NL to FHIR Query Explorer |
| Smart Patient Summary | Clinical Summary | Smart Patient Summary Generator |
| Gaps in Care Finder | Population Health | Gaps in Care Finder |
| Medication Safety Assistant | Medication Safety | Medication Safety & Interaction Assistant |
| Care Plan Navigator | Care Coordination | AI Powered Care Plan Navigator |
| SDOH Referral Matcher | Social Care | SDOH & Community Referral Matcher |
| Clinical Trial Matcher | Research | FHIR Clinical Trial Matcher |
| Readmission Risk Workbench | Risk Stratification | Hospital Readmission Risk Workbench |
| Conversational Triage Assistant | Triage | Conversational FHIR Triage Assistant |
| Patient-Friendly Lab Explainer | Patient Engagement | Patient-Friendly Lab Explainer |

---

## Transparency: every run shows its work

A clinical agent that can explain itself is one a clinician can actually use, so
transparency is built in. For every run you can open:

- **The transcript.** The exact prompt the agent assembled and the raw model response.
  The JSON the model returned *is* the result you see on screen.
- **The Visual Trace.** IRIS's own Management Portal replays the run as a flow of
  messages: the FHIR read, the SQL query, the vector search, the LLM call (request and
  response, on a real HTTP outbound adapter), and the drafted FHIR action.
- **The response history.** The Studio's **AI Hub** lists every model response with its
  prompt, timestamp, and a hash, all browsable.

And when an agent does not have the evidence to answer, it says so and falls back to a
clearly labelled path that is never presented as AI.

**The AI in three tiers.** Demo runs replay bundled real LLM output with no key needed.
Novel prompts call a live model; you can add your own OpenAI compatible key in Admin
for unlimited use, held in memory only and never stored. With no cache and no key, a
deterministic fallback runs and is clearly labelled as not AI. Vector search is always
real native IRIS Vector Search.

**Safety.** Every clinical or administrative write-back is a draft requiring human
review, never auto-committed. The UI labels drafts, the trace shows the writeback as
`drafted`, and approval commits to FHIR with an audit trail.

---

## Local development

The repo runs as one image (above). To iterate on a front end with hot reload while the
backend runs in Docker:

```bash
docker compose up --build -d                 # IRIS plus everything baked in
cd frontend && npm install && npm run dev     # http://localhost:5173/fhir-agent-studio/
```

Vite proxies `/api` to IRIS on 42773. Back end changes are picked up by rebuilding the
image. Package first install (also done automatically by the Docker build):

```objectscript
zpm "load /path/to/fhir-agent-studio -v"
```

## REST API (overview)

Base: `/fhir-agent-studio/api`

```
GET  /status                            health and record counts
GET  /templates  ·  /templates/:slug    list agents · agent and definition (incl. inputs)
POST /flows/:slug/run                    run an agent { inputs:{…}, skipCache? }
POST /flows/:slug/compile                compile to 7 artefacts
GET  /flows/:slug/artifacts[/:name]      list / fetch compiled artefacts
GET  /flows/:slug/healthconnect-mapping  agent to interoperability component map
POST /authoring/step-test                test one builder step (real engine call)
POST /authoring/prompt-preview           the exact prompt a run would send (no AI call)
GET  /options/patients                   real FHIR patients (picker)
GET  /invocations[/:id]  ·  /traces/:id  runtime results · trace steps
GET  /admin/llm  ·  /admin/llm/cache     AI connection state · browsable response corpus
POST /admin/seed                         reload demo data and embeddings
```

## Tech stack

IRIS for Health Community Edition (FHIR R4, Interoperability, native Vector Search) ·
ObjectScript · IPM (`module.xml`) · React, TypeScript, Vite, Tailwind, shadcn/ui ·
xAI Grok (OpenAI compatible) · all-MiniLM embeddings · Docker.

## Documentation

- [`docs/use-cases.md`](docs/use-cases.md): every agent, its evidence, output, and trace.
- [`docs/architecture.md`](docs/architecture.md) and [`docs/diagrams.md`](docs/diagrams.md): design and sequence diagrams.
- [`docs/demo-script.md`](docs/demo-script.md): a click-by-click demo walkthrough.
- [`docs/troubleshooting.md`](docs/troubleshooting.md): common issues (ports, reseeding).
- [`docs/embedded-python-bug.md`](docs/embedded-python-bug.md): the Embedded Python crash we found and reported.

## License

MIT, see [`LICENSE`](LICENSE).
