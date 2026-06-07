// Triage — the conversational triage assistant, staff view. An intake card
// (patient + presenting complaint in the caller's words + optional notes)
// starts a guided conversation the AI designs for that patient; the answers
// become a colour-coded clinician handoff, saved to the record.
// Eight prepared scenarios (and every answer path through them) replay real AI
// key-free; edited complaints/notes run live when an API key is configured.
import { useEffect, useMemo, useState } from "react";
import { MessageSquareText, Dices, RotateCcw, Phone, Sparkles, KeyRound } from "lucide-react";
import { api } from "@shared/api/client";
import { TRIAGE_SCENARIOS } from "@/agents";
import { TriageChat } from "@/components/TriageChat";

export function Triage() {
  const [scenario, setScenario] = useState(0);
  const [names, setNames] = useState<Record<string, string>>({});
  const [complaint, setComplaint] = useState(TRIAGE_SCENARIOS[0].complaint);
  const [notes, setNotes] = useState("");
  // the conversation in progress (null = still on the intake card)
  const [active, setActive] = useState<{ pid: string; complaint: string; session: number } | null>(null);

  useEffect(() => {
    TRIAGE_SCENARIOS.forEach((s) => {
      const id = s.patient.split("/")[1];
      api.everything(s.patient).then((b) => setNames((n) => ({ ...n, [id]: b.patient || id }))).catch(() => {});
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const sel = TRIAGE_SCENARIOS[scenario];
  const pid = sel.patient.split("/")[1];
  // a conversation is "prepared" (cache-backed) only with the pinned complaint and no notes
  const prepared = useMemo(() => complaint === sel.complaint && notes.trim() === "", [complaint, notes, sel]);

  function pick(i: number) {
    setScenario(i);
    setComplaint(TRIAGE_SCENARIOS[i].complaint);
    setNotes("");
    setActive(null);
  }

  function start() {
    const full = notes.trim() ? `${complaint} (Notes from intake: ${notes.trim()})` : complaint;
    setActive({ pid, complaint: full, session: (active?.session ?? 0) + 1 });
  }

  function surprise() {
    const i = Math.floor(Math.random() * TRIAGE_SCENARIOS.length);
    setScenario(i);
    setComplaint(TRIAGE_SCENARIOS[i].complaint);
    setNotes("");
    const p = TRIAGE_SCENARIOS[i].patient.split("/")[1];
    setActive({ pid: p, complaint: TRIAGE_SCENARIOS[i].complaint, session: (active?.session ?? 0) + 1 });
  }

  return (
    <div className="space-y-5">
      <div>
        <h1 className="flex items-center gap-2 text-xl font-semibold"><MessageSquareText className="h-5 w-5 text-nhs-600" /> Triage assistant</h1>
        <p className="text-sm text-muted-foreground">
          Take a call: pick the patient, capture the complaint in their words, and the AI designs a guided
          conversation — red-flag screen first. The answers become a colour-coded handoff, saved to the record.
        </p>
      </div>

      {/* Intake card */}
      <div className="rounded-xl border bg-card p-4 shadow-sm">
        <div className="mb-3 flex items-center gap-2 text-sm font-semibold"><Phone className="h-4 w-4 text-nhs-600" /> Intake</div>
        <div className="grid gap-3 md:grid-cols-2">
          <div>
            <label className="mb-1 block text-xs font-medium uppercase tracking-wide text-muted-foreground">Patient calling</label>
            <select value={scenario} onChange={(e) => pick(Number(e.target.value))} className="h-10 w-full rounded-md border bg-background px-3 text-sm">
              {TRIAGE_SCENARIOS.map((s, i) => {
                const id = s.patient.split("/")[1];
                return <option key={i} value={i}>{names[id] || id} — {s.label}</option>;
              })}
            </select>
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium uppercase tracking-wide text-muted-foreground">Presenting complaint (their words)</label>
            <input value={complaint} onChange={(e) => { setComplaint(e.target.value); setActive(null); }} className="h-10 w-full rounded-md border bg-background px-3 text-sm" />
          </div>
        </div>
        <div className="mt-3">
          <label className="mb-1 block text-xs font-medium uppercase tracking-wide text-muted-foreground">Anything else the assistant should know? (optional)</label>
          <input value={notes} onChange={(e) => { setNotes(e.target.value); setActive(null); }} placeholder="e.g. temperature 38.4 taken at home, sounds short of breath on the phone…" className="h-10 w-full rounded-md border bg-background px-3 text-sm" />
        </div>
        <div className="mt-3 flex flex-wrap items-center gap-2">
          <button onClick={start} className="inline-flex items-center gap-1.5 rounded-md bg-nhs-600 px-4 py-2 text-sm font-semibold text-white hover:bg-nhs-700">
            <MessageSquareText className="h-4 w-4" /> Start conversation
          </button>
          <button onClick={surprise} title="Pick a prepared scenario at random and start" className="inline-flex items-center gap-1.5 rounded-md border border-nhs-300 bg-white px-4 py-2 text-sm font-semibold text-nhs-700 hover:bg-nhs-50">
            <Dices className="h-4 w-4" /> Surprise me
          </button>
          {active && (
            <button onClick={() => setActive({ ...active, session: active.session + 1 })} className="inline-flex items-center gap-1.5 rounded-md border px-3 py-2 text-sm font-medium text-muted-foreground hover:bg-muted/50" title="Start this conversation again (try a different answer path)">
              <RotateCcw className="h-4 w-4" /> Restart
            </button>
          )}
          <span className={`ml-auto inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-[11px] font-medium ${prepared ? "bg-nhs-50 text-nhs-700" : "bg-amber-50 text-amber-800"}`}>
            {prepared ? <><Sparkles className="h-3 w-3" /> Prepared scenario — replays instantly, any answer path</> : <><KeyRound className="h-3 w-3" /> Custom intake — runs live (needs an API key)</>}
          </span>
        </div>
      </div>

      {active && (
        <TriageChat key={`${active.pid}-${active.session}-${active.complaint}`} patientId={active.pid} complaint={active.complaint} mode="clinician" />
      )}
    </div>
  );
}
