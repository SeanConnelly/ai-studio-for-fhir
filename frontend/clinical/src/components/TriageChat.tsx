// The conversational triage experience. Phase 1: the agent designs guided
// questions for THIS patient + complaint (red-flag safety screen first); the
// patient answers by tapping options in a friendly chat. Phase 2: the agent
// writes the clinician handoff from the actual answers - colour-coded urgency,
// findings that QUOTE the answers, observations mapped to FHIR, suggested
// tasks, and a signable draft ServiceRequest. The finished conversation is
// saved to the real FHIR repository as a QuestionnaireResponse.
// mode="clinician" shows the full handoff; mode="patient" (phone portal) shows
// only the warm patient-facing ending.
import { useEffect, useRef, useState } from "react";
import {
  Loader2, Sparkles, Bot, CheckCircle2, ShieldAlert, ListChecks, FileText, Stethoscope,
} from "lucide-react";
import { api } from "@shared/api/client";
import type { AgentResponse } from "@shared/api/types";
import { isRealAi } from "@shared/lib/clinical";
import { serializeAnswers } from "@shared/lib/triage-serialize.mjs";
import { DraftActionCard } from "@shared/components/clinical/DraftActionCard";

interface QA { question: string; answer: string }

function urgencyTone(u?: string): { banner: string; chip: string; label: string } {
  const v = (u || "").toLowerCase();
  if (v === "red") return { banner: "border-rose-300 bg-rose-50/70", chip: "bg-rose-600 text-white", label: "Emergency care now" };
  if (v === "yellow") return { banner: "border-amber-300 bg-amber-50/70", chip: "bg-amber-500 text-white", label: "Follow-up within 48 hours" };
  return { banner: "border-emerald-300 bg-emerald-50/70", chip: "bg-emerald-600 text-white", label: "Routine appointment" };
}

export function TriageChat({ patientId, complaint, mode }: { patientId: string; complaint: string; mode: "clinician" | "patient" }) {
  const [phase1, setPhase1] = useState<AgentResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [qa, setQa] = useState<QA[]>([]);
  const [step, setStep] = useState(0);
  const [handoff, setHandoff] = useState<AgentResponse | null>(null);
  const [handoffLoading, setHandoffLoading] = useState(false);
  const [savedRef, setSavedRef] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [actionId, setActionId] = useState<string | null>(null);
  const [decided, setDecided] = useState<{ decision: string; reviewer?: string; committedRef?: string } | null>(null);
  const endRef = useRef<HTMLDivElement>(null);

  // Phase 1 — the agent designs the questions for this patient + complaint.
  useEffect(() => {
    setPhase1(null); setQa([]); setStep(0); setHandoff(null); setSavedRef(null); setDecided(null); setActionId(null);
    setLoading(true);
    api.runAgent("conversational-triage", { patient: `Patient/${patientId}`, chiefComplaint: complaint, answers: "" })
      .then(setPhase1).catch(() => setPhase1(null)).finally(() => setLoading(false));
  }, [patientId, complaint]);

  useEffect(() => { endRef.current?.scrollIntoView({ behavior: "smooth", block: "nearest" }); }, [qa, handoff, handoffLoading]);

  const questions = phase1?.questions ?? [];

  async function answer(option: string) {
    const q = questions[step];
    const nextQa = [...qa, { question: q.text, answer: option }];
    setQa(nextQa);
    if (step + 1 < questions.length) {
      setStep(step + 1);
      return;
    }
    // Conversation complete — phase 2 (handoff) + persist the session to FHIR.
    setHandoffLoading(true);
    try {
      const [h, saved] = await Promise.all([
        api.runAgent("conversational-triage", {
          patient: `Patient/${patientId}`,
          chiefComplaint: complaint,
          answers: serializeAnswers(nextQa),
        }),
        api.saveTriageSession(patientId, { complaint, items: nextQa }).catch(() => null),
      ]);
      setHandoff(h);
      if (saved?.ref) setSavedRef(saved.ref);
      if (h?.requestId && h?.proposedAction) {
        try {
          const inv = await api.invocation(h.requestId);
          setActionId(inv.proposedActions?.[0]?.id || null);
        } catch { /* draft stays read-only */ }
      }
    } finally {
      setHandoffLoading(false);
    }
  }

  async function sign() {
    if (!handoff?.requestId || !actionId) return;
    setBusy(true);
    try {
      const r = await api.approveAction(handoff.requestId, actionId, { reviewer: "Demo Clinician" });
      setDecided({ decision: "approved", reviewer: "Demo Clinician", committedRef: r.committedResourceRef });
    } finally { setBusy(false); }
  }
  async function decline() {
    if (!handoff?.requestId || !actionId) return;
    setBusy(true);
    try {
      await api.rejectAction(handoff.requestId, actionId, { reviewer: "Demo Clinician" });
      setDecided({ decision: "rejected", reviewer: "Demo Clinician" });
    } finally { setBusy(false); }
  }

  if (loading) {
    return (
      <div className="flex items-center gap-2 rounded-lg border bg-card px-4 py-3 text-sm text-muted-foreground shadow-sm">
        <Loader2 className="h-4 w-4 animate-spin" /> Preparing the triage assistant…
      </div>
    );
  }
  if (!phase1 || !isRealAi(phase1) || questions.length === 0) {
    return (
      <div className="rounded-lg border bg-card px-4 py-3 text-sm text-muted-foreground shadow-sm">
        The triage assistant isn't available for this scenario. (Prepared scenarios replay key-free; new ones need an API key.)
      </div>
    );
  }

  const realHandoff = handoff && isRealAi(handoff) ? handoff : null;
  const tone = urgencyTone(realHandoff?.urgency);

  return (
    <div className="space-y-4">
      {/* The conversation */}
      <div className={mode === "patient" ? "space-y-3" : "rounded-lg border bg-card p-4 shadow-sm"}>
        <div className="space-y-3">
          {/* greeting */}
          <div className="flex items-start gap-2.5">
            <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-nhs-600 text-white"><Bot className="h-4 w-4" /></span>
            <div className="max-w-[85%] rounded-2xl rounded-tl-sm bg-nhs-50 px-3.5 py-2.5 text-sm leading-relaxed">{phase1.greeting}</div>
          </div>
          {/* answered turns */}
          {qa.map((t, i) => (
            <div key={i} className="space-y-3">
              <div className="flex items-start gap-2.5">
                <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-nhs-600 text-white"><Bot className="h-4 w-4" /></span>
                <div className="max-w-[85%] rounded-2xl rounded-tl-sm bg-nhs-50 px-3.5 py-2.5 text-sm leading-relaxed">{t.question}</div>
              </div>
              <div className="flex justify-end">
                <div className="max-w-[75%] rounded-2xl rounded-tr-sm bg-nhs-600 px-3.5 py-2.5 text-sm text-white">{t.answer}</div>
              </div>
            </div>
          ))}
          {/* current question + tappable options */}
          {!handoff && !handoffLoading && step < questions.length && (
            <div className="space-y-3">
              {qa.length === step && (
                <div className="flex items-start gap-2.5">
                  <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-nhs-600 text-white"><Bot className="h-4 w-4" /></span>
                  <div className="max-w-[85%] rounded-2xl rounded-tl-sm bg-nhs-50 px-3.5 py-2.5 text-sm leading-relaxed">{questions[step].text}</div>
                </div>
              )}
              <div className="flex flex-wrap justify-end gap-2">
                {questions[step].options.map((o) => (
                  <button key={o} onClick={() => answer(o)} className="rounded-full border border-nhs-300 bg-white px-3.5 py-2 text-sm font-medium text-nhs-700 hover:bg-nhs-50">
                    {o}
                  </button>
                ))}
              </div>
            </div>
          )}
          {handoffLoading && (
            <div className="flex items-center gap-2 pl-9 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" /> Writing the summary for your care team…</div>
          )}
          {/* the patient-facing ending */}
          {realHandoff?.patientMessage && (
            <div className="flex items-start gap-2.5">
              <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-nhs-600 text-white"><Bot className="h-4 w-4" /></span>
              <div className="max-w-[85%] whitespace-pre-wrap rounded-2xl rounded-tl-sm bg-nhs-50 px-3.5 py-2.5 text-sm leading-relaxed">{realHandoff.patientMessage}</div>
            </div>
          )}
          {savedRef && (
            <p className="pl-9 text-[11px] text-muted-foreground">
              <CheckCircle2 className="mr-1 inline h-3.5 w-3.5 text-emerald-600" />
              Your answers were saved to your record{mode === "clinician" ? <> as <span className="font-mono">{savedRef}</span></> : null}.
            </p>
          )}
          {phase1.safetyNote && !handoff && (
            <p className="pl-9 text-[11px] text-amber-700">{phase1.safetyNote}</p>
          )}
        </div>
        <div ref={endRef} />
      </div>

      {/* The clinician handoff */}
      {mode === "clinician" && realHandoff && (
        <div className="rounded-lg border bg-card shadow-sm">
          <div className="flex flex-wrap items-center gap-2 border-b px-4 py-2.5 text-sm font-semibold">
            <Stethoscope className="h-4 w-4 text-nhs-600" /> Clinician handoff
            <span className="ml-auto inline-flex items-center gap-1 rounded-full bg-nhs-600 px-2.5 py-0.5 text-[11px] font-bold uppercase tracking-wide text-white"><Sparkles className="h-3 w-3" /> AI generated</span>
          </div>
          <div className="space-y-4 px-4 py-4">
            <div className={`rounded-lg border p-3.5 ${tone.banner}`}>
              <div className="flex flex-wrap items-center gap-2.5">
                <span className={`rounded-full px-3 py-1 text-sm font-bold ${tone.chip}`}>{realHandoff.urgencyLabel || tone.label}</span>
                {realHandoff.redFlags && realHandoff.redFlags.length > 0 && (
                  <span className="inline-flex items-center gap-1 text-sm font-medium text-rose-700"><ShieldAlert className="h-4 w-4" /> {realHandoff.redFlags.join("; ")}</span>
                )}
              </div>
              {realHandoff.summary && <p className="mt-2 text-sm leading-relaxed">{realHandoff.summary}</p>}
            </div>

            {realHandoff.keyFindings && realHandoff.keyFindings.length > 0 && (
              <div>
                <div className="mb-1.5 text-sm font-semibold">Key findings from the conversation</div>
                <div className="space-y-1.5">
                  {realHandoff.keyFindings.map((f, i) => (
                    <div key={i} className="text-sm">
                      <span className="font-medium">{f.finding}</span>
                      {f.source && <span className="text-muted-foreground"> — patient said: <span className="italic">&ldquo;{f.source}&rdquo;</span></span>}
                    </div>
                  ))}
                </div>
              </div>
            )}

            {realHandoff.mappedObservations && realHandoff.mappedObservations.length > 0 && (
              <div>
                <div className="mb-1.5 flex items-center gap-1.5 text-sm font-semibold"><FileText className="h-4 w-4 text-nhs-600" /> Mapped to the record</div>
                <ul className="space-y-1 text-sm text-muted-foreground">
                  {realHandoff.mappedObservations.map((m, i) => <li key={i} className="flex gap-2"><span className="text-nhs-600">•</span>{m}</li>)}
                </ul>
                {savedRef && <p className="mt-1 text-xs text-muted-foreground">Conversation stored as {savedRef} in the FHIR repository.</p>}
              </div>
            )}

            {realHandoff.suggestedTasks && realHandoff.suggestedTasks.length > 0 && (
              <div>
                <div className="mb-1.5 flex items-center gap-1.5 text-sm font-semibold"><ListChecks className="h-4 w-4 text-nhs-600" /> Suggested actions</div>
                <div className="space-y-1.5">
                  {realHandoff.suggestedTasks.map((t, i) => (
                    <div key={i} className="rounded-md border p-2.5 text-sm">
                      <span className="font-medium">{t.task}</span>
                      {t.rationale && <span className="text-muted-foreground"> — {t.rationale}</span>}
                    </div>
                  ))}
                </div>
              </div>
            )}

            {realHandoff.proposedAction?.resourceType && (
              <DraftActionCard
                resourceType={realHandoff.proposedAction.resourceType}
                resource={realHandoff.proposedAction.resource}
                busy={busy}
                decided={decided}
                onSign={actionId ? sign : undefined}
                onDecline={actionId ? decline : undefined}
              />
            )}
            <p className="text-[11px] text-muted-foreground">AI triage support — a clinician reviews and decides; nothing is booked automatically.</p>
          </div>
        </div>
      )}
    </div>
  );
}
