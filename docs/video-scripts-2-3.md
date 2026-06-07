# Follow-up Video Scripts (videos 2 & 3 — voting week)

Same setup rules as `docs/video-script.md` (judge build, clean browser, 1080p,
~120% zoom). Each video stands alone — open with one line of context, don't assume
the viewer saw video 1. Target **3–4 minutes** each.

---

# Video 2 — "Build the thirteenth agent yourself"

**Pitch:** the studio isn't a gallery of 12 demos — it's a working agent-building
product. Prove it by building a new agent **one step at a time, testing every step
on camera**, and getting real AI output on the first run with no API key.

**The use case:** *Metformin Renal Safety Monitor.* The demo patient (Alexander
Gresham, `syn-pat-0696`) is on active metformin with an eGFR of **22** — below the
guideline cut-off of 30 where metformin is contraindicated. The data, the guidance
corpus, and the contradiction are all really in the dataset; the agent genuinely
catches it.

## Scene 1 — Setup (0:00–0:25)
**On screen:** Studio → Agents gallery.
> "FHIR Agent Studio ships twelve AI agents for FHIR workflows, running on a single
> IRIS for Health container. But the studio itself is the point — so let's build a
> thirteenth agent, step by step, and run it without any API key."

## Scene 2 — The wizard (0:25–0:50)
**On screen:** + New Agent → starter picker → choose **Metformin renal safety** →
keep the suggested name → Create & deploy.
> "New Agent starts from a blank canvas or a starter. I'll build a renal-safety
> monitor: is this patient's metformin still safe for their kidney function?"

## Scene 3 — The pipeline, step by step (0:50–2:05)
**On screen:** Build tab — the numbered step rail. Expand step 2 (Read the FHIR
record) → **Test step** → resources appear. Expand the eGFR evidence step →
show the read-only SQL with `{{patientRef}}` → **Test step** → one row: eGFR 22.
Expand the semantic search step → **Test step** → three guidance chunks appear:
ACE-inhibitor/hyperkalemia first (he's on lisinopril with CKD — the retrieval is
genuinely profile-driven), and *"Metformin and renal function… contraindicated
when eGFR is below 30"* among them.
> "An agent is a pipeline, and the builder shows it exactly as the runtime executes
> it: gather evidence, reason once with AI, propose a draft action. Every step is
> testable as you build. The FHIR read — real resources from the repository. This
> step is a custom read-only SQL query — test it: one row, eGFR twenty-two. And the
> semantic search — native IRIS Vector Search over the drug-guidance corpus, queried
> with this patient's actual profile — pulls back ACE-inhibitor guidance, because
> he's on lisinopril with kidney disease, and the metformin rule: contraindicated
> below thirty. The agent hasn't run yet, and we can already see the collision
> coming."

## Scene 4 — Preview the exact prompt (2:05–2:35)
**On screen:** Reason step → point at the output contract dropdown → **Preview
prompt** → the system + user messages appear with the evidence counts.
> "The Reason step. This output contract genuinely shapes the LLM's JSON. And
> Preview prompt shows the exact messages the runtime will send — assembled by the
> same code path, from the steps we just tested. No hidden prompt engineering."

## Scene 5 — Save, run, real AI, no key (2:35–3:25)
**On screen:** Save & deploy (compile succeeds) → Run tab → Run. Result:
needs_review — metformin contraindicated at eGFR 22 AND lisinopril flagged for
dose review — with a drafted **urgent Task** ("Immediately discontinue metformin…
review lisinopril dose and check electrolytes") marked "requires human review".
Expand **Under the hood** → source badge `cached`.
> "Save compiles seven runtime artifacts and deploys to a real interoperability
> production — then run. The agent flags it: metformin contraindicated at an eGFR
> of twenty-two — and it caught the lisinopril dose question too, from that
> ACE-inhibitor guidance. It drafts an urgent Task for the prescriber that a human
> must sign. And the source badge: cached. The repo bundles pre-generated real
> model output for the starter path, so this first run needed no API key. Edit
> anything and it honestly switches to live — bring any OpenAI-compatible key — or
> tells you it can't replay."

## Scene 6 — Close (3:25–3:45)
**On screen:** back to the gallery, 13 agents.
> "Twelve agents shipped, the thirteenth built and step-tested in three minutes —
> definitions, compiler, production, and trace all running inside InterSystems IRIS
> for Health. Repo link below; the README's quick start is two commands."

---

# Video 3 — "Under the hood: prove it isn't smoke and mirrors"

**Pitch:** every AI demo claims to be real. This one invites you to falsify it:
engine-level traces, a browsable response corpus, and an honest failure mode.

## Scene 1 — The claim (0:00–0:25)
**On screen:** Cedar Valley Health, flagship patient chart with advisories visible.
> "This clinical workspace runs twelve AI agents over a FHIR repository in
> InterSystems IRIS. Every result claims to be real retrieval, a real
> interoperability flow, and real LLM output. Claims are cheap — so let's try to
> catch it faking."

## Scene 2 — The completion transcript (0:25–1:05)
**On screen:** Studio → an agent Run → expand **Under the hood** → the full LLM
transcript (base prompt, combined request, raw response).
> "First, the transcript. Every run records the exact prompt assembled from the
> retrieved FHIR, SQL, and vector evidence — and the raw model response that became
> the result you saw. Nothing is post-edited; the JSON the model returned *is* the
> clinical result."

## Scene 3 — Visual Trace: below the application (1:05–1:50)
**On screen:** click the Visual Trace link; the Management Portal opens the exact
session; step through BS → BP → BO messages.
> "Second: the run carries its real engine session id. This is IRIS's own Visual
> Trace — the message flow recorded by the interoperability engine itself, below
> our application code. Application code can't fake this view: here's the FHIR
> read, the vector search, the AI call, and the drafted FHIR action, as messages."

## Scene 4 — The AI Hub corpus (1:50–2:35)
**On screen:** Studio → AI Hub. The three-tier explainer with live counters; search
the cache browser; open one entry — prompt preview, verbatim completion, date, hash.
> "Third: the demo's cached responses aren't a black box. The AI Hub lists the
> entire record/replay corpus — every prompt, every verbatim completion, when it
> was generated, and the hash that keys it. You can read exactly what the model was
> asked and what it said."

## Scene 5 — The falsifiability test (2:35–3:25)
**On screen:** an agent Run; change an input to something un-cached → run → the
result shows no AI framing; the explain-why banner points at Admin (no key set).
Optionally: paste a key in Admin → re-run → `live` badge.
> "And the honest failure mode: give it an input that isn't in the cache, with no
> key configured — and it *tells you so*, falls back to a deterministic non-AI path,
> and never dresses it up as intelligence. Add any OpenAI-compatible key and the
> same input runs live. A system that admits what it can't do is a system you can
> trust about what it can."

## Scene 6 — Close (3:25–3:45)
**On screen:** the demo guide's "Don't take our word for it" section.
> "Transcript, engine trace, browsable corpus, falsifiable caching — plus one more
> for the curious: the natural-language query agent validates its generated SQL
> read-only twice, in ObjectScript and in an Embedded Python AST parse. It's all in
> the repo — link below. Try to catch it faking; that's what the demo guide is for."
