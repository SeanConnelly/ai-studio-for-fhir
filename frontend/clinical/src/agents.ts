// Demo scenario config — the single source of truth for which agent runs on which
// patient with which inputs. The inputs MUST match what the bundled LLM cache was
// built with, or the run misses the cache and falls to the deterministic scaffold
// (which the UI never presents as AI). Flagship = Archie Patel / syn-pat-0001.

export interface AgentScenario {
  /** flow slug */
  agent: string;
  /** Patient/<id> */
  patient: string;
  /** clinician-facing card title */
  title: string;
  /** extra inputs beyond `patient` (must match the cached testCase) */
  inputs?: Record<string, string>;
}

/** Home worklist — the async/event/scan agents, each on its cached demo patient. */
export interface WorklistQueue extends AgentScenario {
  key: string;
  group: string; // section heading
  blurb: string; // what this queue is
}

export const WORKLIST: WorklistQueue[] = [
  {
    key: "results",
    group: "Patient safety",
    title: "Abnormal result — no documented follow-up",
    blurb: "Abnormal results where the care loop isn't closed.",
    agent: "results-followup",
    patient: "Patient/pat-abnormal-001",
    inputs: { diagnosticReportId: "DiagnosticReport/dr-abnormal-001" },
  },
  {
    key: "readmission",
    group: "Recent discharges",
    title: "Post-discharge readmission risk",
    blurb: "Recently discharged patients scored for readmission risk.",
    agent: "readmission-risk",
    patient: "Patient/syn-pat-0085",
  },
  {
    key: "social",
    group: "Social needs",
    title: "Positive social-needs screening — local support matched",
    blurb: "Patients whose screening reported needs, matched to local services for social prescribing.",
    agent: "sdoh-referral",
    patient: "Patient/syn-pat-0061",
  },
];

/** The first 25 patients in the patient search (ORDER BY family, given). Each has
 *  cached Medication-safety, Care-Plan-Navigator and Lab-results-explained runs
 *  (plus the cohort-wide Smart Summary), so a judge who simply browses the patient
 *  list and clicks the top results always lands on a fully-populated chart — not a
 *  thin one. These are badged "demo-ready" in the patient search. The synthetic
 *  data is deterministic, so this top-25 ordering is stable across clean builds.
 *  KEEP IN SYNC with scripts/build-demo-patients-cache.mjs. */
export const DEMO_READY_PATIENTS = new Set([
  "syn-pat-0961", "syn-pat-0922", "syn-pat-0541", "syn-pat-0878", "syn-pat-0902",
  "syn-pat-0933", "syn-pat-0452", "syn-pat-0060", "syn-pat-0464", "syn-pat-0909",
  "syn-pat-0349", "syn-pat-0808", "syn-pat-0277", "syn-pat-0796", "syn-pat-0602",
  "syn-pat-0810", "syn-pat-0774", "syn-pat-0981", "syn-pat-0313", "syn-pat-0210",
  "syn-pat-0391", "syn-pat-0383", "syn-pat-0139", "pat-prior-auth-001", "syn-pat-0211",
]);

const DEMO_READY_SUPPORT: { agent: string; title: string }[] = [
  { agent: "medication-safety", title: "Medication safety review" },
  { agent: "care-plan-navigator", title: "Care-plan review" },
  { agent: "lab-explainer", title: "Lab results, explained" },
];

/** In-chart on-demand decision support, keyed by patient id. Only patients with
 *  rebuilt cache entries are listed, so the chart never shows a deterministic run.
 *  The flagship has the full bespoke set; the 25 demo-ready patients get the three
 *  broadly-applicable chart agents. */
export const CHART_DECISION_SUPPORT: Record<string, AgentScenario[]> = {
  "syn-pat-0001": [
    { agent: "medication-safety", patient: "Patient/syn-pat-0001", title: "Medication safety review" },
    { agent: "care-plan-navigator", patient: "Patient/syn-pat-0001", title: "Care-plan review" },
    { agent: "lab-explainer", patient: "Patient/syn-pat-0001", title: "Lab results, explained" },
    { agent: "clinical-trial-matcher", patient: "Patient/syn-pat-0001", title: "Trial eligibility" },
    { agent: "gaps-in-care", patient: "Patient/syn-pat-0001", title: "Preventive care gaps", inputs: { gapType: "diabetes-a1c" } },
  ],
  ...Object.fromEntries(
    [...DEMO_READY_PATIENTS].map((id) => [
      id,
      DEMO_READY_SUPPORT.map((s) => ({ agent: s.agent, patient: `Patient/${id}`, title: s.title })),
    ])
  ),
};

/** Worklist demo patients that also have a rebuilt Smart Summary. */
export const SUMMARY_PATIENTS = new Set([
  "syn-pat-0001", "pat-abnormal-001", "syn-pat-0085", "syn-pat-0025", "syn-pat-0061",
]);

/** Trial-matcher demo patients — each has a cached match run (and the flagship
 *  also has a cached "answered follow-ups" run). Shown on the Trials page picker
 *  and as a chart section. */
export const TRIAL_PATIENTS: AgentScenario[] = [
  { agent: "clinical-trial-matcher", patient: "Patient/syn-pat-0001", title: "Trial matches" },
  { agent: "clinical-trial-matcher", patient: "Patient/syn-pat-0073", title: "Trial matches" },
  { agent: "clinical-trial-matcher", patient: "Patient/syn-pat-0075", title: "Trial matches" },
  { agent: "clinical-trial-matcher", patient: "Patient/syn-pat-0102", title: "Trial matches" },
];

/** The scripted follow-up answer per patient that replays from the cache
 *  (the "Use example answer" chip). MUST match the cached run verbatim. */
export const TRIAL_SUGGESTED_ANSWERS: Record<string, string> = {
  "syn-pat-0001":
    "He completed a 6-month dietitian-led weight management programme last year without sustained weight loss. Latest triglycerides 180 mg/dL with normal liver function tests.",
};

/** Triage conversation scenarios — patient + pinned complaint. Phase-1
 *  questions and EVERY answer-combination handoff are pre-built into the cache
 *  (scripts/build-triage-cache.mjs), so any path through the chat replays
 *  real AI key-free. Single source of truth: seed/demo-inputs/triage-scenarios.json
 *  (shared verbatim with the cache builder — the strings are cache keys). */
import triageCatalogue from "../../../seed/demo-inputs/triage-scenarios.json";
export const TRIAGE_SCENARIOS: { patient: string; complaint: string; label: string }[] = triageCatalogue.scenarios;

/** The results follow-up cohort — every loop state represented: an open lab
 *  result, an overdue BI-RADS 4 mammogram, a pending nodule CT, and a closed
 *  renal follow-up. Each has a cached tracker run. */
export const RESULTS_PATIENTS: AgentScenario[] = [
  { agent: "results-followup", patient: "Patient/pat-abnormal-001", title: "Results follow-up", inputs: { diagnosticReportId: "DiagnosticReport/dr-abnormal-001" } },
  { agent: "results-followup", patient: "Patient/syn-pat-0002", title: "Results follow-up", inputs: { diagnosticReportId: "" } },
  { agent: "results-followup", patient: "Patient/syn-pat-0003", title: "Results follow-up", inputs: { diagnosticReportId: "" } },
  { agent: "results-followup", patient: "Patient/syn-pat-0004", title: "Results follow-up", inputs: { diagnosticReportId: "" } },
];

/** The discharge band: every recently-discharged patient has a cached
 *  readmission-risk run, so the risk worklist ranks the full cohort. */
export const READMISSION_PATIENTS: AgentScenario[] = Array.from({ length: 12 }, (_, k) => {
  const id = `syn-pat-${String(k + 85).padStart(4, "0")}`;
  return { agent: "readmission-risk", patient: `Patient/${id}`, title: "Readmission risk" };
});

/** The patient-portal demo cohort: every one has a cached Care Plan Navigator
 *  AND a cached social-prescribing run, so both phone-app tabs always work. */
export const PORTAL_PATIENTS: AgentScenario[] = Array.from({ length: 12 }, (_, k) => {
  const id = `syn-pat-${String(k + 1).padStart(4, "0")}`;
  return { agent: "sdoh-referral", patient: `Patient/${id}`, title: "Social prescribing" };
});

/** Every portal patient also has a cached "results explained" run, so the
 *  phone app's Results tab works for all of them. */
export const LAB_PATIENTS: AgentScenario[] = Array.from({ length: 12 }, (_, k) => {
  const id = `syn-pat-${String(k + 1).padStart(4, "0")}`;
  return { agent: "lab-explainer", patient: `Patient/${id}`, title: "Results, explained" };
});

const ALL_SCENARIOS: AgentScenario[] = [...WORKLIST, ...Object.values(CHART_DECISION_SUPPORT).flat(), ...PORTAL_PATIENTS, ...LAB_PATIENTS, ...TRIAL_PATIENTS, ...READMISSION_PATIENTS, ...RESULTS_PATIENTS];

/** The exact extra inputs an agent was cached with for a given patient (so a
 *  demo run hits the cache). Empty when the combo wasn't part of the rebuild. */
export function scenarioInputs(patientRef: string, agent: string): Record<string, string> {
  const m = ALL_SCENARIOS.find((s) => s.patient === patientRef && s.agent === agent);
  return m?.inputs || {};
}

/** Does this patient have a rebuilt (cache-real) entry for this agent? */
export function hasScenario(patientId: string, agent: string): boolean {
  const ref = `Patient/${patientId}`;
  return ALL_SCENARIOS.some((s) => s.patient === ref && s.agent === agent);
}
