# InterSystems Programming Contest: AI Agents for FHIR — Suggested Task Reference

Source page: https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-fhir  
Prepared as an expanded Markdown reference for solution planning.

## Contest summary

**Contest:** InterSystems Programming Contest: AI Agents for FHIR  
**Topic:** Develop an AI agent to be called in an interoperability FHIR solution.  
**Duration:** May 25–June 14, 2026  
**Prize pool:** $12,000  
**Suggested-task bonus:** Implementing one of the suggested tasks earns **5 bonus points**, once per application.

## General requirements from the competition page

A submitted application or library should be functional and not merely a thin wrapper around an existing application or library. Applications may be new Open Exchange apps or existing apps with significant improvements. The app should work on **InterSystems IRIS Community Edition** or **InterSystems IRIS for Health Community Edition**, and it should be open source on GitHub or GitLab. The README must be in English, include installation steps, and include either a video demo or a description of how the application works.

## How to read this document

Each suggested task below includes:

- **Original intent** — what the competition page is asking for.
- **FHIR resources** — resources named by the competition page.
- **InterSystems features** — platform capabilities suggested by the page.
- **MVP behaviour** — the 1–2 week version described by the page.
- **Expanded implementation detail** — practical interpretation of what the workflow should do.
- **Agent outputs** — what the AI agent should produce.
- **Possible FHIR write-backs** — resources the app could draft or create.
- **Demo notes** — what would make the workflow obvious to judges.

---

# 1. Smart Patient Summary Generator

## Original intent

Create a concise, clinician-friendly summary of a patient from FHIR data, including conditions, medications, allergies, recent encounters, labs, and care plans.

## FHIR resources

- `Patient`
- `Condition`
- `MedicationRequest`
- `AllergyIntolerance`
- `Observation`
- `Encounter`
- `CarePlan`

## InterSystems features

- FHIR API
- FHIR SQL Builder
- AI Hub

## MVP behaviour

Pick one patient, pull recent FHIR resources, and generate:

- current issues;
- recent changes;
- risks or follow-up items.

## Expanded implementation detail

The agent should build a compact clinical snapshot from a patient’s longitudinal FHIR record. It should prioritise active and recent information over stale information, group related facts, and avoid copying raw FHIR data directly into prose.

A strong implementation should distinguish active conditions from historical conditions, current medications from discontinued or completed medication requests, abnormal observations from normal observations, recent encounters from older encounters, and care-plan goals that are active, overdue, completed, or unclear.

The agent should create a summary that can be regenerated for different roles. For example, an emergency doctor may need high-risk diagnoses, allergies, active medications, recent abnormal labs, and recent encounters. A care manager may need open care-plan tasks, missed appointments, social risks, and follow-up gaps. A patient or caregiver may need plain-language explanations and next steps.

## Agent outputs

```json
{
  "patientBanner": {},
  "currentIssues": [],
  "recentChanges": [],
  "medications": [],
  "allergies": [],
  "recentLabs": [],
  "carePlanStatus": [],
  "risksAndFollowUp": [],
  "roleSpecificSummary": "string",
  "evidence": []
}
```

## Possible FHIR write-backs

- `DocumentReference` containing a generated summary.
- `Task` for follow-up items found during summarisation.
- `Communication` for patient-friendly summaries, if patient-facing output is included.

## Demo notes

A good demo should show the same patient summarised for two roles: ED doctor and care manager or patient. The judge should see that the same evidence produces different outputs depending on the selected role.

---

# 2. FHIR Prior Authorization Copilot

## Original intent

Help staff prepare prior authorization requests by pulling diagnosis, medication history, procedures, and supporting evidence from FHIR data.

## FHIR resources

- `Patient`
- `Coverage`
- `Condition`
- `MedicationRequest`
- `Procedure`
- `Observation`
- `DocumentReference`

## InterSystems features

- FHIR SQL Builder
- Vector Search
- AI Hub
- AI Agents

## MVP behaviour

Given a requested medication or procedure, the app should identify likely supporting diagnoses, find relevant recent observations or notes, and draft a justification summary.

Nice twist: add a missing-evidence checklist.

## Expanded implementation detail

The agent should act as an evidence assembler for a prior authorization workflow. It should not make coverage decisions. It should gather patient-specific evidence and compare it against policy-style criteria or documentation requirements.

The workflow should start with a requested medication, procedure, imaging study, device, or service. The system should gather patient demographics, insurance or payer coverage details, relevant diagnoses, prior therapies or failed medications, procedures already tried, objective observations such as lab values or BMI, relevant clinical notes or uploaded documents, and payer-policy snippets or mock policy criteria.

A strong agent should separate **evidence found** from **evidence missing**. This is especially important because prior authorization workflows often fail because documentation is incomplete.

## Agent outputs

```json
{
  "requestedService": "string",
  "supportingDiagnoses": [],
  "supportingMedicationsOrFailedTherapies": [],
  "supportingProcedures": [],
  "supportingObservations": [],
  "policyCriteriaMatched": [],
  "missingEvidenceChecklist": [],
  "draftJustification": "string",
  "recommendedNextSteps": [],
  "evidence": []
}
```

## Possible FHIR write-backs

- `DocumentReference` for the generated evidence packet.
- `Task` for missing documentation.
- `ServiceRequest` if the prior authorization relates to a requested service.
- `Communication` for administrative follow-up.

## Demo notes

This is one of the strongest contest demos because it combines structured FHIR data, Vector Search over policy content, AI reasoning, and a clear administrative value proposition.

A strong judge-facing flow: select patient and requested service, retrieve FHIR evidence, search payer policy, draft justification, flag missing evidence, and draft a `Task` or `DocumentReference`.

---

# 3. Gaps-in-Care Finder for Preventive Screening

## Original intent

Identify patients who may be overdue for screenings, vaccines, or chronic disease follow-ups.

## FHIR resources

- `Patient`
- `Immunization`
- `Observation`
- `Condition`
- `Procedure`
- `Encounter`

## InterSystems features

- FHIR SQL Builder
- Dashboards / analytics
- Optional AI Hub

## MVP behaviour

Implement two or three rules, such as HbA1c follow-up for diabetes, mammogram screening window, flu or COVID vaccination reminder, or blood pressure follow-up.

Nice twist: use AI to generate outreach messaging tailored to patient preference or risk level.

## Expanded implementation detail

This workflow should operate over a patient cohort rather than only a single patient. The app should identify preventive or chronic-care gaps using simple, explainable rules. It does not need a sophisticated clinical quality measure engine for the contest; it can implement a few explicit rules.

Example rules include: a patient with diabetes has no HbA1c observation in the last six months; a patient has hypertension and no recent blood pressure reading; a patient has no recorded flu vaccination in the current season; or a screening-eligible patient has no recent procedure or result indicating completion.

The agent layer can then produce patient-specific outreach or care-team next steps. The AI component should explain why a patient is in the gap list and what the next appropriate action is.

## Agent outputs

```json
{
  "cohortSummary": {},
  "patientGaps": [
    {
      "patient": "Patient/id",
      "gapType": "string",
      "ruleTriggered": "string",
      "lastRelevantEvidence": "string",
      "recommendedAction": "string",
      "outreachMessageDraft": "string"
    }
  ],
  "priorityQueue": [],
  "evidence": []
}
```

## Possible FHIR write-backs

- `Task` for care team follow-up.
- `ServiceRequest` for screening or lab order suggestion.
- `Communication` for patient outreach draft.
- `CarePlan` update for chronic disease follow-up.

## Demo notes

A dashboard-style demo works well: show a cohort list, filter by gap type, click one patient to see evidence and the AI-generated outreach message, then show a draft `Task` or `Communication`.

---

# 4. Medication Safety and Interaction Assistant

## Original intent

Build a medication review app that flags possible duplication, interactions, allergy conflicts, or adherence issues using FHIR medication and allergy data.

## FHIR resources

- `MedicationRequest`
- `MedicationStatement`
- `AllergyIntolerance`
- `Condition`
- `Observation`

## InterSystems features

- FHIR API
- AI Hub
- Vector Search

## MVP behaviour

Show active medication list, duplicate therapy detection, allergy cross-check, and a plain-language counselling summary.

Nice twist: use Vector Search over drug guidance content or patient education documents to return context-aware explanations.

## Expanded implementation detail

The workflow should perform a structured medication review. It should not replace a pharmacist or clinical decision support engine, but it can demonstrate how an agent can inspect patient medication data and produce explainable review findings.

The app should classify medications into active, historical, duplicate, and uncertain statuses. It should compare medications against known allergies and conditions. For a prototype, drug interaction logic can be simple and transparent, using seeded guidance documents or rules rather than a complete drug database.

Useful checks include duplicate therapy within the same class, medication listed despite allergy, medication that may require lab monitoring, potential adherence issue, and medication possibly contraindicated by a condition or observation.

## Agent outputs

```json
{
  "activeMedications": [],
  "duplicateTherapyAlerts": [],
  "allergyConflictAlerts": [],
  "monitoringNeeds": [],
  "adherenceConcerns": [],
  "clinicianSummary": "string",
  "patientCounsellingSummary": "string",
  "evidence": []
}
```

## Possible FHIR write-backs

- `DetectedIssue` for safety concerns.
- `Task` for pharmacist or clinician review.
- `Communication` for patient counselling draft.
- `CarePlan` item for medication monitoring.

## Demo notes

A strong demo should show a medication list and a safety finding with evidence, then draft a review task for a pharmacist or clinician.

---

# 5. AI-Powered Care Plan Navigator

## Original intent

Turn `CarePlan` and `Goal` resources into a guided experience for patients or care coordinators.

## FHIR resources

- `CarePlan`
- `Goal`
- `Task`
- `Appointment`
- `MedicationRequest`
- `Observation`

## InterSystems features

- AI Agents
- AI Hub
- FHIR API

## MVP behaviour

The app answers: “What should this patient do next?”, “What tasks are overdue?”, and “Which goals are off track?”

Nice twist: add an agent that creates suggested `Task` resources based on changes in observations or missed appointments.

## Expanded implementation detail

This workflow should convert a complex care plan into an actionable next-step view. It should understand whether a goal is improving, stable, worsening, overdue, blocked, or completed.

The agent should inspect active care-plan activities, goals and target dates, tasks and due dates, missed or upcoming appointments, medications that support the care plan, and recent observations related to care goals.

The value of the workflow is reducing ambiguity. Instead of simply listing a care plan, the agent should answer: “What should happen next, who owns it, and why?”

## Agent outputs

```json
{
  "carePlanSummary": "string",
  "nextBestActions": [],
  "overdueTasks": [],
  "offTrackGoals": [],
  "supportingObservations": [],
  "suggestedTaskDrafts": [],
  "patientFriendlyPlan": "string",
  "evidence": []
}
```

## Possible FHIR write-backs

- `Task` for next steps.
- `CarePlan` update or draft extension.
- `Goal` status suggestion.
- `Communication` for patient instructions.

## Demo notes

Show a patient with a chronic disease care plan, an overdue task, and a worsening observation. The agent should recommend a concrete next step and draft a `Task`.

---

# 6. Social Determinants and Community Referral Matcher

## Original intent

Use clinical and social data to recommend community resources for transportation, food insecurity, housing, or behavioural health support.

## FHIR resources

- `Condition`
- `Observation`
- `QuestionnaireResponse`
- `ServiceRequest`
- `CarePlan`
- `Patient`

## InterSystems features

- Vector Search
- AI Hub
- AI Agents

## MVP behaviour

Given a patient profile plus a small directory of local services, identify possible needs, recommend relevant resources, and generate a referral summary.

Nice twist: store community resources as semantically searchable content and use Vector Search to match needs to services.

## Expanded implementation detail

This agent should combine structured clinical context with social-needs screening responses. It should identify social risk categories and match them to community resources.

Possible needs include food insecurity, transport barrier, unstable housing, difficulty affording medications, behavioural health support, caregiver support, and language or accessibility need.

The resource directory can be small and mocked, but it should include useful metadata such as eligibility, geography, referral method, service type, and contact information.

## Agent outputs

```json
{
  "identifiedNeeds": [],
  "matchedResources": [
    {
      "resourceName": "string",
      "serviceType": "string",
      "matchReason": "string",
      "eligibilityNotes": "string",
      "contactOrReferralInstructions": "string"
    }
  ],
  "referralSummary": "string",
  "careTeamNextSteps": [],
  "evidence": []
}
```

## Possible FHIR write-backs

- `ServiceRequest` for community referral.
- `CarePlan` activity for social support.
- `Task` for care coordinator follow-up.
- `Communication` for patient-facing referral information.

## Demo notes

A strong demo should show a `QuestionnaireResponse` indicating a barrier, a vector search against community resources, and a generated referral summary.

---

# 7. FHIR Clinical Trial Matcher

## Original intent

Match patients to trial eligibility criteria using coded clinical data and relevant unstructured documents.

## FHIR resources

- `Condition`
- `Observation`
- `MedicationStatement`
- `Procedure`
- `Patient`
- `DocumentReference`

## InterSystems features

- Vector Search
- AI Hub
- AI Agents
- FHIR SQL Builder

## MVP behaviour

For a few mock trials, extract criteria, compare against patient profile, and show likely eligible / maybe / unlikely with rationale.

Nice twist: agent asks follow-up questions like “latest eGFR?” or “prior therapy present?” if criteria are incomplete.

## Expanded implementation detail

This workflow should compare a patient profile against trial criteria. It should be careful to distinguish confirmed eligibility, possible eligibility, exclusion criteria, and missing data.

A practical prototype can use three mock trials stored as documents. Each trial should include inclusion criteria, exclusion criteria, required labs, diagnosis requirements, prior therapy requirements, age range, and location or status.

The agent should retrieve relevant trial criteria via search, extract structured eligibility criteria, compare against patient evidence, and produce a transparent match rationale.

## Agent outputs

```json
{
  "trialMatches": [
    {
      "trialId": "string",
      "trialName": "string",
      "eligibilityStatus": "likely | maybe | unlikely",
      "matchedCriteria": [],
      "unmatchedCriteria": [],
      "exclusionConcerns": [],
      "missingDataQuestions": [],
      "rationale": "string"
    }
  ],
  "recommendedNextSteps": [],
  "evidence": []
}
```

## Possible FHIR write-backs

- `Task` for research coordinator review.
- `DocumentReference` for generated eligibility summary.
- `Communication` for clinician notification.
- `ServiceRequest` only if the workflow is explicitly modelled as referral request.

## Demo notes

Use a patient with enough data to match one trial strongly, one trial partially, and one trial poorly. This makes the triage output more interesting than a single match/no-match result.

---

# 8. Natural Language to FHIR Query Explorer

## Original intent

Let a user ask questions such as “Show diabetic patients with A1c above 9 in the last 6 months” and translate that into structured FHIR queries or FHIR SQL.

## FHIR resources

Any relevant set, especially:

- `Patient`
- `Condition`
- `Observation`
- `Encounter`

## InterSystems features

- FHIR SQL Builder
- AI Hub

## MVP behaviour

Support five to ten question patterns: cohort discovery, recent lab filters, medication-based populations, and encounter recency.

Nice twist: show the generated SQL or FHIR search so judges can see the transparency.

## Expanded implementation detail

This is a developer-experience workflow. The agent should convert natural language into safe, read-only structured query intent.

The system should not simply return results. It should show interpreted intent, generated FHIR search or SQL-style query, validation result, executed query, result preview, and explanation of limitations.

Useful supported patterns include diabetic patients with HbA1c above threshold, patients with encounters in the last N days, patients taking a medication class, patients with abnormal labs, patients missing recent follow-up, and patients with condition + observation combinations.

## Agent outputs

```json
{
  "userQuestion": "string",
  "interpretedIntent": "string",
  "generatedQueryType": "FHIR_SEARCH | SQL",
  "generatedQuery": "string",
  "validationStatus": "approved | rejected | needs_review",
  "queryExplanation": "string",
  "resultPreview": [],
  "limitations": [],
  "evidence": []
}
```

## Possible FHIR write-backs

Usually none. This should be read-only by default.

Optional: `DocumentReference` for a saved query report, or `Task` if a user wants to follow up on a cohort.

## Demo notes

This is ideal for showing transparency: user asks a natural language question, agent generates a query, app validates it as read-only, app executes it, and UI shows results and generated query side by side.

---

# 9. Hospital Readmission Risk Workbench

## Original intent

Build a prototype that estimates short-term readmission risk from recent utilisation, diagnoses, medications, and labs, then proposes interventions.

## FHIR resources

- `Encounter`
- `Condition`
- `Observation`
- `MedicationRequest`
- `CarePlan`
- `Patient`

## InterSystems features

- FHIR SQL Builder
- AI Hub
- Dashboards

## MVP behaviour

Use rule-based or lightweight scoring instead of a true ML model. Possible factors include recent admissions, high-risk conditions, missed follow-ups, abnormal labs, and polypharmacy.

Nice twist: generate recommended next steps as `Task` or `CarePlan` suggestions.

## Expanded implementation detail

This workflow should be framed as an explainable risk workbench, not a validated predictive model. The scoring should be transparent and rule-based.

Possible score inputs include number of admissions in the last 6 or 12 months, emergency encounters, high-risk chronic conditions, abnormal recent observations, number of active medications, missed follow-up appointments, prior readmission, and lack of active care plan.

The agent should turn the score into practical interventions: follow-up appointment, medication reconciliation, care manager outreach, lab follow-up, patient education, or transport support.

## Agent outputs

```json
{
  "riskScore": 0,
  "riskBand": "low | medium | high",
  "riskFactors": [],
  "protectiveFactors": [],
  "recommendedInterventions": [],
  "carePlanSuggestions": [],
  "taskSuggestions": [],
  "evidence": []
}
```

## Possible FHIR write-backs

- `Task` for care manager outreach.
- `CarePlan` suggestions for discharge follow-up.
- `ServiceRequest` for post-discharge service.
- `Communication` for patient instructions.

## Demo notes

Show the score as explainable. The judge should be able to see which evidence contributed to the risk band.

---

# 10. Conversational FHIR Triage Assistant

## Original intent

An AI agent asks patients structured triage questions, stores answers as `QuestionnaireResponse`, and creates a clinician handoff summary.

## FHIR resources

- `Questionnaire`
- `QuestionnaireResponse`
- `Condition`
- `Observation`
- `ServiceRequest`
- `Encounter`

## InterSystems features

- AI Agents
- AI Hub
- FHIR API

## MVP behaviour

The prototype can ask symptom questions, recommend urgency level, generate a structured handoff note, and create a follow-up task or service request.

Nice twist: map the conversation into coded FHIR observations where possible.

## Expanded implementation detail

This workflow should support a controlled, structured triage conversation. It should avoid unsafe autonomous advice. The agent should gather symptoms, duration, severity, red flags, relevant history, and patient preferences, then summarise the conversation for a clinician.

The app should make clear that urgency recommendations are draft triage support and require clinical review.

The agent can ask one question at a time or simulate a completed conversation for the demo. It should store structured answers and produce a clinician handoff.

## Agent outputs

```json
{
  "triageSummary": "string",
  "reportedSymptoms": [],
  "redFlags": [],
  "urgencyLevel": "self-care | routine | urgent | emergency",
  "recommendedDisposition": "string",
  "questionnaireResponse": {},
  "codedObservations": [],
  "clinicianHandoff": "string",
  "evidence": []
}
```

## Possible FHIR write-backs

- `QuestionnaireResponse` for captured answers.
- `Observation` for coded symptoms or measurements.
- `ServiceRequest` for follow-up.
- `Encounter` for triage encounter.
- `Task` for clinician review.

## Demo notes

The best demo is a short simulated chat that ends with a structured handoff and draft `QuestionnaireResponse`.

---

# 11. Imaging and Results Follow-Up Tracker

## Original intent

Track abnormal results and ensure they have documented follow-up, making it easier to spot closed-loop care failures.

## FHIR resources

- `Observation`
- `DiagnosticReport`
- `ServiceRequest`
- `Task`
- `Encounter`
- `Patient`

## InterSystems features

- FHIR SQL Builder
- AI Hub
- AI Agents

## MVP behaviour

Find abnormal results and show whether there is a follow-up appointment, a repeat order, a task, or a plan in notes.

Nice twist: use AI to draft an outreach or clinician reminder.

## Expanded implementation detail

This workflow should identify abnormal results and determine whether the care loop is closed. It is similar to the results-follow-up hero workflow in the FHIR Agent Studio architecture.

The system should classify each abnormal result as follow-up documented, follow-up scheduled, follow-up ordered, task exists but incomplete, no follow-up found, or ambiguous / needs review.

The AI component should explain why a result appears open and draft the appropriate reminder.

## Agent outputs

```json
{
  "abnormalResults": [],
  "followUpStatus": "closed | scheduled | ordered | open | ambiguous",
  "missingFollowUpReason": "string",
  "recommendedAction": "string",
  "clinicianReminderDraft": "string",
  "patientOutreachDraft": "string",
  "evidence": []
}
```

## Possible FHIR write-backs

- `Task` for clinician follow-up.
- `ServiceRequest` for repeat order suggestion.
- `Communication` for outreach draft.
- `CarePlan` activity if long-term follow-up is needed.

## Demo notes

This is arguably the strongest HealthConnect-style demo because it starts from a classic result event and ends with a traceable follow-up action.

A good demo receives or selects an abnormal result, searches for follow-up signals, shows “no follow-up found,” drafts a clinician `Task`, and shows trace plus evidence.

---

# 12. Patient-Friendly Lab Explainer

## Original intent

Convert lab results and trends into plain-language explanations for patients, with educational context and suggested questions for their doctor.

## FHIR resources

- `Observation`
- `DiagnosticReport`
- `Patient`

## InterSystems features

- AI Hub
- Vector Search

## MVP behaviour

Select a few lab types, such as CBC, A1c, lipids, or CMP, and generate what the result means, whether it changed over time, and what to ask next.

Nice twist: use Vector Search over trusted educational content to ground the explanation.

## Expanded implementation detail

This workflow should convert clinical lab data into patient-friendly, non-alarming language. It should compare current and prior observations where available and retrieve educational content to ground explanations.

The agent should be careful not to diagnose or overstate certainty. It should encourage the patient to speak with their clinician.

Useful behaviour includes identifying the lab test and result, classifying it as low, normal, high, or changed based on reference range if available, comparing with previous results, explaining common meaning in plain language, suggesting questions for a clinician, and including a safety disclaimer.

## Agent outputs

```json
{
  "labName": "string",
  "currentResult": "string",
  "trendSummary": "string",
  "plainLanguageExplanation": "string",
  "educationalContext": [],
  "questionsForDoctor": [],
  "whenToSeekHelp": "string",
  "evidence": []
}
```

## Possible FHIR write-backs

- `Communication` containing patient-facing explanation draft.
- `DocumentReference` for generated explanation.
- Usually no clinical action should be created automatically.

## Demo notes

Use a patient with three A1c values over time. Show that the agent explains both the current result and the trend in plain language, grounded by education snippets.

---

# Cross-cutting implementation ideas for all twelve tasks

## Common workflow shape

All suggested tasks can be modelled with the same pattern:

```text
Trigger → Evidence Retrieval → Agent Reasoning → Structured Output → FHIR Action → Trace
```

## Common evidence types

- FHIR resources from the patient compartment.
- SQL-style cohort or timeline facts.
- Vector-searched knowledge documents.
- User-supplied context, such as requested procedure, question, or symptom.
- Prior tasks, appointments, service requests, or care-plan items.

## Common output contract

A generic output schema can cover most tasks:

```json
{
  "summary": "string",
  "findings": [],
  "evidence": [],
  "recommendations": [],
  "missingData": [],
  "proposedActions": [],
  "safety": {
    "requiresHumanReview": true,
    "reason": "string"
  }
}
```

## Common FHIR write-back options

- `Task` — most useful generic follow-up resource.
- `ServiceRequest` — useful for referrals, orders, repeat testing, and follow-up services.
- `CarePlan` — useful for care coordination and intervention planning.
- `QuestionnaireResponse` — useful for triage and SDOH workflows.
- `DocumentReference` — useful for generated summaries or packets.
- `Communication` — useful for outreach and patient-facing drafts.
- `DetectedIssue` — useful for medication safety.

## Suggested three hero demos

For a single contest entry, the strongest three workflows to polish are:

1. **Imaging and Results Follow-Up Tracker** — strongest HealthConnect/event-driven patient-safety demo.
2. **FHIR Prior Authorization Copilot** — strongest business-value and Vector Search demo.
3. **Natural Language to FHIR Query Explorer** — strongest developer-experience demo.

These three together demonstrate clinical safety, administrative value, and developer productivity.

---

# Appendix: Competition timeline and submission reminders

## Dates from the competition page

- Contest begins: May 25, 2026 at 00:00 EST.
- Submission deadline: June 7, 2026 at 23:59 EST.
- Voting begins: June 8, 2026 at 00:00 EST.
- Voting ends: June 14, 2026 at 23:59 EST.

## Submission checklist

- Application works on IRIS Community Edition or IRIS for Health Community Edition.
- Application is open source on GitHub or GitLab.
- README is in English.
- README includes installation steps.
- README includes a video demo and/or a description of how the application works.
- Application is functional and not a simple wrapper around an existing app.
- Suggested-task implementation is clearly identified to claim the bonus.

