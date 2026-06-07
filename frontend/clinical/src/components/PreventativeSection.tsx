// In-chart preventative care: what this patient is due/overdue for (diabetes
// review, breast screening, flu vaccination), evaluated from their record. Each
// overdue item offers an AI-drafted invitation letter to book the appointment —
// a draft only, nothing is sent automatically.
import { useState } from "react";
import { ShieldCheck, CheckCircle2, AlertTriangle, Mail, Loader2, Sparkles, X, Send } from "lucide-react";
import { api } from "@shared/api/client";
import type { PreventativeItem, LetterResult } from "@shared/api/types";

export function PreventativeSection({ patientId, items }: { patientId: string; items: PreventativeItem[] }) {
  const [busy, setBusy] = useState<string | null>(null);
  const [letters, setLetters] = useState<Record<string, LetterResult>>({});
  const [sent, setSent] = useState<Record<string, boolean>>({});

  async function draft(area: string) {
    setBusy(area);
    try {
      const l = await api.preventativeLetter(patientId, area);
      setLetters((p) => ({ ...p, [area]: l }));
    } finally {
      setBusy(null);
    }
  }

  // sending records the letter in the REAL chart as a FHIR Communication
  async function send(area: string) {
    const letter = letters[area]?.letter;
    if (!letter) return;
    try {
      await api.sendCommunication(patientId, { category: "invitation-letter", text: letter });
      setSent((p) => ({ ...p, [area]: true }));
    } catch { /* leave the button active */ }
  }

  return (
    <div className="rounded-lg border bg-card shadow-sm">
      <div className="flex items-center gap-2 border-b px-4 py-2.5 text-sm font-semibold text-foreground">
        <ShieldCheck className="h-4 w-4 text-nhs-600" />
        Preventative care
        {items.length > 0 && <span className="ml-auto rounded-full bg-amber-100 px-2 py-0.5 text-[11px] font-medium text-amber-800">{items.length} due</span>}
      </div>
      <div className="space-y-3 px-4 py-3">
        {items.length === 0 ? (
          <p className="flex items-center gap-2 text-sm text-muted-foreground"><CheckCircle2 className="h-4 w-4 text-emerald-600" /> Up to date — nothing due.</p>
        ) : (
          items.map((it) => (
            <div key={it.area} className="rounded-md border p-3">
              <div className="flex items-start gap-2">
                <AlertTriangle className={"mt-0.5 h-4 w-4 shrink-0 " + (it.severity === "warning" ? "text-amber-500" : "text-sky-500")} />
                <div className="min-w-0 flex-1">
                  <div className="text-sm font-medium text-foreground">{it.title}</div>
                  <div className="text-sm text-muted-foreground">{it.detail}</div>
                </div>
                {!letters[it.area] && (
                  <button
                    onClick={() => draft(it.area)}
                    disabled={busy === it.area}
                    className="inline-flex shrink-0 items-center gap-1.5 rounded-md border border-nhs-300 bg-nhs-50 px-2.5 py-1.5 text-xs font-medium text-nhs-800 hover:bg-nhs-100 disabled:opacity-60"
                  >
                    {busy === it.area ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Mail className="h-3.5 w-3.5" />}
                    {busy === it.area ? "Drafting…" : "Draft invitation letter"}
                  </button>
                )}
              </div>

              {letters[it.area] && (() => {
                const isAi = !(letters[it.area].source || "").includes("deterministic");
                return (
                  <div className="mt-3 rounded-md border bg-muted/20 p-3">
                    <div className="mb-1.5 flex items-center gap-2 text-xs font-medium">
                      {isAi ? (
                        <span className="inline-flex items-center gap-1 rounded-full bg-nhs-600 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-white"><Sparkles className="h-3 w-3" /> AI draft</span>
                      ) : (
                        <span className="inline-flex items-center gap-1 rounded-full bg-slate-200 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-slate-700">Template</span>
                      )}
                      Invitation letter
                      <button onClick={() => setLetters((p) => { const n = { ...p }; delete n[it.area]; return n; })} className="ml-auto text-muted-foreground hover:text-foreground"><X className="h-3.5 w-3.5" /></button>
                    </div>
                    <p className="whitespace-pre-wrap text-sm leading-relaxed text-foreground">{letters[it.area].letter}</p>
                    <p className="mt-2 text-[11px] text-muted-foreground">{isAi ? "AI-generated draft" : "Template draft"} — review and edit before sending. Nothing is sent automatically.</p>
                    <div className="mt-2">
                      {sent[it.area] ? (
                        <span className="inline-flex items-center gap-1.5 text-sm font-medium text-emerald-700"><CheckCircle2 className="h-4 w-4" /> Letter recorded in the chart</span>
                      ) : (
                        <button
                          onClick={() => send(it.area)}
                          className="inline-flex items-center gap-1.5 rounded-md bg-nhs-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-nhs-700"
                        >
                          <Send className="h-3.5 w-3.5" /> Send letter
                        </button>
                      )}
                    </div>
                  </div>
                );
              })()}
            </div>
          ))
        )}
      </div>
    </div>
  );
}
