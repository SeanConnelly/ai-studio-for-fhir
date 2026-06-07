# The 12 Agents — Use Case by Use Case

A reader's-eye walkthrough of every contest scenario as it actually ships in FHIR
Agent Studio: **where** the user is, **why** they're there, **what** they get, and
**how** — the exact steps the user takes, the background actions each one fires, and
what comes back on screen.

This is written against the real wiring (`seed/templates/*.json`,
`frontend/{studio,clinical}/src/...`, `FAST.BP.AgentOrchestrator`), not the pre-build
spec. Where a screen is sketched, it reflects the components that actually render.

---

## How to read this document

### Two apps, one backend

Every agent is the **same** compiled recipe running on the **same** IRIS
interoperability production. What differs is *where it's surfaced* and *who's looking*:

| | **Studio** (`/fhir-agent-studio/`) | **Cedar Valley Health** (`/clinical/`) |
|---|---|---|
| Audience | Developer / agent author | Clinician |
| Per-agent screen | **Agents → _agent_ → Run / Build / Inspect** | Woven into a worklist, a patient chart, or a standalone tool |
| Result renderer | `AgentResultView` — technical: source/model badges, raw evidence list, draft resource as JSON, full trace | `ClinicalResult` → `AdvisoryCard` + `DraftActionCard` — plain language, no FHIR/SQL/JSON, Sign/Decline |
| "Under the hood" | Always one click away (prompt transcript + RAG + Ens trace) | Collapsed into "Why am I seeing this?" + a dev-only "Technical details" disclosure |

The Studio is where you *see the machinery*; the clinical app is where you *see the
point*. Most sections below describe the clinical journey first (that's the demo), then
note what the Studio adds.

### The universal run pipeline

Every agent — all 12 — executes the identical message flow inside IRIS. The
**Business Process** `FAST.BP.AgentOrchestrator` reads the recipe and fires only the
steps that recipe declares, recording a real Ens trace step for each:

```
1  BusinessService   AgentTriggerService    receives the AgentRequest
2  BusinessProcess   AgentOrchestrator      loads the recipe, orchestrates the run
3  BusinessOperation FHIRReadOperation      pulls the declared FHIR resources      (only if evidence.fhir)
4  BusinessOperation SQLQueryOperation      runs the named FHIR-SQL queries        (only if evidence.sql)
5  BusinessOperation VectorSearchOperation  VECTOR_DOT_PRODUCT over a corpus       (only if evidence.vector)
6  BusinessProcess   AIHubProcess           combines evidence + base prompt, calls   (always)
                                            the LLM via the LLMService operation
7  BusinessOperation LLMService             the outbound LLM call itself, as a real
                                            FAST.Msg.LLMRequest/LLMResponse pair: the
                                            HTTP request (URL, masked auth, JSON body)
                                            and the truthful transport outcome —
                                            cached = replayed, no network call;
                                            live = real HTTPS status                (always)
8  BusinessOperation FHIRWritebackOperation  drafts the proposed resource          (only if action is draft-*)
```

So an agent's **step count is determined by its recipe**: an agent with FHIR + SQL +
vector evidence and a draft action runs all 8 steps; the NL→FHIR agent (no evidence
arrays, read-only) runs just 4. Each section lists the exact steps for that agent.

The trace is real: open the IRIS Management Portal → Interoperability →
**FAST.Production** → Visual Trace and you'll see the same messages.

### The AI result is authored, not assembled

At step 6 the LLM is handed the gathered evidence plus the agent's base prompt and
**writes the entire result** — the summary, findings, the draft FHIR resource, the
prior-auth met/missing lists, the NL→FHIR query. Code does not pre-build the answer and
let the LLM gloss it. "Under the hood" shows the three-part transcript: **base prompt →
combined request (prompt + evidence) → raw response** that was parsed into what you see.

### Three resolution tiers + the `isRealAi` gate

The LLM seam resolves in three tiers: **cached** real LLM response (the keyless demo
path) → **live** BYO-key call → **deterministic** ObjectScript fallback (never shown as
AI). The bundled cache holds one completion per agent keyed to *that agent's demo
patient*. So:

- In the **Studio**, every agent's default inputs hit the cache → `source = cached`.
- In the **clinical app**, an arbitrary chart patient usually misses → `deterministic`.
  The clinical UI therefore **only renders an advisory when `isRealAi(resp)` is true**
  (cached or live). On a non-prepared patient you see the real chart data and simply no
  AI card — never a generic fallback masquerading as AI.

The demo patients that *do* light up are pinned in `frontend/clinical/src/agents.ts`.
Each section names its demo patient.

### The draft → sign → commit loop

No agent ever writes to the record on its own. A `draft-fhir-create` action produces a
**proposed** resource (`ProposedAction`, status pending). In the clinical app it renders
as a `DraftActionCard` — a human-readable order with an amber **"Draft · needs your
sign-off"** badge and **Sign & commit / Decline** buttons. Only **Sign** calls
`approveAction`, which writes the resource to the real FHIR repo, records a
`Provenance`, and logs an audit entry. "Nothing is saved until you sign."

### Legend for each section

> **Where · Why · What** — the framing.
> **Inputs / Evidence / Draft action / Demo patient** — straight from the recipe.
> **User journey** — numbered, what the user does and sees.
> **Screen** — an ASCII sketch of the real layout.
> **Runtime trace** — the exact Ens steps this agent fires.

The 12 are grouped by **invocation model** — the same lens the clinical app's IA uses:
event-triggered work, population scans, in-chart on-demand support, and standalone tools.

---
---

# Group A — Event-triggered work (the Worklist)

These agents react to something that happened (an abnormal result posted, a discharge).
In Cedar Valley they populate the **Worklist** home screen: each row is a real finding
on a real patient; clicking it opens that patient's chart focused on the advisory that
flagged them.

```
Worklist  ·  AI-surfaced work across your patients
─────────────────────────────────────────────────────────────
▣ Patient safety
  ● Jordan Taylor · Abnormal result — no documented follow-up      ›
    HbA1c 11.2% on 12 May has no follow-up Task, order, or visit…
▣ Recent discharges
  ● Cameron Diaz · Post-discharge readmission risk                 ›
    High risk band — 2 admissions in 90 days, polypharmacy…
▣ Preventive care
  ● Avery Nguyen · Overdue diabetes follow-up                      ›
▣ Social needs
  ● Sam Rivera · Social barriers identified on screening           ›
```
*(The coloured dot = advisory severity. Each row runs its agent live on mount and shows
the first sentence of the real summary.)*

---

## 11. Abnormal Results Follow-Up  ·  *hero*

**Contest scenario:** #11 Imaging and Results Follow-Up Tracker — close the loop on
abnormal results.

- **WHERE** — Clinical: the **Patient safety** queue on the Worklist; click → chart with
  `?focus=results-followup` ("Why you're reviewing this patient"). Studio: **Agents →
  Abnormal Results Follow-Up → Run** (a *Featured* agent).
- **WHY** — Abnormal results that nobody acted on are a classic patient-safety failure.
  The agent finds abnormal `DiagnosticReport`s with **no** documented follow-up.
- **WHAT** — A finding ("abnormal HbA1c 11.2%, no follow-up found"), a recommended next
  step, and a **draft follow-up `Task`** (urgent) ready to sign.

| | |
|---|---|
| **Inputs** | Patient (picker) · Abnormal report (`DiagnosticReport` picker, filtered to the patient) |
| **Evidence** | FHIR: Patient, DiagnosticReport, Observation, Task, ServiceRequest, Appointment · SQL: `abnormal_result_followup_status` · Vector: `clinical_followup_guidance` |
| **Draft action** | `Task` (approval required) |
| **Demo patient** | `pat-abnormal-001`, report `dr-abnormal-001` |

**User journey (clinician)**

1. Lands on the Worklist; the **Patient safety** row already shows the real finding.
2. Clicks the row → patient chart opens, **Storyboard banner** on top, and a teal
   **"Why you're reviewing this patient"** panel holds the advisory.
3. Reads the `AdvisoryCard`: severity chip, one-line summary, bulleted findings, and a
   **"Why am I seeing this?"** link that lists the chart data used (in plain terms).
4. Below it, the amber `DraftActionCard` — "Follow-up task", priority, the suggested
   wording — with **Sign & commit / Decline**.
5. Clicks **Sign & commit** → the Task is written to FHIR, a Provenance recorded; the
   card flips to **"Signed & committed · Saved to the record: Task/…"**.

**Screen (chart, focused)**

```
┌ Storyboard ─────────────────────────────────────────────────┐
│ Jordan Taylor  · 58 · M · MRN …    [Allergies: Penicillin]   │
└──────────────────────────────────────────────────────────────┘
┌ Why you're reviewing this patient ──────────────────────────┐
│ ⚠ Results follow-up                              [Attention] │
│ Abnormal HbA1c 11.2% (12 May) has no documented follow-up.   │
│ • No follow-up Task, repeat order, or visit found            │
│ • Loop appears open since the result was finalised           │
│ AI-generated from this patient's chart — verify before acting│
│ Why am I seeing this? ▾                                       │
│ ┌ Draft · needs your sign-off ───────────────────────────┐  │
│ │ 📋 Follow-up task                                        │  │
│ │ Repeat HbA1c and arrange diabetes review                 │  │
│ │ Priority: urgent    Assigned to: Dr Patel                │  │
│ │ Nothing is saved until you sign.  [Decline] [Sign & commit]│ │
│ └──────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

**Runtime trace (8 steps):** AgentTriggerService → AgentOrchestrator → FHIRReadOperation
(report + Observations + any Task/ServiceRequest/Appointment) → SQLQueryOperation
(`abnormal_result_followup_status`) → VectorSearchOperation (`clinical_followup_guidance`)
→ AIHubProcess (LLM writes the finding + draft Task) → LLMService (the outbound LLM
request/response leg, on EnsLib.HTTP.OutboundAdapter) → FHIRWritebackOperation (drafts the Task).

**Studio adds:** the Run tab's two pickers (Patient, Abnormal report) are populated from
the real FHIR repo; "Under the hood" shows the completion transcript and all 8 steps with
their request/response payloads.

---

## 9. Hospital Readmission Risk Workbench

**Contest scenario:** #9 — estimate short-term readmission risk at discharge and propose
interventions.

- **WHERE** — Clinical: the **Recent discharges** queue; clicking lands on the chart with
  a **"Readmission risk: High"** badge in the Storyboard banner. Studio: **Agents →
  Readmission Risk Workbench → Run**.
- **WHY** — `trigger.type = fhir-event` on `Encounter` *discharge*. The moment a patient
  is discharged, score their 30-day readmission risk while there's still time to
  intervene.
- **WHAT** — A **risk band** (low/moderate/high), the explicit drivers behind it, and a
  draft **`Task`** for the recommended intervention. Explicitly *not* a validated ML
  model — transparent, rule-based scoring the agent explains.

| | |
|---|---|
| **Inputs** | Patient |
| **Evidence** | FHIR: Patient, Encounter, Condition, Observation, MedicationRequest, CarePlan · SQL: `admission_history`, `recent_labs`, `medication_history` · Vector: — |
| **Draft action** | `Task` |
| **Demo patient** | `syn-pat-0085` (Cameron) |

**User journey (clinician)**

1. Worklist **Recent discharges** row shows "High risk band — 2 admissions in 90 days…".
2. Click → chart; the banner carries a rose **"Readmission risk: High"** pill (rendered
   from `riskBand`).
3. The advisory lists **"What's driving the risk"** (recent admissions, polypharmacy,
   abnormal labs, missed follow-up), each a real evidence-backed driver.
4. A draft `Task` proposes the intervention (e.g. "schedule 7-day post-discharge call");
   Sign / Decline.

**Screen (banner + advisory excerpt)**

```
┌ Storyboard ── Cameron Diaz · 71 · F ────── [Readmission risk: High] ┐
└─────────────────────────────────────────────────────────────────────┘
⚠ Readmission risk                                          [Attention]
Estimated high 30-day readmission risk after this discharge.
 What's driving the risk
  • 2 inpatient admissions in the last 90 days
  • Polypharmacy — 11 active medications
  • Last potassium 3.1 (low) at discharge
  • No post-discharge follow-up scheduled
```

**Runtime trace (6 steps):** Trigger → Orchestrator → FHIRRead → SQLQuery
(`admission_history`, `recent_labs`, `medication_history`) → AIHub → FHIRWriteback (Task).

---
---

# Group B — Population scans

These agents sweep a cohort against explainable rules and surface who needs attention.
In Cedar Valley they back the **Preventive care** and **Social needs** worklist queues;
in the chart they appear as on-demand checks and can drive a banner care-gap count.

---

## 3. Gaps-in-Care Finder

**Contest scenario:** #3 — find patients overdue for screenings, vaccines, or
chronic-disease follow-up.

- **WHERE** — Clinical: **Preventive care** worklist queue; also on-demand in the chart's
  **Health Maintenance** section. Studio: **Agents → Gaps in Care Finder → Run**.
- **WHY** — Preventive gaps are invisible until someone runs the rule. The agent applies
  explicit, explainable rules (HbA1c follow-up for diabetics, BP control, cancer
  screening windows, immunizations).
- **WHAT** — A list of gaps, each with **why this patient is in the list**, the last
  relevant evidence, and a recommended action; optional **draft `Task`** for outreach.

| | |
|---|---|
| **Inputs** | Patient · **Care gap** (enum: `diabetes-a1c` / `bp-control` / `cancer-screening` / `immunization`) |
| **Evidence** | FHIR: Patient, Immunization, Observation, Condition, Procedure, Encounter · SQL: `overdue_screenings`, `diabetes_a1c_followup` · Vector: — |
| **Draft action** | `Task` |
| **Demo patient** | `syn-pat-0025` (Avery), gapType `diabetes-a1c` |

**User journey (clinician)**

1. **Preventive care** worklist row → chart; the banner may show an amber **"N care
   gaps"** pill.
2. The advisory lists each gap as a status pill (`overdue` = amber) + measure + detail +
   recommended action: *"HbA1c overdue — last 9.8% on 3 Jan, none in 6 months → repeat
   HbA1c & review."*
3. Sign the draft outreach `Task` if appropriate.

**Screen (gaps body)**

```
🛡 Preventive care gaps                                       [Attention]
[overdue] HbA1c monitoring — last 9.8% (3 Jan), none in 6 months · repeat & review
[overdue] Foot exam — none recorded in 12 months · schedule diabetic foot check
[ info  ] Flu vaccination — given 14 Oct, in window
```

**Runtime trace (6 steps):** Trigger → Orchestrator → FHIRRead → SQLQuery
(`overdue_screenings`, `diabetes_a1c_followup`) → AIHub → FHIRWriteback (Task).

---

## 6. Social Determinants & Community Referral Matcher

**Contest scenario:** #6 — recommend community resources for social needs (food,
transport, housing, behavioral health).

- **WHERE** — Clinical: **Social needs** worklist queue. Studio: **Agents → SDOH Referral
  Matcher → Run**.
- **WHY** — `trigger` on `QuestionnaireResponse` (a completed social-needs screening).
  Clinical + social data together reveal needs a clinician would otherwise miss, and the
  right local resource is hard to find by hand.
- **WHAT** — Identified **social risk categories**, **matched community resources**
  (retrieved by **Vector Search** over a resource directory), and a referral summary;
  draft **`ServiceRequest`**.

| | |
|---|---|
| **Inputs** | Patient |
| **Evidence** | FHIR: Patient, Condition, Observation, QuestionnaireResponse, ServiceRequest, CarePlan · SQL: — · Vector: `community_resources` |
| **Draft action** | `ServiceRequest` |
| **Demo patient** | `syn-pat-0061` (Sam) |

**User journey (clinician)**

1. **Social needs** worklist row → chart focused on the SDOH advisory.
2. Two side-by-side cards: **Social needs** (e.g. "Food: reports skipping meals";
   "Transport: no vehicle, misses appointments") and **Suggested referrals** (each a
   real directory entry the vector search matched, with the reason).
3. Sign a draft `ServiceRequest` to make the referral.

**Screen (needs + referrals)**

```
🤝 Social needs & referrals                                  [Advisory]
┌ Social needs ───────────────┐ ┌ Suggested referrals ─────────────┐
│ Food: skips meals weekly     │ │ Riverside Food Bank — groceries, │
│ Transport: no vehicle        │ │   walk-in, 2 mi                  │
│ Housing: stable              │ │ Dial-A-Ride — medical transport, │
│                              │ │   eligibility: Medicaid          │
└──────────────────────────────┘ └──────────────────────────────────┘
```

**Runtime trace (6 steps):** Trigger → Orchestrator → FHIRRead → **VectorSearchOperation**
(`community_resources`) → AIHub → FHIRWriteback (ServiceRequest). *(No SQL step — this
agent declares no SQL evidence.)*

---
---

# Group C — In-chart, on-demand decision support

These run *inside a patient chart* when the clinician asks (or, for Smart Summary, on
chart open). In Cedar Valley each lives in the relevant chart section and only offers
itself **where it produces a real, cache-backed result** — so a clinician never meets the
deterministic scaffold. The "Decision support" tab gathers all available ones.

```
Patient chart
┌ Storyboard banner ───────────────────────────────────────────┐
├─ Summary           ← auto-runs Smart Summary
├─ Problems
├─ Medications       ← [Run medication safety review]
├─ Results           ← [Run lab results, explained]
├─ Encounters
├─ Care Plan         ← [Run care-plan review]
├─ Health Maintenance← [Run preventive care gaps]
├─ Decision support  ← every cache-backed agent for this patient
└─ Tasks             ← all draft orders generated, awaiting sign-off
```

**Flagship demo patient: Skyler Bianchi `syn-pat-0001`** — lights up Summary, Medication
Safety, Care Plan, Labs, Trials, and Gaps.

---

## 1. Smart Patient Summary Generator

**Contest scenario:** #1 — a concise, role-aware patient summary from the FHIR record.

- **WHERE** — Clinical: **auto-runs on the chart's Summary tab** (every chart open).
  Studio: **Agents → Smart Patient Summary Generator → Run**.
- **WHY** — Reconstructing a patient from scattered resources wastes clinician time; the
  summary needed by an ED doctor differs from a care manager's or the patient's own.
- **WHAT** — A one-line overview + sectioned snapshot (active issues, recent changes,
  meds, risks/follow-ups), **tailored to the chosen role**. Draft `DocumentReference` to
  file it.

| | |
|---|---|
| **Inputs** | Patient · **Audience** (enum: emergency-physician / care-manager / patient / family-caregiver) |
| **Evidence** | FHIR: Patient, Condition, MedicationRequest, AllergyIntolerance, Observation, Encounter, CarePlan · SQL: `active_conditions`, `recent_labs`, `recent_encounters` · Vector: — |
| **Draft action** | `DocumentReference` |
| **Demo patient** | `syn-pat-0001` (Skyler), role `emergency-physician` |

**User journey (clinician)**

1. Opens a patient chart → the **Summary** tab auto-runs Smart Summary ("Preparing
   summary…" spinner).
2. Reads the snapshot — `summary` headline + `sections` rendered as side-by-side context
   cards (Problems / Medications / Recent results / Allergies).
3. If the run isn't cache-backed for that patient, the tab gracefully falls back to a
   **plain FHIR snapshot** built from `$everything` (real data, no AI card).
4. The **Decision support** strip beneath offers the patient's other available checks.

**Screen (Summary tab)**

```
✨ AI-generated summary                                        [Advisory]
58-y-o with type 2 diabetes (HbA1c 11.2%, poorly controlled), hypertension,
and CKD stage 3. Recent ED visit for hyperglycaemia; no endocrinology follow-up.
┌ Problems ───────────────┐ ┌ Medications ───────────────┐
│ • Type 2 diabetes        │ │ • Metformin 1g BD           │
│ • Hypertension           │ │ • Lisinopril 20mg OD        │
│ • CKD stage 3            │ │ • Atorvastatin 40mg ON      │
└──────────────────────────┘ └─────────────────────────────┘
┌ Recent results ─────────┐ ┌ Allergies ─────────────────┐
│ • HbA1c 11.2% ↑          │ │ • Penicillin (rash)         │
│ • eGFR 48                │ └─────────────────────────────┘
└──────────────────────────┘
─ Decision support ────────────────────────────────────────────
[Run medication safety review] [Run care-plan review] [Run labs…]
```

**Role twist:** changing **Audience** in the Studio Run tab re-tones the whole output —
an ED summary leads with acute risks; the patient version uses plain language. (Each role
is a distinct cached completion.)

**Runtime trace (6 steps):** Trigger → Orchestrator → FHIRRead → SQLQuery
(`active_conditions`, `recent_labs`, `recent_encounters`) → AIHub → FHIRWriteback
(DocumentReference).

---

## 4. Medication Safety & Interaction Assistant

**Contest scenario:** #4 — flag duplication, interactions, allergy conflicts, monitoring
needs.

- **WHERE** — Clinical: the chart's **Medications** section — **[Run medication safety
  review]**. Studio: **Agents → Medication Safety Assistant → Run**.
- **WHY** — Polypharmacy hides interactions and allergy conflicts; a pharmacist's review
  isn't always available at the point of prescribing.
- **WHAT** — Classified meds + **review findings**: each interaction with a severity pill,
  the drugs involved, the issue, and a recommendation, **grounded in retrieved drug
  guidance** (Vector Search). Draft `DetectedIssue`.

| | |
|---|---|
| **Inputs** | Patient |
| **Evidence** | FHIR: MedicationRequest, MedicationStatement, AllergyIntolerance, Condition, Observation · SQL: `medication_history` · Vector: `drug_guidance` |
| **Draft action** | `DetectedIssue` |
| **Demo patient** | `syn-pat-0037` (and Skyler `syn-pat-0001` in-chart) |

**User journey (clinician)**

1. In the chart, opens **Medications**; sees the active list, then clicks **[Run
   medication safety review]**.
2. The advisory returns interaction cards: e.g. `[Moderate] Lisinopril + Spironolactone —
   hyperkalaemia risk → monitor potassium`. Each cites guidance behind "Why am I seeing
   this?".
3. Optionally signs the draft `DetectedIssue` to record the concern.

**Screen (interactions)**

```
💊 Medication safety review                                   [Attention]
[Moderate] Lisinopril + Spironolactone
  Combined use raises hyperkalaemia risk.
  → Check potassium within 1–2 weeks; review if K⁺ > 5.0.
[Info]     Atorvastatin
  No interaction; routine LFT monitoring applies.
```

*(Note: on Skyler the demo's med set is "all clear" — the weakest in-chart item; a future
synthetic-data tweak adds one interacting med to strengthen it.)*

**Runtime trace (8 steps):** Trigger → Orchestrator → FHIRRead → SQLQuery
(`medication_history`) → VectorSearch (`drug_guidance`) → AIHub → LLMService →
FHIRWriteback (DetectedIssue).

---

## 5. AI-Powered Care Plan Navigator

**Contest scenario:** #5 — turn CarePlan/Goal into "what to do next / what's overdue /
what's off track".

- **WHERE** — Clinical: the chart's **Care Plan** section — **[Run care-plan review]**.
  Studio: **Agents → Care Plan Navigator → Run**.
- **WHY** — Care plans go stale; nobody can see at a glance which goals are slipping or
  which tasks lapsed.
- **WHAT** — Each goal assessed (on-track / off-track / overdue / blocked / done) with a
  next step and owner; **draft `Task`** suggestions for overdue items.

| | |
|---|---|
| **Inputs** | Patient |
| **Evidence** | FHIR: CarePlan, Goal, Task, Appointment, MedicationRequest, Observation · SQL: `overdue_tasks`, `offtrack_goals` · Vector: — |
| **Draft action** | `Task` |
| **Demo patient** | `syn-pat-0049` (and Skyler in-chart) |

**User journey (clinician)**

1. Chart → **Care Plan** → **[Run care-plan review]**.
2. Goals render as status pills + next step: *"[off track] HbA1c < 7% · next: intensify
   therapy, repeat in 4 weeks"*, *"[on track] BP < 130/80"*.
3. Sign the draft `Task` for an overdue item.

**Screen (goals)**

```
🎯 Care-plan review                                           [Attention]
[off track] Achieve HbA1c < 7%   · next: intensify therapy, repeat in 4 wks
[overdue ] Annual eye exam       · next: refer to ophthalmology
[on track] Maintain BP < 130/80
```

**Runtime trace (6 steps):** Trigger → Orchestrator → FHIRRead → SQLQuery
(`overdue_tasks`, `offtrack_goals`) → AIHub → FHIRWriteback (Task).

---

## 12. Patient-Friendly Lab Explainer

**Contest scenario:** #12 — plain-language explanation of labs and trends for patients.

- **WHERE** — Clinical: the chart's **Results** section — **[Run lab results,
  explained]**. Studio: **Agents → Patient-Friendly Lab Explainer → Run**.
- **WHY** — Patients can't read lab tables; portals dump numbers without meaning or trend.
- **WHAT** — Per-result plain explanation (test, value, what it means), a trend note, a
  **patient message**, "when to seek care" guidance, and questions to ask — **grounded in
  trusted education content** (Vector Search). Draft `Communication` (the message).

| | |
|---|---|
| **Inputs** | Patient · **Lab result** (`Observation` picker, filtered to patient) |
| **Evidence** | FHIR: Patient, Observation, DiagnosticReport · SQL: `recent_labs` · Vector: `patient_education` |
| **Draft action** | `Communication` |
| **Demo patient** | `syn-pat-0109`, obs `syn-pat-0109-o1` (and Skyler in-chart) |

**User journey (clinician/patient)**

1. Chart → **Results** → **[Run lab results, explained]**.
2. Reads "Your results, explained" — each result in one plain sentence; an amber **"When
   to seek care"** box; a sky-blue **"Message for the patient"** draft.
3. The patient message is a draft `Communication` — review/edit, nothing is sent
   automatically.

**Screen (lab body)**

```
🧪 Your results, explained                                    [Advisory]
HbA1c 11.2% — your average blood sugar over ~3 months is high…
eGFR 48 — your kidneys are filtering a little slower than ideal…
┌ When to seek care ───────────────────────────────────────────┐
│ • Very high thirst, frequent urination, or blurred vision     │
└───────────────────────────────────────────────────────────────┘
💬 Message for the patient
"Your recent blood test shows your sugar has been running high…"
  Plain-language draft — review and edit before sending.
```

**Runtime trace (8 steps):** Trigger → Orchestrator → FHIRRead → SQLQuery (`recent_labs`)
→ VectorSearch (`patient_education`) → AIHub → LLMService → FHIRWriteback (Communication).

---

## 7. FHIR Clinical Trial Matcher

**Contest scenario:** #7 — match a patient against trial eligibility criteria.

- **WHERE** — Clinical: in-chart on-demand (Decision support) for eligible demo patients.
  Studio: **Agents → Clinical Trial Matcher → Run**.
- **WHY** — Eligibility screening is manual and criteria live in unstructured documents.
- **WHAT** — Per-trial classification **likely / maybe / unlikely** with **matched** and
  **unmatched** criteria and rationale; criteria are retrieved by **Vector Search** over a
  trial-criteria corpus. The "nice twist" — asking for missing data (e.g. latest eGFR) —
  surfaces as unmatched criteria/follow-up questions. Draft `Task`.

| | |
|---|---|
| **Inputs** | Patient |
| **Evidence** | FHIR: Patient, Condition, Observation, MedicationStatement, Procedure, DocumentReference · SQL: `recent_labs` · Vector: `trial_criteria` |
| **Draft action** | `Task` |
| **Demo patient** | `syn-pat-0073` (and Skyler in-chart) |

**User journey (clinician)**

1. From the chart's Decision support, runs **Trial eligibility**.
2. Each trial is a card: eligibility pill + the trial name; green **Met** criteria; amber
   **Unmet** criteria (which double as the follow-up questions).

**Screen (matches)**

```
🔬 Trial eligibility                                          [Advisory]
[maybe] CARDIO-DM Phase III
  Met: Type 2 diabetes; age 40–75; on metformin
  Unmet: latest eGFR > 45 (no result in 90 days); no prior GLP-1
[unlikely] RENAL-PROTECT
  Unmet: eGFR ≥ 60
```

**Runtime trace (8 steps):** Trigger → Orchestrator → FHIRRead → SQLQuery (`recent_labs`)
→ VectorSearch (`trial_criteria`) → AIHub → LLMService → FHIRWriteback (Task).

---
---

# Group D — Standalone tools

These aren't tied to one chart — they're top-level destinations in Cedar Valley
(**Prior Auth · Ask · Triage**) and *Featured* agents in the Studio. Each is a focused
workspace: a small form, a Run button, a tailored result.

---

## 2. FHIR Prior Authorization Copilot  ·  *hero*

**Contest scenario:** #2 — assemble evidence for a prior-auth request + a "missing
evidence" checklist.

- **WHERE** — Clinical: the **Prior Auth** page. Studio: **Agents → Prior Authorization
  Evidence Agent → Run** (*Featured*).
- **WHY** — Prior-auth prep is slow and denials hinge on missing documentation. Matching
  the patient's record against the **payer policy** (retrieved by **Vector Search**) is
  the whole game.
- **WHAT** — **Criteria met** vs **Still needed** (the missing-evidence checklist), a
  drafted justification, and a draft **`DocumentReference`** evidence packet. The agent
  does *not* make a coverage decision.

| | |
|---|---|
| **Inputs** | Patient · **Requested service** (free text) |
| **Evidence** | FHIR: Patient, Coverage, Condition, MedicationRequest, Procedure, Observation, DocumentReference · SQL: `prior_auth_supporting_evidence` · Vector: `payer_policies` |
| **Draft action** | `DocumentReference` |
| **Demo patient** | `pat-prior-auth-001`, service "Semaglutide (Wegovy) prior authorization" |

**User journey (staff)**

1. Opens **Prior Auth**; the form is pre-filled with the demo patient + requested
   service. Clicks **Assemble evidence**.
2. Reads two columns: **Criteria met** (green checks — "baseline BMI ≥ 30: 38.4"; "prior
   failed therapy: phentermine") and **Still needed** (amber — "documented 6-month
   lifestyle program") — the gap that causes denials.
3. Reviews the drafted justification paragraph and signs the draft `DocumentReference`.

**Screen (criteria checklist)**

```
Prior authorization · Semaglutide (Wegovy)                    [Advisory]
┌ Criteria met ───────────────┐ ┌ Still needed ──────────────────┐
│ ✓ Baseline BMI ≥ 30 (38.4)   │ │ ✗ Documented 6-month lifestyle │
│ ✓ Prior failed therapy        │ │   program                      │
│   (phentermine)              │ │ ✗ Comorbidity documentation    │
└──────────────────────────────┘ └────────────────────────────────┘
 Draft justification: "Patient meets payer criteria A and C for…"
 ┌ Draft DocumentReference · needs sign-off ───────────────────┐
```

**Runtime trace (8 steps):** Trigger → Orchestrator → FHIRRead → SQLQuery
(`prior_auth_supporting_evidence`) → **VectorSearch (`payer_policies`)** → AIHub →
LLMService → FHIRWriteback (DocumentReference).

---

## 8. Natural Language → FHIR Query Explorer  ·  *hero*

**Contest scenario:** #8 — plain-English question → transparent FHIR/SQL query → result
preview.

- **WHERE** — Clinical: the **Ask** ("Ask your data") page. Studio: **Agents → Natural
  Language to FHIR Query Agent → Run** (*Featured*).
- **WHY** — Cohort questions normally need a developer. The transparency twist — *showing
  the generated query* — is what the judges want to see.
- **WHAT** — Interpreted intent, the **generated read-only query** (real SQL against the
  IRIS FHIR SQL projections), a **validation status** (verified read-only before it
  runs), and a **live result table** from executing it. This is the only agent with **no
  draft action** (read-only) and **no pre-gathered evidence** — the LLM authors the query,
  which is validated and executed inside the AIHub step.

| | |
|---|---|
| **Inputs** | Question (free text) |
| **Evidence** | FHIR: — · SQL: — · Vector: — (the query *is* the data access) |
| **Draft action** | none (`read-only`) |
| **Demo question** | "Show diabetic patients with HbA1c above 9 in the last 6 months" |

**User journey (clinician/developer)**

1. Opens **Ask**; the question is pre-filled. Clicks **Ask**.
2. Sees **"Interpreted as: …"**, then a result **table** (the real cohort — Jordan Taylor
   11.2, Ada Okafor 9.8, …) rendered from `resultPreview`.
3. Expands **"How this was answered"** → the generated SQL (syntax-highlighted), the query
   type, and "validated read-only (approved) · executed against the record".

**Screen (Ask)**

```
🔎 Ask your data
[ Show diabetic patients with HbA1c above 9 in the last 6 months ] [Ask]
Interpreted as: cohort of patients with an active diabetes condition and a
                recent HbA1c result above 9%.
┌ 4 results ─────────────────────────────────────────────────┐
│ name           | hba1c | date                                │
│ Jordan Taylor  | 11.2  | 2026-05-12                          │
│ Ada Okafor     | 9.8   | 2026-04-30                          │
└─────────────────────────────────────────────────────────────┘
▸ How this was answered
   Generated SQL · validated read-only (approved) · executed.
   SELECT … FROM HSFHIR_X0001_S.Observation …
```

**Runtime trace (4 steps):** AgentTriggerService → AgentOrchestrator → AIHubProcess
(LLM writes SQL → `SqlGuard`/`IsReadOnly` validates → `%SQL.Statement` executes → rows
returned) → LLMService (the outbound LLM request/response leg). No FHIRRead/SQL/Vector
evidence steps, no writeback.

**Safety:** the generated query is validated read-only *before* execution; a write would
be rejected. The transparency disclosure is deliberate — judges can see the exact query
that ran.

---

## 10. Conversational FHIR Triage Assistant

**Contest scenario:** #10 — structured triage questions → QuestionnaireResponse →
clinician handoff.

- **WHERE** — Clinical: the **Triage** ("Triage intake") page. Studio: **Agents →
  Conversational Triage Assistant → Run**.
- **WHY** — Front-door triage needs structure, an urgency signal, and a clean handoff —
  without giving unsafe autonomous advice.
- **WHAT** — A draft **urgency level**, **red flags**, a **recommended next step**, a
  clinician handoff, and a plain-language patient message; answers captured as a draft
  **`QuestionnaireResponse`** (mapped to coded observations where possible). Urgency is
  *draft support requiring clinical review*.

| | |
|---|---|
| **Inputs** | Patient · **Chief complaint** (free text) |
| **Evidence** | FHIR: Questionnaire, QuestionnaireResponse, Condition, Observation, ServiceRequest, Encounter · SQL: — · Vector: — |
| **Draft action** | `QuestionnaireResponse` |
| **Demo patient** | `syn-pat-0097`, complaint "chest discomfort for 2 days" |

**User journey (intake)**

1. Opens **Triage**; patient + chief complaint pre-filled. Clicks **Assess**.
2. The result leads with severity (the urgency band drives the card colour), a **Red
   flags** line, and a **Recommended next step**.
3. A patient-facing message and the structured handoff round it out — for clinician
   review, never an autonomous disposition.

**Screen (triage)**

```
💬 Triage assessment                                          [Critical]
Chest discomfort for 2 days with exertional component — urgent review advised.
┌───────────────────────────────────────────────────────────────┐
│ Red flags: exertional chest pain; radiation to left arm         │
│ Recommended next step: same-day clinical assessment / ED if…    │
└───────────────────────────────────────────────────────────────┘
💬 Message for the patient: "Based on your answers, please…"
```

**Runtime trace (5 steps):** Trigger → Orchestrator → FHIRRead → AIHub → FHIRWriteback
(QuestionnaireResponse). *(No SQL or Vector steps.)*

---
---

# Appendix — quick reference

### Step count by agent (driven by the recipe)

| # | Agent | FHIR | SQL | Vector | Draft action | Steps |
|---|---|:---:|:---:|:---:|---|:---:|
| 1 | Smart Patient Summary | ✓ | ✓ | — | DocumentReference | 6 |
| 2 | Prior Authorization *(hero)* | ✓ | ✓ | ✓ | DocumentReference | 7 |
| 3 | Gaps in Care | ✓ | ✓ | — | Task | 6 |
| 4 | Medication Safety | ✓ | ✓ | ✓ | DetectedIssue | 7 |
| 5 | Care Plan Navigator | ✓ | ✓ | — | Task | 6 |
| 6 | SDOH Referral | ✓ | — | ✓ | ServiceRequest | 6 |
| 7 | Clinical Trial Matcher | ✓ | ✓ | ✓ | Task | 7 |
| 8 | NL → FHIR Query *(hero)* | — | — | — | none (read-only) | 3 |
| 9 | Readmission Risk | ✓ | ✓ | — | Task | 6 |
| 10 | Conversational Triage | ✓ | — | — | QuestionnaireResponse | 5 |
| 11 | Abnormal Results Follow-Up *(hero)* | ✓ | ✓ | ✓ | Task | 7 |
| 12 | Lab Explainer | ✓ | ✓ | ✓ | Communication | 7 |

### Where each agent surfaces in the clinical app

| Invocation model | Agents | Cedar Valley location |
|---|---|---|
| Event-triggered | Results Follow-Up, Readmission Risk | **Worklist** queues → chart `?focus=` |
| Population scan | Gaps in Care, SDOH Referral | **Worklist** queues; chart sections |
| In-chart on-demand | Smart Summary (auto), Medication Safety, Care Plan, Lab Explainer, Trial Matcher | Patient **chart** sections / Decision support |
| Standalone tool | Prior Auth, NL→FHIR, Triage | Top-level **Prior Auth · Ask · Triage** pages |

### Hero agents (polished)

Abnormal Results Follow-Up · Prior Authorization · Natural Language → FHIR Query. The
other nine compile cleanly, run the same real pipeline, and are LLM-authored — but get no
bespoke hand-tuning beyond their pinned demo patient.

---

*Sources: `seed/templates/*.json` (recipes), `FAST.BP.AgentOrchestrator` (runtime trace),
`frontend/clinical/src/{agents.ts,pages/*,components/ClinicalResult.tsx}` and
`frontend/shared/components/clinical/{AdvisoryCard,DraftActionCard}.tsx` (clinician
screens), `frontend/studio/src/components/run/*` (Studio screens). Keep this in sync when
recipes or the renderers change.*
