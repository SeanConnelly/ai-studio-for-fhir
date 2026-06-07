# Demo Script — click-by-click

A walkthrough a judge (or you) can follow in ~5 minutes. Assumes the app is running
via `docker compose up --build` and the portal is open at
http://localhost:42773/fhir-agent-studio/.

> Tip: to start from a clean state, go to **Admin** → **Reload seed data**.

---

## Demo 1 — Abnormal Results Follow-Up (patient safety)

1. Open the portal. You land on **Agents** — 12 agents, 3 marked **Featured**.
2. Click **Abnormal Results Follow-Up**. You land in its workspace on the **Run** tab.
3. The **input panel** shows a **Patient** picker and an **Abnormal report** picker —
   both populated from the real FHIR repository, pre-filled with the demo case. Press **Run**.
4. Read the clean **result**:
   - **Status** `needs review`; summary: abnormal HbA1c 11.2%, no documented follow-up.
   - **Recommended next steps**: create a follow-up Task (urgent).
   - **Draft Task**, amber badge *"Requires human review"* — nothing is written.
5. Expand **Under the hood**:
   - the **AI source** badge (cached real LLM),
   - the **LLM completion transcript** — the *base prompt*, the *combined completion
     request* (base prompt + the gathered evidence), and the *raw LLM response* that
     was parsed into the result you see. This is the heart of the demo: the result is
     authored by the LLM from the evidence, not assembled in code.
   - the **evidence gathered (RAG)** the agent used,
   - the **Runtime trace**: 8 steps (AgentTriggerService → … → LLMService →
     FHIRWritebackOperation). Expand the **LLMService** step: the outbound LLM call as
     a real request/response pair — the POST to /chat/completions with the masked auth
     header, and the truthful transport outcome (cached = "replayed, no network call
     made"; with a live key = the real HTTP 200).

**Talking point:** a clinician sees only the result; a developer opens "under the hood"
to see exactly what was sent to the LLM and what came back, plus the real IRIS
interoperability flow behind it — and the action is drafted, never committed.

---

## Demo 2 — Prior Authorization (business value + Vector Search)

1. **Agents** → **Prior Authorization** → **Run**.
2. Note in the result:
   - **Criteria met**: baseline BMI ≥ 30 (38.4), prior failed therapy (phentermine).
   - **Still missing**: documented 6-month lifestyle program — the gap that causes denials.
   - **Draft DocumentReference** (the evidence packet).
3. **Under the hood** → the evidence includes chunks from `payer_policies` retrieved by
   **IRIS Vector Search**.

**Talking point:** real native vector search over payer policy grounds the
missing-evidence checklist — concrete administrative value.

---

## Demo 3 — Natural Language → FHIR Query (developer experience)

1. **Agents** → **Natural Language to FHIR Query** → **Run**
   (question pre-filled: "Show diabetic patients with HbA1c above 9 in the last 6 months").
2. Note in the result:
   - **Interpreted intent**, the **generated query** — real SQL the LLM wrote against
     the IRIS FHIR SQL projections, syntax-highlighted — and **validation** `approved`
     (verified read-only before it runs).
   - **Result preview** table: the actual cohort returned by executing that query
     against the real FHIR repository (e.g. Jordan Taylor 11.2, Ada Okafor 9.8,
     Petr Novak 10.5, …). The rows are live query output, not a canned list.
3. Expand **Under the hood** → the **completion transcript** shows the schema-grounded
   prompt and the raw LLM response containing the query it generated.

**Talking point:** natural language → the LLM writes a real query → we validate it as
read-only → we execute it against the live FHIR data and show the rows. Transparent and
safe: no surprise writes, and you can see the exact query that ran.

---

## Demo 4 — Inspect: how an agent maps to IRIS

1. On any agent, click the **Inspect** tab.
2. **Runs on IRIS Interoperability** — the agent-concept → Business Service / Process /
   Operation mapping. Then the **generated build output**: the 7 artefacts the compiler
   emits into IRIS (recipe, prompt, schema, FHIR action template, production settings,
   mapping, IPM manifest).
3. (Optional) top-right **Management Portal** → Interoperability → **FAST.Production** →
   **Visual Trace** of the run you just did — the same real message flow.

**Talking point:** the runtime is generic; the workflow logic lives in the compiled
recipe — and these are real, running components, not a diagram.

---

## Demo 5 — The other nine (all LLM-authored)

Back to **Agents** — every one of the twelve is an LLM-authored, evidence-grounded
agent (not just the three). Open any (Smart Patient Summary, Medication Safety,
Readmission Risk, Lab Explainer, …), **Run**, and read the tailored clinician result;
**Under the hood** shows the same transcript + request/response trace.

---

## Demo 6 — Build an agent from reusable components (the Studio)

1. **Prompts** (left nav) — the Prompt Manager: create / edit / delete prompts. Open
   one to see its system template + output-contract reference. The Evidence Sources,
   Actions, and Schemas managers work the same way — an agent is **stacked from these
   reusable parts**.
2. **Agents → + New Agent** — name it; you land in the **Agent Builder**. Wire the
   Trigger → Inputs → Evidence → Prompt → Action, press **Save & deploy** — it
   validates, compiles to the 7 artefacts, and deploys to the live production. Open
   **Run** and try it. (**Clone** copies any agent to iterate.)

**Talking point:** "It's a real studio — every ingredient is a reusable component you
can author, and a new agent is live the moment you save it."

---

## Demo 7 — The Clinical app (mini-EHR) at `/clinical/`

1. Open **http://localhost:42773/clinical/** — a distinct clinician workspace.
2. **Worklists** → *Diabetes* (or CKD / Heart failure) — a cohort discovered live from
   FHIR by condition code (`_has` reverse-chain), hundreds of real patients. Click one.
3. **Patient chart** — banner + Overview / Results / Encounters / Care tabs, all from
   the real FHIR repository.
4. **AI assistants** rail — run *Smart summary*, *Medication safety*, *Readmission
   risk*, *Explain labs*… in context. The result renders with the **same components**
   the Studio preview uses (one shared library).
5. **Approve a draft** — when an agent proposes a draft (e.g. a follow-up Task), the
   **Approve & commit** button writes it to the FHIR repository, records a Provenance,
   and logs it in the **review audit**. Nothing is committed without that click.

**Closing:** "One IRIS backend, two polished apps — a developer Studio that builds
agents from reusable components, and a clinician mini-EHR that runs them in context
over ~1,000 real FHIR patients. Twelve LLM-authored agents, real native Vector Search,
explicit FHIR tools, a traceable HealthConnect-style runtime, and every write-back
guarded by human review."
