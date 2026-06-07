// Readmission Risk Workbench — the in-chart view. A colour-coded score banner,
// the classic risk-factor breakdown (each citing real record values), the AI's
// narrative insight, and suggested preventive tasks with one-click "Accept all"
// (creates real FHIR Tasks). Cross-links to the chart's Medication safety and
// Social care sections where they exist. Only ever shows genuine AI output.
import { useEffect, useState } from "react";
import {
  Activity, Loader2, Sparkles, Lightbulb, ListChecks, CheckCircle2, Link2,
} from "lucide-react";
import { api } from "@shared/api/client";
import type { AgentResponse } from "@shared/api/types";
import { isRealAi } from "@shared/lib/clinical";
import { hasScenario } from "@/agents";

function bandTone(band?: string): { banner: string; chip: string; bar: string; label: string } {
  const b = (band || "").toLowerCase();
  if (b === "high") return { banner: "border-rose-200 bg-rose-50/60", chip: "bg-rose-600 text-white", bar: "bg-rose-500", label: "High risk" };
  if (b === "moderate") return { banner: "border-amber-200 bg-amber-50/60", chip: "bg-amber-500 text-white", bar: "bg-amber-500", label: "Moderate risk" };
  return { banner: "border-emerald-200 bg-emerald-50/60", chip: "bg-emerald-600 text-white", bar: "bg-emerald-500", label: "Low risk" };
}

function levelChip(level?: string): string {
  const l = (level || "").toLowerCase();
  if (l === "high") return "bg-rose-100 text-rose-800";
  if (l === "medium" || l === "moderate") return "bg-amber-100 text-amber-800";
  return "bg-emerald-100 text-emerald-800";
}

export function ReadmissionSection({ patientId, onJump }: { patientId: string; onJump?: (key: string) => void }) {
  const [resp, setResp] = useState<AgentResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [created, setCreated] = useState<number | null>(null);
  const [creating, setCreating] = useState(false);

  useEffect(() => {
    setResp(null); setCreated(null); setLoading(true);
    api.runAgent("readmission-risk", { patient: `Patient/${patientId}` })
      .then(setResp).catch(() => setResp(null)).finally(() => setLoading(false));
  }, [patientId]);

  async function acceptAll() {
    if (!resp?.suggestedTasks?.length) return;
    setCreating(true);
    try {
      const r = await api.createCarePlanTasks(patientId, resp.suggestedTasks.map((t) => ({ task: t.task })));
      setCreated(r.created);
    } finally { setCreating(false); }
  }

  if (loading) {
    return (
      <div className="flex items-center gap-2 rounded-lg border bg-card px-4 py-3 text-sm text-muted-foreground shadow-sm">
        <Loader2 className="h-4 w-4 animate-spin" /> Scoring readmission risk…
      </div>
    );
  }
  if (!resp || !isRealAi(resp)) {
    return (
      <div className="rounded-lg border bg-card px-4 py-3 text-sm text-muted-foreground shadow-sm">
        Readmission risk scoring isn't available for this patient.
      </div>
    );
  }

  const tone = bandTone(resp.riskBand);
  const score = typeof resp.riskScore === "number" ? Math.max(0, Math.min(100, resp.riskScore)) : null;

  return (
    <div className="rounded-lg border bg-card shadow-sm">
      <div className="flex flex-wrap items-center gap-2 border-b px-4 py-2.5 text-sm font-semibold">
        <Activity className="h-4 w-4 text-nhs-600" /> Readmission risk
        <span className="ml-auto inline-flex items-center gap-1 rounded-full bg-nhs-600 px-2.5 py-0.5 text-[11px] font-bold uppercase tracking-wide text-white"><Sparkles className="h-3 w-3" /> AI generated</span>
      </div>

      <div className="space-y-5 px-4 py-4">
        {/* Score banner */}
        <div className={`rounded-lg border p-4 ${tone.banner}`}>
          <div className="flex flex-wrap items-center gap-3">
            <span className={`rounded-full px-3 py-1 text-sm font-bold ${tone.chip}`}>{tone.label}</span>
            {score !== null && <span className="text-2xl font-bold">{score}<span className="text-sm font-medium text-muted-foreground">/100</span></span>}
            {resp.thirtyDayEstimate && (
              <span className="text-sm text-muted-foreground">30-day readmission estimate <span className="font-semibold text-foreground">{resp.thirtyDayEstimate}</span></span>
            )}
          </div>
          {score !== null && (
            <div className="mt-2.5 h-2 w-full overflow-hidden rounded-full bg-white/70">
              <div className={`h-full rounded-full ${tone.bar}`} style={{ width: `${score}%` }} />
            </div>
          )}
          {resp.summary && <p className="mt-2.5 text-sm leading-relaxed">{resp.summary}</p>}
        </div>

        {/* Risk factor breakdown */}
        {resp.riskFactors && resp.riskFactors.length > 0 && (
          <div>
            <div className="mb-2 text-sm font-semibold">Risk factors</div>
            <div className="overflow-hidden rounded-md border">
              <table className="w-full text-sm">
                <tbody>
                  {resp.riskFactors.map((f, i) => (
                    <tr key={i} className="border-b last:border-0">
                      <td className="w-44 px-3 py-2 font-medium">{f.factor}</td>
                      <td className="w-24 px-3 py-2">
                        <span className={`rounded-full px-2 py-0.5 text-[11px] font-semibold capitalize ${levelChip(f.level)}`}>{f.level}</span>
                      </td>
                      <td className="px-3 py-2 text-muted-foreground">{f.detail}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* Narrative insight */}
        {resp.insights && (
          <div className="rounded-md border border-sky-200 bg-sky-50/40 p-3 text-sm">
            <div className="mb-1 flex items-center gap-1.5 font-medium text-sky-800"><Lightbulb className="h-4 w-4" /> What this means</div>
            <p className="leading-relaxed">{resp.insights}</p>
          </div>
        )}

        {/* Suggested preventive tasks + one-click accept */}
        {resp.suggestedTasks && resp.suggestedTasks.length > 0 && (
          <div>
            <div className="mb-2 flex items-center gap-1.5 text-sm font-semibold"><ListChecks className="h-4 w-4 text-nhs-600" /> Suggested preventive actions</div>
            <div className="space-y-2">
              {resp.suggestedTasks.map((t, i) => (
                <div key={i} className="rounded-md border p-3 text-sm">
                  <div className="font-medium">{t.task}</div>
                  {t.rationale && <div className="mt-0.5 text-xs text-muted-foreground"><span className="font-medium">Why:</span> {t.rationale}</div>}
                </div>
              ))}
            </div>
            <div className="mt-2.5 flex flex-wrap items-center gap-2">
              {created === null ? (
                <button onClick={acceptAll} disabled={creating} className="inline-flex items-center gap-1.5 rounded-md bg-nhs-600 px-3 py-2 text-sm font-medium text-white hover:bg-nhs-700 disabled:opacity-60">
                  {creating ? <Loader2 className="h-4 w-4 animate-spin" /> : <ListChecks className="h-4 w-4" />}
                  {creating ? "Creating…" : "Accept all & create tasks"}
                </button>
              ) : (
                <span className="inline-flex items-center gap-1.5 text-sm font-medium text-emerald-700"><CheckCircle2 className="h-4 w-4" /> {created} task{created === 1 ? "" : "s"} created in the record</span>
              )}
              {/* cross-links into the other in-chart agents */}
              {onJump && hasScenario(patientId, "medication-safety") && (
                <button onClick={() => onJump("med-safety")} className="inline-flex items-center gap-1.5 rounded-md border px-3 py-2 text-sm font-medium hover:bg-muted/50">
                  <Link2 className="h-4 w-4" /> Medication safety review
                </button>
              )}
              {onJump && hasScenario(patientId, "sdoh-referral") && (
                <button onClick={() => onJump("social")} className="inline-flex items-center gap-1.5 rounded-md border px-3 py-2 text-sm font-medium hover:bg-muted/50">
                  <Link2 className="h-4 w-4" /> Social needs check
                </button>
              )}
            </div>
          </div>
        )}

        <p className="text-[11px] text-muted-foreground">AI-generated from this patient's chart — review before acting. Tasks are created only when you accept them.</p>
      </div>
    </div>
  );
}
