// Results Follow-Up Tracker — the in-chart view. Every abnormal imaging and
// lab result with its loop status (overdue / pending / closed), the documented
// follow-up (or "none found"), AI-drafted outreach to the patient and a note
// to the clinician, and a signable draft order to close the most urgent loop.
import { useEffect, useState } from "react";
import { Loader2, Sparkles, ClipboardList, MessageCircle, Stethoscope, CheckCircle2, Clock3, AlertTriangle } from "lucide-react";
import { api } from "@shared/api/client";
import type { AgentResponse } from "@shared/api/types";
import { isRealAi } from "@shared/lib/clinical";
import { scenarioInputs } from "@/agents";
import { DraftActionCard } from "@shared/components/clinical/DraftActionCard";

function statusChip(s?: string): { cls: string; icon: JSX.Element; label: string } {
  const v = (s || "").toLowerCase();
  if (v === "closed") return { cls: "bg-emerald-100 text-emerald-800", icon: <CheckCircle2 className="h-3.5 w-3.5" />, label: "Closed" };
  if (v === "pending") return { cls: "bg-amber-100 text-amber-800", icon: <Clock3 className="h-3.5 w-3.5" />, label: "Pending" };
  return { cls: "bg-rose-100 text-rose-800", icon: <AlertTriangle className="h-3.5 w-3.5" />, label: "Overdue" };
}

export function ResultsFollowUpSection({ patientId }: { patientId: string }) {
  const [resp, setResp] = useState<AgentResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [actionId, setActionId] = useState<string | null>(null);
  const [decided, setDecided] = useState<{ decision: string; reviewer?: string; committedRef?: string } | null>(null);

  useEffect(() => {
    setResp(null); setDecided(null); setActionId(null); setLoading(true);
    api.runAgent("results-followup", { patient: `Patient/${patientId}`, ...scenarioInputs(`Patient/${patientId}`, "results-followup") })
      .then(async (r) => {
        setResp(r);
        if (r?.requestId && r?.proposedAction) {
          try {
            const inv = await api.invocation(r.requestId);
            setActionId(inv.proposedActions?.[0]?.id || null);
          } catch { /* draft stays read-only */ }
        }
      })
      .catch(() => setResp(null))
      .finally(() => setLoading(false));
  }, [patientId]);

  async function sign() {
    if (!resp?.requestId || !actionId) return;
    setBusy(true);
    try {
      const r = await api.approveAction(resp.requestId, actionId, { reviewer: "Demo Clinician" });
      setDecided({ decision: "approved", reviewer: "Demo Clinician", committedRef: r.committedResourceRef });
    } finally { setBusy(false); }
  }
  async function decline() {
    if (!resp?.requestId || !actionId) return;
    setBusy(true);
    try {
      await api.rejectAction(resp.requestId, actionId, { reviewer: "Demo Clinician" });
      setDecided({ decision: "rejected", reviewer: "Demo Clinician" });
    } finally { setBusy(false); }
  }

  if (loading) {
    return (
      <div className="flex items-center gap-2 rounded-lg border bg-card px-4 py-3 text-sm text-muted-foreground shadow-sm">
        <Loader2 className="h-4 w-4 animate-spin" /> Checking every abnormal result for documented follow-up…
      </div>
    );
  }
  if (!resp || !isRealAi(resp)) {
    return (
      <div className="rounded-lg border bg-card px-4 py-3 text-sm text-muted-foreground shadow-sm">
        Results follow-up tracking isn't available for this patient.
      </div>
    );
  }

  return (
    <div className="rounded-lg border bg-card shadow-sm">
      <div className="flex flex-wrap items-center gap-2 border-b px-4 py-2.5 text-sm font-semibold">
        <ClipboardList className="h-4 w-4 text-nhs-600" /> Results follow-up
        <span className="ml-auto inline-flex items-center gap-1 rounded-full bg-nhs-600 px-2.5 py-0.5 text-[11px] font-bold uppercase tracking-wide text-white"><Sparkles className="h-3 w-3" /> AI generated</span>
      </div>

      <div className="space-y-4 px-4 py-4">
        {resp.closedLoopSummary && (
          <div className="rounded-md border bg-muted/30 px-3.5 py-2.5 text-sm font-medium">{resp.closedLoopSummary}</div>
        )}

        {/* Per-result loop status */}
        {resp.trackedResults && resp.trackedResults.length > 0 && (
          <div className="space-y-2.5">
            {resp.trackedResults.map((r, i) => {
              const chip = statusChip(r.followUpStatus);
              return (
                <div key={i} className={`rounded-md border p-3 text-sm ${chip.label === "Overdue" ? "border-rose-200 bg-rose-50/40" : ""}`}>
                  <div className="flex flex-wrap items-center gap-2">
                    <span className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-semibold ${chip.cls}`}>{chip.icon}{chip.label}</span>
                    <span className="font-medium">{r.result}</span>
                    {r.date && <span className="text-xs text-muted-foreground">{r.date}</span>}
                  </div>
                  <p className="mt-1.5">{r.finding}</p>
                  <div className="mt-1.5 space-y-0.5 text-muted-foreground">
                    {r.followUp && <p><span className="font-medium text-foreground">Documented follow-up:</span> {r.followUp}</p>}
                    {r.action && <p><span className="font-medium text-foreground">Next:</span> {r.action}</p>}
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {/* AI-drafted outreach */}
        {(resp.patientOutreach || resp.clinicianNote) && (
          <div className="grid gap-3 md:grid-cols-2">
            {resp.patientOutreach && (
              <div className="rounded-md border border-sky-200 bg-sky-50/40 p-3 text-sm">
                <div className="mb-1 flex items-center gap-1.5 font-medium text-sky-800"><MessageCircle className="h-4 w-4" /> Draft message to the patient</div>
                <p className="leading-relaxed">{resp.patientOutreach}</p>
                <p className="mt-1.5 text-[11px] text-muted-foreground">Review and edit before sending — nothing is sent automatically.</p>
              </div>
            )}
            {resp.clinicianNote && (
              <div className="rounded-md border p-3 text-sm">
                <div className="mb-1 flex items-center gap-1.5 font-medium"><Stethoscope className="h-4 w-4 text-nhs-600" /> Note to the responsible clinician</div>
                <p className="leading-relaxed text-muted-foreground">{resp.clinicianNote}</p>
              </div>
            )}
          </div>
        )}

        {resp.proposedAction?.resourceType && (
          <DraftActionCard
            resourceType={resp.proposedAction.resourceType}
            resource={resp.proposedAction.resource}
            busy={busy}
            decided={decided}
            onSign={actionId ? sign : undefined}
            onDecline={actionId ? decline : undefined}
          />
        )}
        <p className="text-[11px] text-muted-foreground">AI-generated from this patient's results and record — a clinician reviews and signs every action.</p>
      </div>
    </div>
  );
}
