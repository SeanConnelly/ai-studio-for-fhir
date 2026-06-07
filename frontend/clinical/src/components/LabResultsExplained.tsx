// "Your results, explained" — the patient-friendly lab renderer. One card per
// test: the value on a colour-coded range bar (blue low / green normal / red
// high), a warm plain-language meaning grounded in trusted education content,
// the trend with a mini sparkline across real readings, practical suggestions,
// then "questions to ask your doctor" and the overall wrap-up.
// Used by the chart's clinician preview AND the phone portal's Results tab.
import type { AgentResponse } from "@shared/api/types";
import { TrendingUp, TrendingDown, Minus, Sparkle, HelpCircle, AlertTriangle } from "lucide-react";

type Explained = NonNullable<AgentResponse["explained"]>[number];

function flagTone(flag?: string): { chip: string; label: string } {
  const f = (flag || "").toLowerCase();
  if (f === "high") return { chip: "bg-rose-100 text-rose-800", label: "High" };
  if (f === "low") return { chip: "bg-sky-100 text-sky-800", label: "Low" };
  return { chip: "bg-emerald-100 text-emerald-800", label: "Normal" };
}

/** The value positioned on a low/normal/high band bar. */
function RangeBar({ e }: { e: Explained }) {
  const v = Number(e.value);
  if (!isFinite(v) || typeof e.rangeHigh !== "number") return null;
  const lo = typeof e.rangeLow === "number" ? e.rangeLow : 0;
  const hi = e.rangeHigh;
  if (hi <= lo) return null;
  // scale: show the normal band in the middle 60%, with headroom either side
  const span = hi - lo;
  const min = lo - span * 0.35;
  const max = hi + span * 0.35;
  const pct = Math.max(2, Math.min(98, ((v - min) / (max - min)) * 100));
  const loPct = ((lo - min) / (max - min)) * 100;
  const hiPct = ((hi - min) / (max - min)) * 100;
  return (
    <div className="mt-2">
      <div className="relative h-2.5 w-full overflow-hidden rounded-full">
        <div className="absolute inset-y-0 left-0 bg-sky-200" style={{ width: `${loPct}%` }} />
        <div className="absolute inset-y-0 bg-emerald-300" style={{ left: `${loPct}%`, width: `${hiPct - loPct}%` }} />
        <div className="absolute inset-y-0 bg-rose-300" style={{ left: `${hiPct}%`, right: 0 }} />
        <div className="absolute top-1/2 h-4 w-4 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-white bg-foreground shadow" style={{ left: `${pct}%` }} />
      </div>
      {e.normalRange && <div className="mt-1 text-[11px] text-muted-foreground">Normal range: {e.normalRange}</div>}
    </div>
  );
}

/** Mini sparkline across the real readings. */
function Sparkline({ series }: { series: { date: string; value: number }[] }) {
  if (!series || series.length < 2) return null;
  const vals = series.map((s) => Number(s.value)).filter(isFinite);
  if (vals.length < 2) return null;
  const min = Math.min(...vals), max = Math.max(...vals);
  const pad = (max - min) * 0.2 || 1;
  const y = (v: number) => 26 - ((v - (min - pad)) / ((max + pad) - (min - pad))) * 24;
  const x = (i: number) => 4 + (i / (vals.length - 1)) * 92;
  const pts = vals.map((v, i) => `${x(i)},${y(v)}`).join(" ");
  return (
    <span className="inline-flex items-center gap-1.5">
      <svg viewBox="0 0 100 28" className="h-6 w-20">
        <polyline points={pts} fill="none" stroke="currentColor" strokeWidth="2" className="text-nhs-500" />
        {vals.map((v, i) => <circle key={i} cx={x(i)} cy={y(v)} r="2.4" className="fill-nhs-600" />)}
      </svg>
      <span className="text-[11px] text-muted-foreground">{series.length} readings</span>
    </span>
  );
}

function TrendChip({ trend }: { trend?: { direction: string; detail?: string } | null }) {
  if (!trend?.direction || trend.direction === "first-test") return null;
  const d = trend.direction.toLowerCase();
  const cfg = d === "improving"
    ? { cls: "bg-emerald-100 text-emerald-800", icon: <TrendingDown className="h-3.5 w-3.5" />, label: "Improving" }
    : d === "worsening"
    ? { cls: "bg-rose-100 text-rose-800", icon: <TrendingUp className="h-3.5 w-3.5" />, label: "Worsening" }
    : { cls: "bg-slate-100 text-slate-700", icon: <Minus className="h-3.5 w-3.5" />, label: "Stable" };
  return (
    <span className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-semibold ${cfg.cls}`} title={trend.detail || ""}>
      {cfg.icon}{cfg.label}
    </span>
  );
}

export function LabResultsExplained({ resp, compact }: { resp: AgentResponse; compact?: boolean }) {
  const tests = resp.explained ?? [];
  return (
    <div className={compact ? "space-y-3" : "space-y-4"}>
      {tests.map((e, i) => {
        const tone = flagTone(e.flag);
        return (
          <div key={i} className={compact ? "rounded-2xl bg-white p-3.5 shadow-sm" : "rounded-md border p-3.5"}>
            <div className="flex flex-wrap items-center gap-2">
              <span className="font-semibold">{e.test}</span>
              <span className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${tone.chip}`}>{tone.label}</span>
              <TrendChip trend={e.trend} />
            </div>
            <div className="mt-1 flex flex-wrap items-baseline gap-x-3 gap-y-1">
              {e.value !== undefined && <span className="text-xl font-bold">{e.value}<span className="ml-1 text-xs font-medium text-muted-foreground">{e.unit}</span></span>}
              {e.series && e.series.length > 1 && <Sparkline series={e.series} />}
            </div>
            <RangeBar e={e} />
            <p className="mt-2 text-sm leading-relaxed">{e.meaning}</p>
            {e.trend?.detail && <p className="mt-1 text-xs text-muted-foreground">{e.trend.detail}</p>}
            {e.whatYouCanDo && e.whatYouCanDo.length > 0 && (
              <div className="mt-2 text-sm">
                <span className="font-medium">What you can do: </span>
                <span className="text-muted-foreground">{e.whatYouCanDo.join(" · ")}</span>
              </div>
            )}
          </div>
        );
      })}

      {resp.overallSummary && (
        <div className={compact ? "rounded-2xl bg-nhs-50 p-3.5 text-sm leading-relaxed shadow-sm" : "rounded-md border border-nhs-200 bg-nhs-50/50 p-3.5 text-sm leading-relaxed"}>
          <div className="mb-1 flex items-center gap-1.5 font-semibold text-nhs-800"><Sparkle className="h-4 w-4" /> The big picture</div>
          {resp.overallSummary}
        </div>
      )}

      {resp.questionsToAsk && resp.questionsToAsk.length > 0 && (
        <div className={compact ? "rounded-2xl bg-white p-3.5 shadow-sm" : "rounded-md border p-3.5"}>
          <div className="mb-1.5 flex items-center gap-1.5 text-sm font-semibold"><HelpCircle className="h-4 w-4 text-nhs-600" /> Questions to ask your doctor</div>
          <ul className="space-y-1 text-sm text-muted-foreground">
            {resp.questionsToAsk.map((q, i) => <li key={i} className="flex gap-2"><span className="text-nhs-600">•</span>{q}</li>)}
          </ul>
        </div>
      )}

      {resp.whenToWorry && resp.whenToWorry.length > 0 && (
        <div className={compact ? "rounded-2xl bg-amber-50 p-3.5 shadow-sm" : "rounded-md border border-amber-200 bg-amber-50/50 p-3.5"}>
          <div className="mb-1.5 flex items-center gap-1.5 text-sm font-semibold text-amber-800"><AlertTriangle className="h-4 w-4" /> When to get in touch</div>
          <ul className="space-y-1 text-sm text-amber-900/80">
            {resp.whenToWorry.map((w, i) => <li key={i} className="flex gap-2"><span>•</span>{w}</li>)}
          </ul>
        </div>
      )}
    </div>
  );
}
