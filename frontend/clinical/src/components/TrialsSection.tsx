// Clinical trial matching — runs the trial-matcher agent for a patient and
// renders graded matches (likely / maybe / unlikely with cited criteria and
// washout flags), the AI's follow-up questions for missing data (answerable:
// an answer re-runs the match and can upgrade a grade), and a signable draft
// referral Task to the research coordinator. Used by both the patient chart's
// "Clinical trials" section and the standalone Trials page.
import { useEffect, useState } from "react";
import { Loader2, MessageCircleQuestion, RefreshCw, Sparkles } from "lucide-react";
import { api } from "@shared/api/client";
import type { AgentResponse } from "@shared/api/types";
import { advisorySeverity, isRealAi } from "@shared/lib/clinical";
import { TRIAL_SUGGESTED_ANSWERS } from "@/agents";
import { ClinicalResult } from "@/components/ClinicalResult";

export function TrialsSection({ patientId }: { patientId: string }) {
  const [resp, setResp] = useState<AgentResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [answers, setAnswers] = useState("");
  const [answered, setAnswered] = useState(false);
  const [busy, setBusy] = useState(false);
  const [actionId, setActionId] = useState<string | null>(null);
  const [decided, setDecided] = useState<{ decision: string; reviewer?: string; committedRef?: string } | null>(null);

  async function run(followUpAnswers: string) {
    setLoading(true);
    setDecided(null); setActionId(null);
    try {
      const r = await api.runAgent("clinical-trial-matcher", {
        patient: `Patient/${patientId}`,
        followUpAnswers,
      });
      setResp(r);
      if (r?.requestId && r?.proposedAction) {
        try {
          const inv = await api.invocation(r.requestId);
          setActionId(inv.proposedActions?.[0]?.id || null);
        } catch { /* draft stays read-only */ }
      }
    } catch {
      setResp(null);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    setResp(null); setAnswers(""); setAnswered(false);
    run("");
    // eslint-disable-next-line react-hooks/exhaustive-deps
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

  const suggested = TRIAL_SUGGESTED_ANSWERS[patientId];

  if (loading && !resp) {
    return (
      <div className="flex items-center gap-2 rounded-lg border bg-card px-4 py-3 text-sm text-muted-foreground shadow-sm">
        <Loader2 className="h-4 w-4 animate-spin" /> Matching against the trial registry…
      </div>
    );
  }
  if (!resp || !isRealAi(resp)) {
    return (
      <div className="rounded-lg border bg-card px-4 py-3 text-sm text-muted-foreground shadow-sm">
        Trial matching isn't available for this patient.
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <ClinicalResult
        resp={resp}
        title="Clinical trial matches"
        severity={advisorySeverity("clinical-trial-matcher", resp)}
        actionBusy={busy}
        decided={decided}
        onSign={actionId ? sign : undefined}
        onDecline={actionId ? decline : undefined}
      />

      {/* The agent's follow-up questions — answering them re-runs the match */}
      {resp.followUpQuestions && resp.followUpQuestions.length > 0 && (
        <div className="rounded-lg border bg-card shadow-sm">
          <div className="flex items-center gap-2 border-b px-4 py-2.5 text-sm font-semibold">
            <MessageCircleQuestion className="h-4 w-4 text-nhs-600" /> The agent needs more information
            <span className="ml-auto inline-flex items-center gap-1 rounded-full bg-nhs-600 px-2.5 py-0.5 text-[11px] font-bold uppercase tracking-wide text-white"><Sparkles className="h-3 w-3" /> AI generated</span>
          </div>
          <div className="space-y-3 px-4 py-3">
            <div className="space-y-2">
              {resp.followUpQuestions.map((q, i) => (
                <div key={i} className="text-sm">
                  <span className="font-medium">{q.question}</span>
                  {q.why && <span className="text-muted-foreground"> — {q.why}</span>}
                </div>
              ))}
            </div>
            {answered ? (
              <p className="text-sm text-emerald-700">Answers applied — the matches above reflect the updated information.</p>
            ) : (
              <>
                <textarea
                  value={answers}
                  onChange={(e) => setAnswers(e.target.value)}
                  placeholder="Type the answers here and the agent will re-grade the matches…"
                  className="h-20 w-full rounded-md border bg-background px-3 py-2 text-sm"
                />
                <div className="flex flex-wrap items-center gap-2">
                  <button
                    onClick={async () => { if (!answers.trim()) return; setAnswered(true); await run(answers.trim()); }}
                    disabled={loading || !answers.trim()}
                    className="inline-flex items-center gap-1.5 rounded-md bg-nhs-600 px-3 py-2 text-sm font-medium text-white hover:bg-nhs-700 disabled:opacity-60"
                  >
                    {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <RefreshCw className="h-4 w-4" />}
                    Update matches
                  </button>
                  {suggested && (
                    <button
                      onClick={() => setAnswers(suggested)}
                      className="rounded-md border px-3 py-2 text-sm text-muted-foreground hover:bg-muted/50"
                      title="Fill in the demo answer"
                    >
                      Use example answer
                    </button>
                  )}
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
