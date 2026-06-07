// Simulated patient-facing portal — a phone app. On desktop it's drawn inside a
// fake phone outline with a patient selector above it (this is NOT a real mobile
// app; we're simulating the patient view). Read-only, friendly language.
// Two screens: "My plan" (Care Plan Navigator) and "Local support" (the social
// prescribing offer), each shown only when genuinely AI-generated.
import { useEffect, useState } from "react";
import { Loader2, HeartPulse, CheckCircle2, ThumbsUp, Phone, ClipboardList, HeartHandshake, MessageSquareText, FlaskConical } from "lucide-react";
import { api } from "@shared/api/client";
import type { AgentResponse } from "@shared/api/types";
import { isRealAi } from "@shared/lib/clinical";
import { scenarioInputs, TRIAGE_SCENARIOS } from "@/agents";
import { TriageChat } from "@/components/TriageChat";
import { LabResultsExplained } from "@/components/LabResultsExplained";

// Categorical 3-segment indicator (not a fake percentage) for the 3-state goal assessment.
function goalFill(onTrack?: boolean): { bar: string; fill: string; filled: number; label: string; text: string } {
  if (onTrack === true) return { bar: "bg-emerald-100", fill: "bg-emerald-500", filled: 3, label: "On track", text: "text-emerald-700" };
  if (onTrack === false) return { bar: "bg-rose-100", fill: "bg-rose-500", filled: 1, label: "Needs attention", text: "text-rose-700" };
  return { bar: "bg-amber-100", fill: "bg-amber-500", filled: 2, label: "Keep going", text: "text-amber-700" };
}

/** The warm message + low-pressure Yes/Call call-to-action, shared by both
 *  screens. A "Yes, please" genuinely lands in the record as a Communication. */
function MessageWithReply({ id, message }: { id: string; message: string }) {
  const [reply, setReply] = useState<"" | "yes" | "call">("");

  async function sayYes() {
    setReply("yes");
    // record the patient's reply in the real chart (best effort)
    api.sendCommunication(id, { category: "patient-reply", text: "Patient replied YES via the portal - please contact them to arrange." }).catch(() => {});
  }

  return (
    <>
      <div className="rounded-2xl bg-white p-4 shadow-sm">
        <p className="whitespace-pre-wrap text-[15px] leading-relaxed text-foreground">{message}</p>
      </div>
      {reply === "" ? (
        <div className="grid grid-cols-2 gap-2">
          <button onClick={sayYes} className="inline-flex items-center justify-center gap-1.5 rounded-full bg-nhs-600 px-3 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-nhs-700">
            <ThumbsUp className="h-4 w-4" /> Yes, please
          </button>
          <button onClick={() => setReply("call")} className="inline-flex items-center justify-center gap-1.5 rounded-full border border-nhs-300 bg-white px-3 py-2.5 text-sm font-semibold text-nhs-700 hover:bg-nhs-50">
            <Phone className="h-4 w-4" /> Call us
          </button>
        </div>
      ) : (
        <div className="rounded-2xl bg-emerald-50 p-4 text-center shadow-sm">
          <CheckCircle2 className="mx-auto mb-1 h-6 w-6 text-emerald-600" />
          <p className="text-sm font-medium text-emerald-800">
            {reply === "yes" ? "Thank you! Your reply has been passed to your care team — they'll be in touch." : "No problem — please call us on 01632 960 000 and we'll be happy to help."}
          </p>
        </div>
      )}
    </>
  );
}

/** My results — the lab explainer, patient view. */
function ResultsScreen({ id }: { id: string }) {
  const [resp, setResp] = useState<AgentResponse | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true); setResp(null);
    api.runAgent("lab-explainer", { patient: `Patient/${id}` })
      .then(setResp).catch(() => setResp(null)).finally(() => setLoading(false));
  }, [id]);

  if (loading) return <div className="flex items-center gap-2 pt-6 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" /> Explaining your results…</div>;
  if (!resp || !isRealAi(resp)) return <p className="pt-6 text-sm text-muted-foreground">Your results aren't ready to view just yet.</p>;

  return (
    <>
      <p className="px-1 text-xs text-muted-foreground">Your latest results, explained in plain language to help you prepare for your next appointment.</p>
      <LabResultsExplained resp={resp} compact />
    </>
  );
}

/** My plan — the Care Plan Navigator, patient view. */
function PlanScreen({ id }: { id: string }) {
  const [resp, setResp] = useState<AgentResponse | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true); setResp(null);
    api.runAgent("care-plan-navigator", { patient: `Patient/${id}` })
      .then(setResp).catch(() => setResp(null)).finally(() => setLoading(false));
  }, [id]);

  if (loading) return <div className="flex items-center gap-2 pt-6 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" /> Loading your plan…</div>;
  if (!resp || !isRealAi(resp)) return <p className="pt-6 text-sm text-muted-foreground">Your care plan isn't available right now.</p>;

  return (
    <>
      {resp.patientMessage && <MessageWithReply id={id} message={resp.patientMessage} />}
      {resp.goals && resp.goals.length > 0 && (
        <div>
          <div className="mb-1.5 px-1 text-xs font-medium uppercase tracking-wide text-slate-500">How you're doing</div>
          <div className="space-y-2.5">
            {resp.goals.map((g, i) => {
              const t = goalFill(g.onTrack);
              return (
                <div key={i} className="rounded-2xl bg-white p-3 shadow-sm">
                  <div className="flex items-center justify-between gap-2 text-sm">
                    <span className="font-medium text-foreground">{g.goal}</span>
                    <span className={`shrink-0 text-[11px] font-medium ${t.text}`}>{t.label}</span>
                  </div>
                  <div className="mt-1.5 flex gap-1">
                    {[0, 1, 2].map((seg) => <div key={seg} className={`h-2 flex-1 rounded-full ${seg < t.filled ? t.fill : t.bar}`} />)}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </>
  );
}

/** Local support — the social prescribing offer, patient view. */
function SupportScreen({ id }: { id: string }) {
  const [resp, setResp] = useState<AgentResponse | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true); setResp(null);
    api.runAgent("sdoh-referral", { patient: `Patient/${id}`, ...scenarioInputs(`Patient/${id}`, "sdoh-referral") })
      .then(setResp).catch(() => setResp(null)).finally(() => setLoading(false));
  }, [id]);

  if (loading) return <div className="flex items-center gap-2 pt-6 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" /> Finding support near you…</div>;
  if (!resp || !isRealAi(resp)) return <p className="pt-6 text-sm text-muted-foreground">Nothing to show here right now.</p>;

  const referrals = (resp.referrals ?? []).slice().sort((a, b) => Number(!!b.bestMatch) - Number(!!a.bestMatch));

  return (
    <>
      {resp.patientMessage && <MessageWithReply id={id} message={resp.patientMessage} />}
      {referrals.length > 0 && (
        <div>
          <div className="mb-1.5 px-1 text-xs font-medium uppercase tracking-wide text-slate-500">Support near you</div>
          <div className="space-y-2.5">
            {referrals.map((r, i) => (
              <div key={i} className="rounded-2xl bg-white p-3 shadow-sm">
                <div className="flex items-center justify-between gap-2 text-sm">
                  <span className="font-medium text-foreground">{r.name || r.resource}</span>
                  {r.bestMatch && <span className="shrink-0 rounded-full bg-nhs-100 px-2 py-0.5 text-[10px] font-semibold text-nhs-700">Top pick</span>}
                </div>
                {r.offers && <p className="mt-1 text-[13px] leading-snug text-muted-foreground">{r.offers}</p>}
                {r.contact && <p className="mt-1 text-[13px] font-medium text-nhs-700">{r.contact}</p>}
              </div>
            ))}
          </div>
        </div>
      )}
    </>
  );
}

function PhoneScreen({ id, name }: { id: string; name: string }) {
  const [tab, setTab] = useState<"plan" | "results" | "support" | "symptoms">("plan");
  // the triage chat is available where a prepared conversation exists for this patient
  const triage = TRIAGE_SCENARIOS.find((s) => s.patient === `Patient/${id}`);

  useEffect(() => { setTab("plan"); }, [id]);

  const firstName = name.replace(/^(Mr|Ms|Mrs|Miss|Dr)\s+/i, "").split(" ")[0] || name;
  const subtitle = tab === "symptoms" ? "Tell us how you're feeling" : tab === "results" ? "Your results, explained simply" : "A message from your care team";

  return (
    <div className="flex h-full flex-col bg-slate-50">
      {/* App bar */}
      <div className="shrink-0 bg-nhs-600 px-4 pb-3 pt-2 text-white">
        <div className="flex items-center gap-1.5 text-[11px] text-white/70"><HeartPulse className="h-3.5 w-3.5" /> Cedar Valley Health</div>
        <div className="mt-0.5 text-lg font-semibold leading-tight">Hi {firstName}</div>
        <div className="text-xs text-white/80">{subtitle}</div>
      </div>

      <div className="min-h-0 flex-1 space-y-4 overflow-y-auto px-4 py-4">
        {tab === "plan" ? <PlanScreen id={id} />
          : tab === "results" ? <ResultsScreen id={id} />
          : tab === "support" ? <SupportScreen id={id} />
          : triage ? <TriageChat patientId={id} complaint={triage.complaint} mode="patient" /> : null}
        <div className="flex items-center justify-center gap-1.5 pt-2 text-[11px] text-muted-foreground">
          <HeartPulse className="h-3.5 w-3.5" /> Your care team is here to help
        </div>
      </div>

      {/* Bottom tab bar */}
      <div className={`grid shrink-0 ${triage ? "grid-cols-4" : "grid-cols-3"} border-t bg-white`}>
        <button onClick={() => setTab("plan")} className={`flex flex-col items-center gap-0.5 py-2 text-[11px] font-medium ${tab === "plan" ? "text-nhs-700" : "text-slate-400"}`}>
          <ClipboardList className="h-5 w-5" /> My plan
        </button>
        <button onClick={() => setTab("results")} className={`flex flex-col items-center gap-0.5 py-2 text-[11px] font-medium ${tab === "results" ? "text-nhs-700" : "text-slate-400"}`}>
          <FlaskConical className="h-5 w-5" /> Results
        </button>
        <button onClick={() => setTab("support")} className={`flex flex-col items-center gap-0.5 py-2 text-[11px] font-medium ${tab === "support" ? "text-nhs-700" : "text-slate-400"}`}>
          <HeartHandshake className="h-5 w-5" /> Support
        </button>
        {triage && (
          <button onClick={() => setTab("symptoms")} className={`flex flex-col items-center gap-0.5 py-2 text-[11px] font-medium ${tab === "symptoms" ? "text-nhs-700" : "text-slate-400"}`}>
            <MessageSquareText className="h-5 w-5" /> Symptoms
          </button>
        )}
      </div>
    </div>
  );
}

export function PatientPortal() {
  const [patients, setPatients] = useState<{ id: string; name: string }[]>([]);
  const [active, setActive] = useState("");

  useEffect(() => {
    // every portal demo patient has BOTH a cached care plan and a cached
    // social-prescribing offer, so no searching is needed to find demo data
    api.carePlanDemoPatients().then((r) => {
      const ps = r.patients || [];
      setPatients(ps);
      if (ps.length) setActive(ps[0].id);
    });
  }, []);

  const activePatient = patients.find((p) => p.id === active);

  return (
    <div className="flex min-h-screen flex-col items-center bg-gradient-to-b from-slate-100 to-slate-200 px-4 py-8">
      <div className="mb-1 text-sm font-semibold text-slate-700">Patient portal — preview</div>
      <p className="mb-4 text-xs text-slate-500">Simulated patient phone app. Choose a demo patient to preview their view.</p>

      {/* Patient selector (sits above the phone) */}
      <div className="mb-5 flex items-center gap-2">
        <label className="text-sm text-slate-600">Patient:</label>
        <select value={active} onChange={(e) => setActive(e.target.value)} className="h-9 rounded-md border border-slate-300 bg-white px-3 text-sm">
          {patients.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
        </select>
      </div>

      {/* Fake phone outline */}
      <div className="relative h-[760px] w-[380px] rounded-[2.75rem] border-[10px] border-slate-900 bg-slate-900 shadow-2xl">
        {/* notch */}
        <div className="absolute left-1/2 top-0 z-10 h-6 w-36 -translate-x-1/2 rounded-b-2xl bg-slate-900" />
        <div className="h-full w-full overflow-hidden rounded-[2.1rem] bg-white">
          {active && activePatient && <PhoneScreen id={active} name={activePatient.name} />}
        </div>
      </div>
    </div>
  );
}
