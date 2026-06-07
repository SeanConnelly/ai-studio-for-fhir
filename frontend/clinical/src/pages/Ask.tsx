// Ask — the natural-language data explorer (the NL→FHIR query agent). A big
// question box with prepared example chips, and a split view: how the AI read
// the question (resources, extracted filters, confidence) and the generated,
// validated read-only SQL on one side; the live result table on the other.
// Ambiguous questions get a clarifying question back instead of a guess.
import { useRef, useState } from "react";
import {
  Search, Loader2, Sparkles, ShieldCheck, Copy, Check, Download, Clock3,
  MessageCircleQuestion, History, ChevronRight, Dices,
} from "lucide-react";
import { api } from "@shared/api/client";
import type { AgentResponse } from "@shared/api/types";
import { isRealAi } from "@shared/lib/clinical";
import { Button } from "@shared/components/ui/button";
import { CodeBlock } from "@shared/components/ui/code-block";
// The "Surprise me" catalogue: 20 question types x ~144 parameterised variants,
// every one pre-built into the cache as a real Grok translation (see
// scripts/build-ask-cache.mjs), so a random question always answers key-free.
import { randomQuestion } from "@shared/lib/ask-questions.mjs";
import askCatalogue from "../../../../seed/demo-inputs/ask-questions.json";

const EXAMPLES: { label: string; q: string }[] = [
  { label: "Cohort", q: "Show diabetic patients with HbA1c above 9 in the last 6 months" },
  { label: "Medications", q: "Which patients with hypertension are taking two or more different blood pressure medicines?" },
  { label: "Complex", q: "Heart failure patients over 65 who attended the emergency department in the last 60 days" },
  { label: "Trend", q: "Which diabetic patients' latest HbA1c is higher than their first recorded HbA1c?" },
  { label: "Ambiguous", q: "Which patients are getting worse?" },
];

function confidenceTone(c?: number): string {
  if (typeof c !== "number") return "bg-slate-100 text-slate-600";
  if (c >= 75) return "bg-emerald-100 text-emerald-800";
  if (c >= 40) return "bg-amber-100 text-amber-800";
  return "bg-rose-100 text-rose-800";
}

function toCsv(rows: Record<string, unknown>[]): string {
  if (!rows.length) return "";
  const cols = Object.keys(rows[0]);
  const esc = (v: unknown) => {
    const s = String(v ?? "");
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  return [cols.join(","), ...rows.map((r) => cols.map((c) => esc(r[c])).join(","))].join("\n");
}

export function Ask() {
  const [q, setQ] = useState(EXAMPLES[0].q);
  const [resp, setResp] = useState<AgentResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [elapsed, setElapsed] = useState<number | null>(null);
  const [history, setHistory] = useState<string[]>([]);
  const [copied, setCopied] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  async function run(question: string) {
    setQ(question);
    setLoading(true);
    setResp(null);
    setCopied(false);
    const t0 = performance.now();
    try {
      const r = await api.runAgent("nl-to-fhir-query", { question });
      setResp(r);
      setElapsed(Math.round(performance.now() - t0));
      setHistory((h) => [question, ...h.filter((x) => x !== question)].slice(0, 6));
    } catch (e) {
      setResp({ status: "error", summary: (e as Error).message } as AgentResponse);
      setElapsed(null);
    } finally {
      setLoading(false);
    }
  }

  function copySql() {
    if (!resp?.generatedQuery) return;
    navigator.clipboard.writeText(resp.generatedQuery).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  }

  function exportCsv() {
    const rows = resp?.resultPreview ?? [];
    if (!rows.length) return;
    const blob = new Blob([toCsv(rows as Record<string, unknown>[])], { type: "text/csv" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "cohort.csv";
    a.click();
    URL.revokeObjectURL(a.href);
  }

  const rows = (resp?.resultPreview ?? []) as Record<string, unknown>[];
  const real = resp ? isRealAi(resp) : false;
  const clarifying = real && !!resp?.clarification;

  return (
    <div className="space-y-5">
      <div>
        <h1 className="flex items-center gap-2 text-xl font-semibold"><Search className="h-5 w-5 text-nhs-600" /> Ask your data</h1>
        <p className="text-sm text-muted-foreground">
          Ask anything about the patient population in plain English. The AI translates it into a safe, read-only
          query, the platform validates and runs it live, and you see exactly how it was answered.
        </p>
      </div>

      {/* The question box */}
      <form
        className="rounded-xl border bg-card p-4 shadow-sm"
        onSubmit={(e) => { e.preventDefault(); run(q); }}
      >
        <div className="flex items-center gap-3">
          <input
            ref={inputRef}
            value={q}
            onChange={(e) => setQ(e.target.value)}
            className="h-11 flex-1 rounded-lg border bg-background px-4 text-[15px] outline-none focus:ring-2 focus:ring-nhs-300"
            placeholder="Ask anything about your patient population…"
          />
          <Button type="submit" disabled={loading || !q.trim()} className="h-11 px-5">
            {loading ? <Loader2 className="mr-1.5 h-4 w-4 animate-spin" /> : <Sparkles className="mr-1.5 h-4 w-4" />}
            {loading ? "Translating…" : "Ask"}
          </Button>
          <button
            type="button"
            disabled={loading}
            onClick={() => run(randomQuestion(askCatalogue))}
            title="Ask one of 144 prepared questions at random"
            className="inline-flex h-11 items-center gap-1.5 rounded-lg border border-nhs-300 bg-white px-4 text-sm font-semibold text-nhs-700 hover:bg-nhs-50 disabled:opacity-60"
          >
            <Dices className="h-4 w-4" /> Surprise me
          </button>
        </div>
        <div className="mt-3 flex flex-wrap items-center gap-1.5">
          <span className="text-xs text-muted-foreground">Try:</span>
          {EXAMPLES.map((ex) => (
            <button
              key={ex.label}
              type="button"
              onClick={() => run(ex.q)}
              className="rounded-full border border-nhs-200 bg-nhs-50 px-2.5 py-1 text-xs font-medium text-nhs-700 hover:bg-nhs-100"
              title={ex.q}
            >
              {ex.label}
            </button>
          ))}
        </div>
        {history.length > 1 && (
          <div className="mt-2 flex flex-wrap items-center gap-1.5 text-xs text-muted-foreground">
            <History className="h-3.5 w-3.5" />
            {history.slice(1).map((h) => (
              <button key={h} type="button" onClick={() => run(h)} className="max-w-[260px] truncate rounded-full border px-2.5 py-1 hover:bg-muted/50" title={h}>
                {h}
              </button>
            ))}
          </div>
        )}
      </form>

      {resp && !real && (
        <p className="rounded-lg border bg-card px-4 py-3 text-sm text-muted-foreground shadow-sm">
          That one isn't in the prepared demo set — novel questions run live when an API key is configured.
          Try the example chips above; each replays a real AI translation instantly.
        </p>
      )}

      {/* Clarifying question — the agent refuses to guess */}
      {clarifying && (
        <div className="rounded-xl border border-amber-300 bg-amber-50/60 p-4 shadow-sm">
          <div className="flex items-center gap-2 text-sm font-semibold text-amber-900">
            <MessageCircleQuestion className="h-4 w-4" /> The agent needs you to be more specific
          </div>
          <p className="mt-1.5 text-sm text-amber-900">{resp!.clarification}</p>
          <p className="mt-2 text-xs text-amber-800/80">
            Rather than silently guessing what "worse" means, the agent asks. Refine the question above — or peek at
            its best-guess attempt below.
          </p>
        </div>
      )}

      {real && (
        <div className="grid gap-4 lg:grid-cols-2">
          {/* How the AI read the question */}
          <div className="rounded-xl border bg-card shadow-sm">
            <div className="flex flex-wrap items-center gap-2 border-b px-4 py-2.5 text-sm font-semibold">
              <Sparkles className="h-4 w-4 text-nhs-600" /> How the AI read your question
              {typeof resp!.confidence === "number" && (
                <span className={`ml-auto rounded-full px-2 py-0.5 text-[11px] font-semibold ${confidenceTone(resp!.confidence)}`}>
                  {resp!.confidence}% confident
                </span>
              )}
            </div>
            <div className="space-y-3 px-4 py-3 text-sm">
              {resp!.interpretedIntent && (
                <p><span className="font-medium">Understood as:</span> <span className="text-muted-foreground">{resp!.interpretedIntent}</span></p>
              )}
              {resp!.resources && resp!.resources.length > 0 && (
                <div className="flex flex-wrap items-center gap-1.5">
                  <span className="text-xs font-medium uppercase tracking-wide text-muted-foreground">FHIR resources</span>
                  {resp!.resources.map((r, i) => (
                    <span key={i} className="rounded-full bg-secondary px-2 py-0.5 text-[11px] font-medium">{r}</span>
                  ))}
                </div>
              )}
              {resp!.filters && resp!.filters.length > 0 && (
                <div>
                  <div className="mb-1 text-xs font-medium uppercase tracking-wide text-muted-foreground">Extracted filters</div>
                  <ul className="space-y-1">
                    {resp!.filters.map((f, i) => (
                      <li key={i} className="flex gap-1.5"><ChevronRight className="mt-0.5 h-3.5 w-3.5 shrink-0 text-nhs-600" />{f}</li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
          </div>

          {/* The generated query */}
          {resp!.generatedQuery && (
            <div className="rounded-xl border bg-card shadow-sm">
              <div className="flex flex-wrap items-center gap-2 border-b px-4 py-2.5 text-sm font-semibold">
                <ShieldCheck className="h-4 w-4 text-emerald-600" /> Generated SQL
                <span className={`rounded-full px-2 py-0.5 text-[11px] font-medium ${resp!.validationStatus === "approved" ? "bg-emerald-100 text-emerald-800" : "bg-amber-100 text-amber-800"}`}>
                  {resp!.validationStatus === "approved" ? "validated read-only · executed live" : resp!.validationStatus}
                </span>
                <button type="button" onClick={copySql} className="ml-auto inline-flex items-center gap-1 rounded-md border px-2 py-1 text-xs font-medium text-muted-foreground hover:bg-muted/50">
                  {copied ? <Check className="h-3.5 w-3.5 text-emerald-600" /> : <Copy className="h-3.5 w-3.5" />}
                  {copied ? "Copied" : "Copy SQL"}
                </button>
              </div>
              <div className="px-4 py-3">
                <CodeBlock language="sql" content={resp!.generatedQuery} />
                {resp!.queryExplanation && <p className="mt-2 text-sm text-muted-foreground">{resp!.queryExplanation}</p>}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Results */}
      {real && rows.length > 0 && (
        <div className="rounded-xl border bg-card shadow-sm">
          <div className="flex flex-wrap items-center gap-3 border-b px-4 py-2.5">
            <span className="text-sm font-semibold">
              {resp!.matchCount === 50 ? "50+" : rows.length} patient{rows.length === 1 ? "" : "s"} found
            </span>
            {elapsed !== null && (
              <span className="inline-flex items-center gap-1 text-xs text-muted-foreground"><Clock3 className="h-3.5 w-3.5" /> {(elapsed / 1000).toFixed(1)}s end to end</span>
            )}
            <button type="button" onClick={exportCsv} className="ml-auto inline-flex items-center gap-1 rounded-md border px-2 py-1 text-xs font-medium text-muted-foreground hover:bg-muted/50">
              <Download className="h-3.5 w-3.5" /> Export CSV
            </button>
          </div>
          <div className="max-h-[420px] overflow-auto">
            <table className="w-full text-sm">
              <thead className="sticky top-0 bg-card">
                <tr className="border-b text-left text-muted-foreground">
                  {Object.keys(rows[0]).map((k) => <th key={k} className="px-4 py-2 font-medium">{k}</th>)}
                </tr>
              </thead>
              <tbody>
                {rows.map((row, i) => (
                  <tr key={i} className="border-b last:border-0 hover:bg-muted/30">
                    {Object.values(row).map((v, j) => <td key={j} className="px-4 py-2">{String(v ?? "")}</td>)}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {real && resp!.limitations && resp!.limitations.length > 0 && (
        <p className="text-xs text-muted-foreground">
          <span className="font-medium">The agent's own caveats:</span> {resp!.limitations.join(" · ")}
        </p>
      )}
    </div>
  );
}
