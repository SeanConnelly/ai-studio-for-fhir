# Demo Video Script — FHIR Agent Studio

**Target length:** 5–6 minutes. **Audience:** contest judges (Complexity, Clarity,
Developer Experience, Applicability, Usability).

**One-sentence pitch to keep in mind:** *An IRIS-native developer portal that
compiles FHIR AI-agent workflows into HealthConnect-style runtime recipes, then
runs them with a traceable evidence → recommendation → FHIR-action loop.*

---

## Before you record (setup)

- Start the app the judge way: `docker compose up --build`, wait until healthy.
- Open `http://localhost:42773/fhir-agent-studio/` in a clean browser window (lands on **Agents**).
- Reset to a pristine state: **Admin → Reload seed data** (so counts/demo are fresh).
- Browser at ~110–125% zoom, 1080p capture, hide bookmarks bar.
- Have a terminal window ready (for the one-command start shot).
- Keep narration calm and specific; let the Trace Timeline and Mapping views breathe.

---

## Scene 1 — Hook + what it is  (0:00–0:35)

**On screen:** the Agents gallery (already loaded).

**Narration:**
> "This is FHIR Agent Studio — an IRIS-native developer portal for building AI
> agents that work *inside* a HealthConnect-style interoperability flow. Instead of
> hard-coding one chatbot, developers design a workflow from healthcare concepts —
> a trigger, the evidence to gather, an agent instruction, and a FHIR action — and
> the studio compiles it into runtime recipes that execute on IRIS. Everything you'll
> see is served by a single IRIS for Health container."

## Scene 2 — One-command start  (0:35–1:00)

**On screen:** terminal showing `docker compose up --build` (can be pre-run; show the
tail), then switch to the browser and the "IRIS Runtime Connected" badge in the header.

**Narration:**
> "One command builds the React front end, bakes the ObjectScript backend, demo data,
> and vector embeddings into the image via the InterSystems Package Manager, and IRIS
> serves the whole thing. No separate backend, no database to install, no API key
> required to start."

## Scene 3 — The gallery: agents, not apps  (1:00–1:30)

**On screen:** scroll the 12 agent cards; point at the three "Featured" badges.

**Narration:**
> "It ships with all twelve of the contest's suggested workflows — but these aren't
> twelve separate apps. They're twelve database-backed agents that share one
> build-and-run model. Three are polished end-to-end: Abnormal Results Follow-Up,
> Prior Authorization, and Natural Language to FHIR Query."

## Scene 4 — Run it: inputs → result → under the hood  (1:30–3:00)

**On screen:** click *Abnormal Results Follow-Up* → lands in its workspace on the
**Run** tab. Show the input panel — a **real patient picker** and the patient's
**abnormal report**, both pulled from the FHIR repository. Press **Run**. Walk the
clean **result**: the summary, "no follow-up found", the recommendation, and the
**draft Task** with the amber "requires human review" badge. Then expand **Under the
hood** to reveal the AI source badge, the evidence, and the **Trace Timeline**; expand
one step's payload.

**Narration:**
> "You open an agent and run it like a real application: pick a patient, pick the
> abnormal report — these come straight from the FHIR repository — and run. The agent
> finds an HbA1c of 11.2% with no documented follow-up and drafts a FHIR Task to close
> the loop. Notice it's a *draft*: every write-back requires human review, never
> auto-committed. That clean result is all a clinician needs — but a developer can open
> 'under the hood' to see exactly how it ran. Here's the completion transcript: the base
> prompt, the gathered evidence combined into one request, and the raw LLM response that
> became this result — the result is authored by the model from the evidence, not
> assembled in code. Below it, whether the response was cached or live, and the full
> trace through a real IRIS interoperability production — Business Service, Process, and
> the FHIR Read, SQL, Vector Search, AI, and Writeback operations."

## Scene 5 — Inspect: the build + the production  (3:00–3:45)

**On screen:** switch to the **Inspect** tab. Show "Runs on IRIS Interoperability" (the
agent-concept → Business-Service/Process/Operation mapping) and the **generated build
output** (the seven artefacts — recipe.json, prompt.md, healthconnect-mapping.json,
fhir-action-template.json, module.xml…). Then click the **Management Portal** link
(top-right), navigate to Interoperability → **FAST.Production**, and open the **Visual
Trace** for the run you just executed — the same Business Service → Process →
Operations message flow.

**Narration:**
> "Inspect shows what the studio generated under the agent: the compiler emits seven
> runtime artefacts into IRIS — an executable recipe, the agent prompt, an output
> schema, a FHIR action template, production settings, the HealthConnect mapping, and an
> IPM module manifest. And the mapping isn't a diagram — these are real, running
> components. Here's the exact run I just did, in the IRIS Management Portal's Visual
> Trace: real messages, real components. The runtime stays generic — the
> workflow-specific logic lives entirely in the compiled recipe."

## Scene 6 — Prior Auth + real Vector Search  (3:45–4:30)

**On screen:** Agents → *Prior Authorization* → **Run**. Show the **Criteria met** vs
**Still missing** cards; expand **Under the hood** for the evidence items sourced from
`payer_policies`.

**Narration:**
> "The Prior Authorization agent assembles the evidence packet: it confirms the BMI and
> a failed prior therapy, and — using real IRIS Vector Search over payer-policy
> documents — flags the one missing requirement, a documented six-month lifestyle
> program. That's the difference between an approval and a denial, surfaced
> automatically. Vector search here is genuine IRIS native vector search, not a keyword
> shortcut."

## Scene 7 — Natural Language → FHIR Query  (4:30–5:00)

**On screen:** Agents → *Natural Language to FHIR Query* → type the question → **Run**.
Show the interpreted intent, the generated SQL (highlighted), the `approved` validation
badge, and the result table.

**Narration:**
> "And for developer experience: a natural-language question becomes a transparent,
> read-only query. The LLM writes real SQL against the IRIS FHIR SQL projections; we
> validate it as read-only, then actually execute it against the live FHIR repository.
> You see the interpreted intent, the exact generated SQL, an approved validation badge,
> and the real cohort it returns — full transparency, no surprise writes. The query
> isn't canned; it's written by the model and run for real."

## Scene 8 — Real AI, safely distributable  (5:00–5:30)

**On screen:** stay on a result and expand **Under the hood**; point at the AI source
badge ("cached real LLM").

**Narration:**
> "The agent reasoning runs on a real LLM. So the demo is reproducible and safe to
> distribute without leaking a key, responses are pre-generated and cached and bundled
> with the app — and judges can plug in their own key for live calls against any
> OpenAI-compatible provider."

## Scene 9 — Close  (5:30–6:00)

**On screen:** back to the Agents gallery.

**Narration:**
> "FHIR Agent Studio turns 'build an AI agent for FHIR' into a reusable development
> experience on IRIS: ObjectScript backend, native Vector Search, FHIR-shaped data, an
> IPM package, and a traceable HealthConnect-style runtime. It ships with all twelve
> suggested tasks and three polished demos. Thanks for watching."

---

## Shot list / b-roll reminders
- One-command start (terminal) → portal loads on **Agents**.
- Agents gallery scroll.
- Run tab: the patient/report **input pickers**.
- Run **result** + the amber draft-action badge.
- **Under the hood** expanded → Trace Timeline (expand one payload).
- Inspect tab: "Runs on IRIS Interoperability" mapping + generated build output.
- Prior-auth Criteria met / Still missing.
- NL→FHIR generated SQL + results table.

## If you need to trim to ~4 minutes
Cut Scene 7 (NL query) or Scene 8 (AI/caching) — keep Run+Trace (4), Inspect (5),
and Prior-Auth+Vector (6), which together cover complexity, the HealthConnect story,
and business value.
