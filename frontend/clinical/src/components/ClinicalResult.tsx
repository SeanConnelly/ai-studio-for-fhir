// The clinician-facing renderer for an agent result. Mirrors the data shapes the
// developer Studio's AgentResultView understands, but strips all backend framing
// (no source/model/"cached" badges, no FHIR/SQL/vector wording, no raw JSON in
// the body) and presents everything as a CDS advisory card with a human-readable
// draft order. The Studio keeps AgentResultView for developers.
import * as React from "react";
import {
  AlertTriangle, XCircle, CheckCircle2, Lightbulb, MessageCircle, FlaskConical,
} from "lucide-react";
import { ContextSummaryCard } from "@shared/components/clinical/ContextSummaryCard";
import { AdvisoryCard } from "@shared/components/clinical/AdvisoryCard";
import { DraftActionCard } from "@shared/components/clinical/DraftActionCard";
import { CodeBlock } from "@shared/components/ui/code-block";
import { plainEvidence, type Severity } from "@shared/lib/clinical";
import type { AgentResponse } from "@shared/api/types";

function sevTone(s?: string): "info" | "warning" | "critical" {
  const v = (s || "").toLowerCase();
  if (["high", "major", "critical", "emergent", "severe"].includes(v)) return "critical";
  if (["moderate", "urgent", "medium"].includes(v)) return "warning";
  return "info";
}

function pill(sev: "info" | "warning" | "critical", text: string) {
  const cls =
    sev === "critical"
      ? "bg-rose-100 text-rose-800"
      : sev === "warning"
      ? "bg-amber-100 text-amber-800"
      : "bg-sky-100 text-sky-800";
  return <span className={`rounded-full px-2 py-0.5 text-[11px] font-medium ${cls}`}>{text}</span>;
}

/** Shape-specific body — every block the agent might have produced, in plain
 *  clinical language. The headline summary is rendered by the AdvisoryCard. */
function ResultBody({ resp }: { resp: AgentResponse }) {
  return (
    <div className="space-y-4">
      {resp.findings && resp.findings.length > 0 && (
        <ul className="space-y-1 text-sm text-muted-foreground">
          {resp.findings.map((f, i) => (
            <li key={i} className="flex gap-2"><span className="text-nhs-600">•</span>{f}</li>
          ))}
        </ul>
      )}

      {/* Smart summary — snapshot sections */}
      {resp.sections && resp.sections.length > 0 && (
        <div className="grid gap-4 md:grid-cols-2">
          {resp.sections.map((s, i) => (
            <ContextSummaryCard key={i} heading={s.heading} items={s.items ?? []} />
          ))}
        </div>
      )}

      {/* Medication safety — interactions */}
      {resp.interactions && resp.interactions.length > 0 && (
        <div className="space-y-2">
          {resp.interactions.map((it, i) => {
            const sev = sevTone(it.severity);
            return (
              <div key={i} className="rounded-md border p-3 text-sm">
                <div className="flex items-center gap-2">
                  {pill(sev, it.severity)}
                  <span className="font-medium">{(it.drugs ?? []).join(" + ")}</span>
                </div>
                <p className="mt-1">{it.issue}</p>
                <p className="mt-1 text-muted-foreground">→ {it.recommendation}</p>
              </div>
            );
          })}
        </div>
      )}

      {/* Care gaps */}
      {resp.gaps && resp.gaps.length > 0 && (
        <div className="space-y-2 text-sm">
          {resp.gaps.map((g, i) => (
            <div key={i} className="flex items-start gap-2">
              {pill(g.status?.toLowerCase() === "overdue" ? "warning" : "info", g.status)}
              <div>
                <span className="font-medium">{g.measure}</span> — {g.detail}
                {g.recommendedAction && <span className="text-muted-foreground"> · {g.recommendedAction}</span>}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Care-plan goals */}
      {resp.goals && resp.goals.length > 0 && (
        <div className="space-y-2 text-sm">
          {resp.goals.map((g, i) => (
            <div key={i} className="flex items-start gap-2">
              {pill(g.onTrack ? "info" : "warning", g.onTrack ? "on track" : g.status || "off track")}
              <div>
                <span className="font-medium">{g.goal}</span>
                {g.nextStep && <span className="text-muted-foreground"> · next: {g.nextStep}</span>}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Social prescribing — identified needs (each grounded in evidence) */}
      {resp.needs && resp.needs.length > 0 && (
        <div>
          <div className="mb-1.5 text-sm font-medium">Identified needs</div>
          <div className="space-y-2">
            {resp.needs.map((n, i) => (
              <div key={i} className="rounded-md border p-3 text-sm">
                <div className="flex items-center gap-2">
                  {pill("warning", n.domain)}
                  <span className="font-medium">{n.detail}</span>
                </div>
                {n.evidence && (
                  <p className="mt-1.5 text-muted-foreground">
                    {n.source === "patient-reported" ? <>Patient told us: <span className="italic">&ldquo;{n.evidence}&rdquo;</span></> : <>{n.evidence}</>}
                  </p>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Social prescribing — matched local services */}
      {resp.referrals && resp.referrals.length > 0 && (
        <div>
          <div className="mb-1.5 text-sm font-medium">Matched local services</div>
          <div className="space-y-2">
            {resp.referrals.map((r, i) => (
              <div
                key={i}
                className={`rounded-md border p-3 text-sm ${r.bestMatch ? "border-nhs-300 bg-nhs-50/50" : ""}`}
              >
                <div className="flex items-center gap-2">
                  <span className="font-medium">{r.name || r.resource}</span>
                  {r.bestMatch && (
                    <span className="rounded-full bg-nhs-600 px-2 py-0.5 text-[11px] font-semibold text-white">Best match</span>
                  )}
                </div>
                <p className="mt-1">{r.reason}</p>
                <div className="mt-1.5 space-y-0.5 text-muted-foreground">
                  {r.offers && <p>Offers: {r.offers}</p>}
                  {r.eligibility && <p>Who it's for: {r.eligibility}</p>}
                  {r.contact && <p>Contact: {r.contact}</p>}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Trial matches — graded likely / maybe / unlikely with cited criteria */}
      {resp.matches && resp.matches.length > 0 && (
        <div className="space-y-2">
          {resp.matches.map((m, i) => {
            const level = (m.matchLevel || m.eligibility || "").toLowerCase();
            const chip =
              level === "likely" || level === "eligible"
                ? "bg-emerald-100 text-emerald-800"
                : level === "maybe" || level === "uncertain"
                ? "bg-amber-100 text-amber-800"
                : "bg-slate-100 text-slate-600";
            const label = level === "likely" ? "Likely eligible" : level === "maybe" ? "Maybe" : level === "unlikely" ? "Unlikely" : m.matchLevel || m.eligibility;
            return (
              <div key={i} className={`rounded-md border p-3 text-sm ${level === "likely" ? "border-emerald-200 bg-emerald-50/30" : ""}`}>
                <div className="flex flex-wrap items-center gap-2">
                  <span className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${chip}`}>{label}</span>
                  {typeof m.confidence === "number" && (
                    <span className="text-[11px] font-medium text-muted-foreground">{m.confidence}% confidence</span>
                  )}
                  <span className="font-medium">{m.trial}</span>
                  {m.nctId && <span className="text-[11px] text-muted-foreground">{m.nctId}</span>}
                </div>
                {m.rationale && <p className="mt-1.5">{m.rationale}</p>}
                {m.criteriaMet && m.criteriaMet.length > 0 && (
                  <div className="mt-1.5 space-y-0.5">
                    {m.criteriaMet.map((c, j) => (
                      <div key={j} className="flex gap-1.5 text-emerald-700"><CheckCircle2 className="mt-0.5 h-3.5 w-3.5 shrink-0" />{c}</div>
                    ))}
                  </div>
                )}
                {m.criteriaUnmet && m.criteriaUnmet.length > 0 && (
                  <div className="mt-1 space-y-0.5">
                    {m.criteriaUnmet.map((c, j) => (
                      <div key={j} className="flex gap-1.5 text-amber-700"><XCircle className="mt-0.5 h-3.5 w-3.5 shrink-0" />{c}</div>
                    ))}
                  </div>
                )}
                {m.flags && m.flags.length > 0 && (
                  <div className="mt-1.5 space-y-0.5">
                    {m.flags.map((f, j) => (
                      <div key={j} className="flex gap-1.5 font-medium text-amber-800"><AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0" />{f}</div>
                    ))}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      {/* Readmission risk — drivers */}
      {resp.riskDrivers && resp.riskDrivers.length > 0 && (
        <div>
          <div className="mb-1 flex items-center gap-2 text-sm font-medium">
            <AlertTriangle className="h-4 w-4 text-amber-500" /> What's driving the risk
          </div>
          <ul className="space-y-1 text-sm text-muted-foreground">
            {resp.riskDrivers.map((d, i) => (<li key={i} className="flex gap-2"><span className="text-amber-500">•</span>{d}</li>))}
          </ul>
        </div>
      )}

      {/* Triage — red flags + next step */}
      {(resp.redFlags || resp.recommendedNextStep) && (
        <div className="rounded-md border p-3 text-sm">
          {resp.redFlags && resp.redFlags.length > 0 && (
            <div className="mb-1"><span className="font-medium text-rose-700">Red flags: </span>{resp.redFlags.join("; ")}</div>
          )}
          {resp.recommendedNextStep && <p><span className="font-medium">Recommended next step: </span>{resp.recommendedNextStep}</p>}
        </div>
      )}

      {/* Lab explainer — results */}
      {resp.results && resp.results.length > 0 && (
        <div>
          <div className="mb-1 flex items-center gap-2 text-sm font-medium"><FlaskConical className="h-4 w-4 text-nhs-600" /> Your results, explained</div>
          <div className="space-y-2 text-sm">
            {resp.results.map((r, i) => (
              <div key={i}><span className="font-medium">{r.test}</span> <span className="text-muted-foreground">{r.value}</span> — {r.meaning}</div>
            ))}
          </div>
          {resp.whenToWorry && resp.whenToWorry.length > 0 && (
            <div className="mt-3 rounded-md border border-amber-300 bg-amber-50/50 p-3 text-sm">
              <div className="mb-1 font-medium text-amber-700">When to seek care</div>
              <ul className="space-y-1 text-muted-foreground">{resp.whenToWorry.map((w, i) => (<li key={i}>• {w}</li>))}</ul>
            </div>
          )}
        </div>
      )}

      {/* Patient-facing message */}
      {resp.patientMessage && (
        <div className="rounded-md border border-sky-200 bg-sky-50/40 p-3 text-sm">
          <div className="mb-1 flex items-center gap-2 font-medium text-sky-700"><MessageCircle className="h-4 w-4" /> Message for the patient</div>
          <p className="leading-relaxed">{resp.patientMessage}</p>
          <p className="mt-2 text-xs text-muted-foreground">Plain-language draft — review and edit before sending; nothing is sent automatically.</p>
        </div>
      )}

      {/* Prior-auth: criteria met / missing / justification */}
      {(resp.policyCriteriaMatched || resp.missingEvidenceChecklist) && (
        <div className="grid gap-4 md:grid-cols-2">
          <div>
            <div className="mb-1 text-sm font-medium text-emerald-700">Criteria met</div>
            <div className="space-y-1 text-sm">
              {(resp.policyCriteriaMatched ?? []).map((c, i) => (<div key={i} className="flex gap-2"><CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-emerald-600" />{c}</div>))}
            </div>
          </div>
          <div>
            <div className="mb-1 text-sm font-medium text-amber-700">Still needed</div>
            <div className="space-y-1 text-sm">
              {(resp.missingEvidenceChecklist ?? []).map((c, i) => (<div key={i} className="flex gap-2"><XCircle className="mt-0.5 h-4 w-4 shrink-0 text-amber-500" />{c}</div>))}
            </div>
          </div>
          {resp.draftJustification && (
            <div className="md:col-span-2 rounded-md border bg-muted/30 p-3 text-sm text-muted-foreground">{resp.draftJustification}</div>
          )}
        </div>
      )}

      {/* Recommendations */}
      {resp.recommendations && resp.recommendations.length > 0 && (
        <div>
          <div className="mb-1 flex items-center gap-2 text-sm font-medium"><Lightbulb className="h-4 w-4 text-nhs-600" /> Recommended next steps</div>
          <div className="space-y-1.5">
            {resp.recommendations.map((r, i) => (
              <div key={i} className="flex items-start gap-2 text-sm">
                {pill(r.priority?.toLowerCase() === "urgent" || r.priority?.toLowerCase() === "high" ? "warning" : "info", r.priority)}
                <span>{r.text} {r.owner && <span className="text-muted-foreground">({r.owner})</span>}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

export interface ClinicalResultProps {
  resp: AgentResponse;
  title: string;
  severity?: Severity;
  actionBusy?: boolean;
  decided?: { decision: string; reviewer?: string; committedRef?: string } | null;
  onSign?: () => void;
  onDecline?: () => void;
}

export function ClinicalResult({ resp, title, severity = "info", actionBusy, decided, onSign, onDecline }: ClinicalResultProps) {
  const sources = plainEvidence(resp.evidence);
  const technical = resp.aiTrace?.rawResponse ? (
    <CodeBlock language="json" content={resp.aiTrace.rawResponse} />
  ) : undefined;
  const draft = resp.proposedAction && resp.proposedAction.resourceType ? (
    <DraftActionCard
      resourceType={resp.proposedAction.resourceType}
      resource={resp.proposedAction.resource}
      busy={actionBusy}
      decided={decided}
      onSign={onSign}
      onDecline={onDecline}
    />
  ) : null;

  return (
    <AdvisoryCard title={title} severity={severity} summary={resp.summary} sources={sources} technical={technical} footer={draft}>
      <ResultBody resp={resp} />
    </AdvisoryCard>
  );
}
