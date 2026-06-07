// Helpers for the clinician-facing surface: keep backend vocabulary (FHIR / SQL /
// vector / RAG / agent) out of what a clinician reads, and decide when an AI
// result is genuine enough to surface as an advisory.
import type { AgentResponse, EvidenceItem } from "@shared/api/types";

/** Where the result actually came from (cache replay / live model / deterministic). */
export function aiSource(resp: Pick<AgentResponse, "source" | "aiTrace">): string | undefined {
  return resp.aiTrace?.source ?? resp.source;
}

/** True when the model actually authored the result. The deterministic scaffold
 *  ("executed over N FHIR resources…") is never shown to a clinician as AI. */
export function isRealAi(resp: Pick<AgentResponse, "status" | "source" | "aiTrace">): boolean {
  return resp.status !== "error" && aiSource(resp) !== "deterministic";
}

const QUERY_LABELS: Record<string, string> = {
  active_conditions: "Active problems",
  recent_labs: "Recent lab results",
  recent_encounters: "Recent encounters",
  medication_history: "Medication history",
  admission_history: "Admission history",
  overdue_tasks: "Outstanding tasks",
  offtrack_goals: "Care-plan goals",
  overdue_screenings: "Preventive screenings",
  diabetes_a1c_followup: "Diabetes labs",
};

export interface PlainSourceGroup {
  label: string;
  items: string[];
}

/** Turn the raw evidence array into plain-language provenance groups for the
 *  "Why am I seeing this?" disclosure — no FHIR/SQL/vector/score wording. */
export function plainEvidence(evidence?: EvidenceItem[]): PlainSourceGroup[] {
  if (!evidence || evidence.length === 0) return [];
  const chart = new Set<string>();
  const refs = new Set<string>();
  const guides = new Set<string>();
  for (const e of evidence) {
    if (e.evidenceType === "KNOWLEDGE_CHUNK") {
      guides.add(e.display || e.source);
    } else if (e.evidenceType === "FHIR_QUERY") {
      chart.add(QUERY_LABELS[e.source] || titleCase(e.source));
    } else {
      // FHIR_RESOURCE — the display is already human-readable ("Metformin 1000mg")
      const d = (e.display || "").trim();
      if (d && !d.includes("/")) refs.add(d);
    }
  }
  const groups: PlainSourceGroup[] = [];
  if (chart.size) groups.push({ label: "From this patient's chart", items: [...chart] });
  if (refs.size) groups.push({ label: "Patient details considered", items: [...refs].slice(0, 12) });
  if (guides.size) groups.push({ label: "Clinical references", items: [...guides] });
  return groups;
}

function titleCase(s: string): string {
  return s.replace(/[_-]+/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

export type Severity = "info" | "warning" | "critical";

/** Map an agent result to a CDS severity indicator, per agent shape. */
export function advisorySeverity(slug: string, r: AgentResponse): Severity {
  const some = (a: unknown[] | undefined, pred: (x: any) => boolean) => Array.isArray(a) && a.some(pred);
  if (slug === "readmission-risk") {
    const b = (r.riskBand || "").toLowerCase();
    return b === "high" ? "critical" : b === "moderate" || b === "medium" ? "warning" : "info";
  }
  if (slug === "medication-safety") {
    if (some(r.interactions, (i) => ["high", "major", "critical"].includes((i.severity || "").toLowerCase()))) return "critical";
    return (r.interactions && r.interactions.length > 0) ? "warning" : "info";
  }
  if (slug === "results-followup") return r.proposedAction ? "warning" : "info";
  if (slug === "gaps-in-care") return some(r.gaps, (g) => (g.status || "").toLowerCase() === "overdue") ? "warning" : "info";
  if (slug === "care-plan-navigator") return some(r.goals, (g) => g.onTrack === false) ? "warning" : "info";
  if (slug === "sdoh-referral") return (r.needs && r.needs.length > 0) ? "warning" : "info";
  if (slug === "conversational-triage") {
    const a = (r.acuity || "").toLowerCase();
    return a === "emergency" || a === "emergent" ? "critical" : a === "urgent" ? "warning" : "info";
  }
  return "info";
}
