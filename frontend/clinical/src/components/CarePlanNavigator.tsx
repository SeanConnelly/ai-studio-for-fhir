// AI-Powered Care Plan Navigator — turns the patient's CarePlan + Goals + Tasks
// into an actionable next-step view: current status, what to do next, what's
// overdue/off-track, and AI-suggested new tasks (with rationale). Colour-coded
// (green on track / amber at risk / red off track) with one-click actions.
import { useEffect, useState } from "react";
import {
  Compass, Loader2, Sparkles, ArrowRight, Clock, Lightbulb, CheckCircle2,
  ListChecks, MessageSquare, Check,
} from "lucide-react";
import { api } from "@shared/api/client";
import type { AgentResponse } from "@shared/api/types";
import { isRealAi } from "@shared/lib/clinical";

// A categorical 3-segment indicator (not a fake percentage): on track fills 3,
// at risk 2, off track 1 — an honest visual for a 3-state assessment.
function goalTone(onTrack?: boolean): { bar: string; fill: string; chip: string; label: string; filled: number } {
  if (onTrack === true) return { bar: "bg-emerald-100", fill: "bg-emerald-500", chip: "bg-emerald-100 text-emerald-800", label: "On track", filled: 3 };
  if (onTrack === false) return { bar: "bg-rose-100", fill: "bg-rose-500", chip: "bg-rose-100 text-rose-800", label: "Off track", filled: 1 };
  return { bar: "bg-amber-100", fill: "bg-amber-500", chip: "bg-amber-100 text-amber-800", label: "At risk", filled: 2 };
}

export function CarePlanNavigator({ patientId }: { patientId: string }) {
  const [resp, setResp] = useState<AgentResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [tasksCreated, setTasksCreated] = useState<number | null>(null);
  const [creating, setCreating] = useState(false);
  const [messaged, setMessaged] = useState(false);
  const [discussed, setDiscussed] = useState(false);

  // both one-click actions record REAL FHIR Communication resources
  async function sendMessage() {
    if (!resp?.patientMessage) return;
    try {
      await api.sendCommunication(patientId, { category: "patient-message", text: resp.patientMessage });
      setMessaged(true);
    } catch { /* leave button active */ }
  }
  async function markDiscussed() {
    try {
      await api.sendCommunication(patientId, { category: "care-plan-discussion", text: "Care plan and AI-suggested tasks discussed with the patient." });
      setDiscussed(true);
    } catch { /* leave button active */ }
  }

  useEffect(() => {
    setLoading(true); setResp(null); setTasksCreated(null); setMessaged(false); setDiscussed(false);
    api.runAgent("care-plan-navigator", { patient: `Patient/${patientId}` })
      .then(setResp).catch(() => setResp(null)).finally(() => setLoading(false));
  }, [patientId]);

  async function acceptTasks() {
    if (!resp?.suggestedTasks?.length) return;
    setCreating(true);
    try {
      const r = await api.createCarePlanTasks(patientId, resp.suggestedTasks.map((t) => ({ task: t.task, owner: t.owner })));
      setTasksCreated(r.created);
    } finally {
      setCreating(false);
    }
  }

  const Card = ({ children }: { children: React.ReactNode }) => <div className="rounded-lg border bg-card shadow-sm">{children}</div>;

  if (loading) {
    return <Card><div className="flex items-center gap-2 px-4 py-3 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" /> Reviewing the care plan…</div></Card>;
  }
  if (!resp || !isRealAi(resp)) {
    return <Card><div className="px-4 py-3 text-sm text-muted-foreground">The Care Plan Navigator isn't available for this patient. (Available on the demo cohort syn-pat-0001…0012.)</div></Card>;
  }

  return (
    <div className="rounded-lg border bg-card shadow-sm">
      <div className="flex flex-wrap items-center gap-2 border-b px-4 py-2.5 text-sm font-semibold text-foreground">
        <Compass className="h-4 w-4 text-nhs-600" /> Care Plan Navigator
        <span className="ml-auto inline-flex items-center gap-1 rounded-full bg-nhs-600 px-2.5 py-0.5 text-[11px] font-bold uppercase tracking-wide text-white"><Sparkles className="h-3 w-3" /> AI generated</span>
      </div>

      <div className="space-y-5 px-4 py-4">
        {/* Current status */}
        {resp.summary && (
          <div>
            <div className="mb-1 text-xs font-semibold uppercase tracking-wide text-muted-foreground">Current status</div>
            <p className="text-sm leading-relaxed text-foreground">{resp.summary}</p>
          </div>
        )}

        {/* What to do next */}
        {resp.nextSteps && resp.nextSteps.length > 0 && (
          <div>
            <div className="mb-2 flex items-center gap-1.5 text-sm font-semibold"><ArrowRight className="h-4 w-4 text-nhs-600" /> What should happen next</div>
            <ol className="space-y-2">
              {resp.nextSteps.map((s, i) => (
                <li key={i} className="flex gap-2.5 text-sm">
                  <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-nhs-100 text-[11px] font-bold text-nhs-700">{i + 1}</span>
                  <span><span className="font-medium">{s.action}</span>{s.detail && <span className="text-muted-foreground"> — {s.detail}</span>}</span>
                </li>
              ))}
            </ol>
          </div>
        )}

        {/* Goals with progress */}
        {resp.goals && resp.goals.length > 0 && (
          <div>
            <div className="mb-2 flex items-center gap-1.5 text-sm font-semibold"><ListChecks className="h-4 w-4 text-nhs-600" /> Goals</div>
            <div className="space-y-2.5">
              {resp.goals.map((g, i) => {
                const t = goalTone(g.onTrack);
                return (
                  <div key={i}>
                    <div className="flex items-center gap-2 text-sm">
                      <span className="font-medium">{g.goal}</span>
                      <span className={`rounded-full px-2 py-0.5 text-[11px] font-medium ${t.chip}`}>{t.label}</span>
                    </div>
                    <div className="mt-1 flex gap-1">
                      {[0, 1, 2].map((seg) => <div key={seg} className={`h-1.5 flex-1 rounded-full ${seg < t.filled ? t.fill : t.bar}`} />)}
                    </div>
                    {g.detail && <div className="mt-0.5 text-xs text-muted-foreground">{g.detail}</div>}
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* Overdue */}
        {resp.overdueTasks && resp.overdueTasks.length > 0 && (
          <div>
            <div className="mb-2 flex items-center gap-1.5 text-sm font-semibold text-rose-700"><Clock className="h-4 w-4" /> Overdue</div>
            <div className="space-y-1.5">
              {resp.overdueTasks.map((t, i) => (
                <div key={i} className="rounded-md border border-rose-200 bg-rose-50/40 px-3 py-2 text-sm">
                  <span className="font-medium">{t.task}</span>{t.detail && <span className="text-rose-700"> — {t.detail}</span>}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* AI suggested new tasks */}
        {resp.suggestedTasks && resp.suggestedTasks.length > 0 && (
          <div>
            <div className="mb-2 flex items-center gap-1.5 text-sm font-semibold"><Lightbulb className="h-4 w-4 text-amber-500" /> AI-suggested new tasks</div>
            <div className="space-y-2">
              {resp.suggestedTasks.map((t, i) => (
                <div key={i} className="rounded-md border p-3 text-sm">
                  <div className="font-medium">{t.task}{t.owner && <span className="font-normal text-muted-foreground"> · {t.owner}</span>}</div>
                  {t.rationale && <div className="mt-0.5 text-xs text-muted-foreground"><span className="font-medium">Why:</span> {t.rationale}</div>}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* One-click actions */}
        <div className="flex flex-wrap items-center gap-2 border-t pt-3">
          {resp.suggestedTasks && resp.suggestedTasks.length > 0 && (
            tasksCreated === null ? (
              <button onClick={acceptTasks} disabled={creating} className="inline-flex items-center gap-1.5 rounded-md bg-nhs-600 px-3 py-2 text-sm font-medium text-white hover:bg-nhs-700 disabled:opacity-60">
                {creating ? <Loader2 className="h-4 w-4 animate-spin" /> : <ListChecks className="h-4 w-4" />}
                {creating ? "Creating…" : "Accept & create tasks"}
              </button>
            ) : (
              <span className="inline-flex items-center gap-1.5 text-sm font-medium text-emerald-700"><CheckCircle2 className="h-4 w-4" /> {tasksCreated} task{tasksCreated === 1 ? "" : "s"} created in the record</span>
            )
          )}
          {resp.patientMessage && (
            <button onClick={sendMessage} disabled={messaged} className="inline-flex items-center gap-1.5 rounded-md border px-3 py-2 text-sm font-medium hover:bg-muted/50 disabled:opacity-80">
              {messaged ? <Check className="h-4 w-4 text-emerald-600" /> : <MessageSquare className="h-4 w-4" />}{messaged ? "Message recorded in the chart" : "Send patient message"}
            </button>
          )}
          <button onClick={markDiscussed} disabled={discussed} className="inline-flex items-center gap-1.5 rounded-md border px-3 py-2 text-sm font-medium hover:bg-muted/50 disabled:opacity-80">
            {discussed ? <Check className="h-4 w-4 text-emerald-600" /> : null}{discussed ? "Discussion noted in the chart" : "Mark as discussed"}
          </button>
        </div>
        <p className="text-[11px] text-muted-foreground">AI-generated from this patient's chart — review before acting. Drafts only; nothing is sent automatically.</p>
      </div>
    </div>
  );
}
