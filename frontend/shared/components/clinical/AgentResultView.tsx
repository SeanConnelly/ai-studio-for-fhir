// The clinician-facing result of a run — the "guideline" view. Rendered with the
// shared CC component library so the Studio preview looks exactly like what the
// Clinical app shows. The whole result is wrapped in AIGeneratedTextPanel (clear
// AI label + source badge + review state); diagnostics (evidence, transcript,
// trace) live in UnderTheHood. Renders every one of the 12 agents' result shapes.
import * as React from "react";
import { XCircle, CheckCircle2, Lightbulb, FileText, ShieldAlert, AlertTriangle, MessageCircle } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@shared/components/ui/card";
import { Badge } from "@shared/components/ui/badge";
import { CodeBlock } from "@shared/components/ui/code-block";
import { AIGeneratedTextPanel } from "@shared/components/clinical/AIGeneratedTextPanel";
import { StatusRiskBadgeBar, toneForStatus } from "@shared/components/clinical/StatusRiskBadgeBar";
import { ContextSummaryCard } from "@shared/components/clinical/ContextSummaryCard";
import { AISafetyChecklist } from "@shared/components/clinical/AISafetyChecklist";
import type { AgentResponse } from "@shared/api/types";

function Section({ title, icon, children }: { title: string; icon?: React.ReactNode; children: React.ReactNode }) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="flex items-center gap-2 text-base">{icon}{title}</CardTitle>
      </CardHeader>
      <CardContent>{children}</CardContent>
    </Card>
  );
}

export function AgentResultView({ resp }: { resp: AgentResponse }) {
  const badges = [{ label: resp.status.replace(/_/g, " "), tone: toneForStatus(resp.status) }];
  if (resp.riskBand) badges.push({ label: `risk: ${resp.riskBand}${typeof resp.riskScore === "number" ? ` (${resp.riskScore}/100)` : ""}`, tone: toneForStatus(resp.riskBand) });
  if (resp.thirtyDayEstimate) badges.push({ label: `30-day est: ${resp.thirtyDayEstimate}`, tone: "secondary" });
  if (resp.urgency) badges.push({ label: `urgency: ${resp.urgency}`, tone: resp.urgency === "red" ? toneForStatus("high") : resp.urgency === "yellow" ? toneForStatus("moderate") : toneForStatus("low") });
  if (resp.acuity) badges.push({ label: `acuity: ${resp.acuity}`, tone: toneForStatus(resp.acuity) });
  if (typeof resp.confidence === "number") badges.push({ label: `confidence: ${resp.confidence}%`, tone: toneForStatus(resp.confidence >= 75 ? "low" : resp.confidence >= 40 ? "moderate" : "high") });

  return (
    <div className="space-y-5">
      {/* Headline — wrapped as AI-generated with source + review state */}
      <AIGeneratedTextPanel
        title="Clinician result"
        source={resp.aiTrace?.source ?? resp.source}
        model={resp.aiTrace?.model}
        reviewState={resp.status === "completed" ? "reviewed" : "draft"}
      >
        <div className="space-y-3">
          <StatusRiskBadgeBar badges={badges} />
          <p className="leading-relaxed">{resp.summary}</p>
          {resp.findings && resp.findings.length > 0 && (
            <ul className="space-y-1 text-muted-foreground">
              {resp.findings.map((f, i) => (
                <li key={i} className="flex gap-2"><span className="text-primary">•</span>{f}</li>
              ))}
            </ul>
          )}
        </div>
      </AIGeneratedTextPanel>

      {/* Smart summary — sections */}
      {resp.sections && resp.sections.length > 0 && (
        <div className="grid gap-4 md:grid-cols-2">
          {resp.sections.map((s, i) => (
            <ContextSummaryCard key={i} heading={s.heading} items={s.items ?? []} />
          ))}
        </div>
      )}

      {/* Medication safety — interactions */}
      {resp.interactions && resp.interactions.length > 0 && (
        <Section title="Medication issues" icon={<AlertTriangle className="h-4 w-4 text-amber-500" />}>
          <div className="space-y-3">
            {resp.interactions.map((it, i) => (
              <div key={i} className="rounded-md border p-3 text-sm">
                <div className="flex items-center gap-2">
                  <Badge variant={toneForStatus(it.severity) === "danger" ? "warning" : "secondary"} className={toneForStatus(it.severity) === "danger" ? "bg-destructive" : undefined}>{it.severity}</Badge>
                  <span className="font-medium">{(it.drugs ?? []).join(" + ")}</span>
                </div>
                <p className="mt-1">{it.issue}</p>
                <p className="mt-1 text-muted-foreground">→ {it.recommendation}</p>
              </div>
            ))}
          </div>
        </Section>
      )}

      {/* Gaps in care */}
      {resp.gaps && resp.gaps.length > 0 && (
        <Section title="Care gaps" icon={<XCircle className="h-4 w-4 text-amber-500" />}>
          <div className="space-y-2 text-sm">
            {resp.gaps.map((g, i) => (
              <div key={i} className="flex items-start gap-2">
                <Badge variant={toneForStatus(g.status) === "success" ? "success" : "warning"} className="shrink-0">{g.status}</Badge>
                <div><span className="font-medium">{g.measure}</span> — {g.detail}{g.recommendedAction && <span className="text-muted-foreground"> · {g.recommendedAction}</span>}</div>
              </div>
            ))}
          </div>
        </Section>
      )}

      {/* Care plan — goals */}
      {resp.goals && resp.goals.length > 0 && (
        <Section title="Care-plan goals">
          <div className="space-y-2 text-sm">
            {resp.goals.map((g, i) => (
              <div key={i} className="flex items-start gap-2">
                <Badge variant={g.onTrack ? "success" : "warning"} className="shrink-0">{g.onTrack ? "on track" : (g.status || "off track")}</Badge>
                <div><span className="font-medium">{g.goal}</span>{g.nextStep && <span className="text-muted-foreground"> · next: {g.nextStep}</span>}</div>
              </div>
            ))}
          </div>
        </Section>
      )}

      {/* Social prescribing — needs (with their evidence) + matched services */}
      {((resp.needs && resp.needs.length > 0) || (resp.referrals && resp.referrals.length > 0)) && (
        <div className="grid gap-4 md:grid-cols-2">
          {resp.needs && resp.needs.length > 0 && (
            <ContextSummaryCard
              heading="Social needs"
              items={resp.needs.map((n) => `${n.domain}: ${n.detail}${n.evidence ? ` (${n.source === "patient-reported" ? "patient said" : "from the record"}: "${n.evidence}")` : ""}`)}
            />
          )}
          {resp.referrals && resp.referrals.length > 0 && (
            <Section title="Matched services">
              <div className="space-y-2 text-sm">
                {resp.referrals.map((r, i) => (
                  <div key={i} className="rounded-md border p-2.5">
                    <div className="flex items-center gap-2">
                      <span className="font-medium">{r.name || r.resource}</span>
                      {r.bestMatch && <Badge variant="success">best match</Badge>}
                    </div>
                    <p className="mt-0.5">{r.reason}</p>
                    {(r.offers || r.contact) && (
                      <p className="mt-0.5 text-xs text-muted-foreground">{[r.offers, r.eligibility, r.contact].filter(Boolean).join(" · ")}</p>
                    )}
                  </div>
                ))}
              </div>
            </Section>
          )}
        </div>
      )}

      {/* Trial matcher — graded matches with flags */}
      {resp.matches && resp.matches.length > 0 && (
        <Section title="Trial matches">
          <div className="space-y-3">
            {resp.matches.map((m, i) => {
              const level = m.matchLevel || m.eligibility || "";
              const tone = level === "likely" || level === "eligible" ? "success" : level === "maybe" || level === "uncertain" ? "warning" : "secondary";
              return (
                <div key={i} className="rounded-md border p-3 text-sm">
                  <div className="flex flex-wrap items-center gap-2">
                    <Badge variant={tone}>{level}</Badge>
                    {typeof m.confidence === "number" && <span className="text-xs text-muted-foreground">{m.confidence}%</span>}
                    <span className="font-medium">{m.trial}</span>
                    {m.nctId && <span className="text-xs text-muted-foreground">{m.nctId}</span>}
                  </div>
                  {m.rationale && <p className="mt-1">{m.rationale}</p>}
                  {m.criteriaMet && m.criteriaMet.length > 0 && <p className="mt-1 text-emerald-700">Met: {m.criteriaMet.join("; ")}</p>}
                  {m.criteriaUnmet && m.criteriaUnmet.length > 0 && <p className="mt-1 text-amber-600">Unmet: {m.criteriaUnmet.join("; ")}</p>}
                  {m.flags && m.flags.length > 0 && <p className="mt-1 font-medium text-amber-700">⚑ {m.flags.join("; ")}</p>}
                </div>
              );
            })}
          </div>
        </Section>
      )}

      {/* Trial matcher — the agent's follow-up questions */}
      {resp.followUpQuestions && resp.followUpQuestions.length > 0 && (
        <Section title="Follow-up questions the agent asks" icon={<MessageCircle className="h-4 w-4 text-sky-600" />}>
          <div className="space-y-1.5 text-sm">
            {resp.followUpQuestions.map((q, i) => (
              <div key={i}><span className="font-medium">{q.question}</span>{q.why && <span className="text-muted-foreground"> — {q.why}</span>}</div>
            ))}
          </div>
          <p className="mt-2 text-xs text-muted-foreground">Supply answers via the optional "Answers to follow-up questions" input and re-run to see the matches re-graded.</p>
        </Section>
      )}

      {/* Readmission risk — factor breakdown + narrative */}
      {resp.riskFactors && resp.riskFactors.length > 0 && (
        <Section title="Risk factors" icon={<AlertTriangle className="h-4 w-4 text-amber-500" />}>
          <table className="w-full text-sm">
            <tbody>
              {resp.riskFactors.map((f, i) => (
                <tr key={i} className="border-b last:border-0">
                  <td className="w-44 py-1.5 pr-2 font-medium">{f.factor}</td>
                  <td className="w-20 py-1.5 pr-2"><Badge variant={f.level === "high" ? "warning" : f.level === "medium" ? "warning" : "success"} className={f.level === "high" ? "bg-destructive" : undefined}>{f.level}</Badge></td>
                  <td className="py-1.5 text-muted-foreground">{f.detail}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {resp.insights && <p className="mt-3 rounded-md border border-sky-200 bg-sky-50/40 p-2.5 text-sm">{resp.insights}</p>}
        </Section>
      )}

      {/* Readmission risk — compact drivers (when no factor table) */}
      {(!resp.riskFactors || resp.riskFactors.length === 0) && resp.riskDrivers && resp.riskDrivers.length > 0 && (
        <Section title="Risk drivers" icon={<AlertTriangle className="h-4 w-4 text-amber-500" />}>
          <ul className="space-y-1 text-sm">
            {resp.riskDrivers.map((d, i) => (<li key={i} className="flex gap-2"><span className="text-amber-500">•</span>{d}</li>))}
          </ul>
        </Section>
      )}

      {/* Suggested tasks (readmission / care-plan navigator) + plan steps */}
      {((resp.suggestedTasks && resp.suggestedTasks.length > 0) || (resp.nextSteps && resp.nextSteps.length > 0) || (resp.overdueTasks && resp.overdueTasks.length > 0)) && (
        <Section title="Plan" icon={<Lightbulb className="h-4 w-4" />}>
          <div className="space-y-3 text-sm">
            {resp.nextSteps && resp.nextSteps.length > 0 && (
              <div>
                <div className="mb-1 font-medium">Next steps</div>
                <ol className="space-y-1">{resp.nextSteps.map((s, i) => (<li key={i}>{i + 1}. <span className="font-medium">{s.action}</span>{s.detail && <span className="text-muted-foreground"> — {s.detail}</span>}</li>))}</ol>
              </div>
            )}
            {resp.overdueTasks && resp.overdueTasks.length > 0 && (
              <div>
                <div className="mb-1 font-medium text-destructive">Overdue</div>
                <ul className="space-y-1">{resp.overdueTasks.map((t, i) => (<li key={i}>• <span className="font-medium">{t.task}</span>{t.detail && <span className="text-muted-foreground"> — {t.detail}</span>}</li>))}</ul>
              </div>
            )}
            {resp.suggestedTasks && resp.suggestedTasks.length > 0 && (
              <div>
                <div className="mb-1 font-medium">Suggested tasks</div>
                <ul className="space-y-1">{resp.suggestedTasks.map((t, i) => (<li key={i}>• <span className="font-medium">{t.task}</span>{t.rationale && <span className="text-muted-foreground"> — {t.rationale}</span>}</li>))}</ul>
              </div>
            )}
          </div>
        </Section>
      )}

      {/* Triage phase 1 — the agent-designed question set */}
      {resp.questions && resp.questions.length > 0 && (
        <Section title="Designed triage questions" icon={<MessageCircle className="h-4 w-4 text-sky-600" />}>
          {resp.greeting && <p className="mb-2 text-sm italic text-muted-foreground">"{resp.greeting}"</p>}
          <ol className="space-y-1.5 text-sm">
            {resp.questions.map((q, i) => (
              <li key={i}>{i + 1}. <span className="font-medium">{q.text}</span> <span className="text-muted-foreground">[{(q.options || []).join(" / ")}]</span></li>
            ))}
          </ol>
          {resp.safetyNote && <p className="mt-2 text-xs text-amber-700">{resp.safetyNote}</p>}
          <p className="mt-2 text-xs text-muted-foreground">Supply answers via the "answers" input (question -&gt; answer | …) and re-run for the clinician handoff.</p>
        </Section>
      )}

      {/* Triage phase 2 — handoff */}
      {(resp.keyFindings || resp.mappedObservations || resp.redFlags || resp.recommendedNextStep) && (
        <Section title="Triage assessment" icon={<AlertTriangle className="h-4 w-4 text-destructive" />}>
          {resp.urgencyLabel && <p className="mb-2 text-sm font-semibold">{resp.urgencyLabel}</p>}
          {resp.keyFindings && resp.keyFindings.length > 0 && (
            <div className="mb-2 space-y-1 text-sm">
              {resp.keyFindings.map((f, i) => (
                <div key={i}><span className="font-medium">{f.finding}</span>{f.source && <span className="text-muted-foreground"> — patient said: "{f.source}"</span>}</div>
              ))}
            </div>
          )}
          {resp.mappedObservations && resp.mappedObservations.length > 0 && (
            <p className="mb-2 text-sm text-muted-foreground"><span className="font-medium text-foreground">Mapped to the record: </span>{resp.mappedObservations.join("; ")}</p>
          )}
          {resp.redFlags && resp.redFlags.length > 0 && (
            <div className="mb-2 text-sm">
              <span className="font-medium text-destructive">Red flags: </span>{resp.redFlags.join("; ")}
            </div>
          )}
          {resp.recommendedNextStep && <p className="text-sm"><span className="font-medium">Recommended next step: </span>{resp.recommendedNextStep}</p>}
        </Section>
      )}

      {/* Lab explainer — explained results (with trend + real reading series) */}
      {((resp.explained && resp.explained.length > 0) || (resp.results && resp.results.length > 0)) && (
        <Section title="Results explained">
          {resp.explained && resp.explained.length > 0 ? (
            <div className="space-y-3 text-sm">
              {resp.explained.map((e, i) => (
                <div key={i} className="rounded-md border p-2.5">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-medium">{e.test}</span>
                    <span>{e.value} {e.unit}</span>
                    <Badge variant={e.flag === "high" ? "warning" : e.flag === "low" ? "secondary" : "success"}>{e.flag}</Badge>
                    {e.trend?.direction && e.trend.direction !== "first-test" && <Badge variant={e.trend.direction === "improving" ? "success" : e.trend.direction === "worsening" ? "warning" : "secondary"}>{e.trend.direction}</Badge>}
                    {e.normalRange && <span className="text-xs text-muted-foreground">normal: {e.normalRange}</span>}
                  </div>
                  <p className="mt-1">{e.meaning}</p>
                  {e.series && e.series.length > 1 && (
                    <p className="mt-1 text-xs text-muted-foreground">Readings: {e.series.map((s) => `${s.value} (${s.date})`).join(" → ")}</p>
                  )}
                </div>
              ))}
            </div>
          ) : (
            <div className="space-y-2 text-sm">
              {(resp.results ?? []).map((r, i) => (
                <div key={i}><span className="font-medium">{r.test}</span> <span className="text-muted-foreground">{r.value}</span> — {r.meaning}</div>
              ))}
            </div>
          )}
          {resp.overallSummary && <p className="mt-3 rounded-md border border-sky-200 bg-sky-50/40 p-2.5 text-sm">{resp.overallSummary}</p>}
          {resp.questionsToAsk && resp.questionsToAsk.length > 0 && (
            <div className="mt-3 text-sm">
              <div className="mb-1 font-medium">Questions for the doctor</div>
              <ul className="space-y-1 text-muted-foreground">{resp.questionsToAsk.map((q, i) => (<li key={i}>• {q}</li>))}</ul>
            </div>
          )}
          {resp.whenToWorry && resp.whenToWorry.length > 0 && (
            <div className="mt-3 rounded-md border border-amber-300 bg-amber-50/50 p-3 text-sm">
              <div className="mb-1 font-medium text-amber-700">When to seek care</div>
              <ul className="space-y-1 text-muted-foreground">{resp.whenToWorry.map((w, i) => (<li key={i}>• {w}</li>))}</ul>
            </div>
          )}
        </Section>
      )}

      {/* Results follow-up — loop tracking + outreach drafts */}
      {resp.trackedResults && resp.trackedResults.length > 0 && (
        <Section title="Tracked results" icon={<CheckCircle2 className="h-4 w-4 text-emerald-600" />}>
          {resp.closedLoopSummary && <p className="mb-2 text-sm font-medium">{resp.closedLoopSummary}</p>}
          <div className="space-y-2 text-sm">
            {resp.trackedResults.map((t, i) => (
              <div key={i} className="rounded-md border p-2.5">
                <div className="flex flex-wrap items-center gap-2">
                  <Badge variant={t.followUpStatus === "closed" ? "success" : t.followUpStatus === "pending" ? "warning" : "warning"} className={t.followUpStatus === "overdue" ? "bg-destructive" : undefined}>{t.followUpStatus}</Badge>
                  <span className="font-medium">{t.result}</span>
                  {t.date && <span className="text-xs text-muted-foreground">{t.date}</span>}
                </div>
                <p className="mt-1">{t.finding}</p>
                {t.followUp && <p className="mt-0.5 text-xs text-muted-foreground">Follow-up: {t.followUp}</p>}
              </div>
            ))}
          </div>
          {(resp.patientOutreach || resp.clinicianNote) && (
            <div className="mt-3 grid gap-3 md:grid-cols-2 text-sm">
              {resp.patientOutreach && <div className="rounded-md border border-sky-200 bg-sky-50/40 p-2.5"><div className="mb-1 font-medium text-sky-800">Draft patient outreach</div>{resp.patientOutreach}</div>}
              {resp.clinicianNote && <div className="rounded-md border p-2.5"><div className="mb-1 font-medium">Clinician note</div><span className="text-muted-foreground">{resp.clinicianNote}</span></div>}
            </div>
          )}
        </Section>
      )}

      {/* Patient-facing message (triage / lab explainer) */}
      {resp.patientMessage && (
        <Section title="Message for the patient" icon={<MessageCircle className="h-4 w-4 text-sky-600" />}>
          <p className="text-sm leading-relaxed">{resp.patientMessage}</p>
          <p className="mt-2 text-xs text-muted-foreground">Plain-language draft — review and edit before sending; nothing is sent automatically.</p>
        </Section>
      )}

      {/* Prior-auth: criteria met vs missing + justification */}
      {(resp.policyCriteriaMatched || resp.missingEvidenceChecklist) && (
        <>
          <div className="grid gap-4 md:grid-cols-2">
            <Section title="Criteria met" icon={<CheckCircle2 className="h-4 w-4 text-emerald-600" />}>
              <div className="space-y-2 text-sm">
                {(resp.policyCriteriaMatched ?? []).map((c, i) => (<div key={i} className="flex gap-2"><CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-emerald-600" />{c}</div>))}
              </div>
            </Section>
            <Section title="Still missing" icon={<XCircle className="h-4 w-4 text-amber-500" />}>
              <div className="space-y-2 text-sm">
                {(resp.missingEvidenceChecklist ?? []).map((c, i) => (<div key={i} className="flex gap-2"><XCircle className="mt-0.5 h-4 w-4 shrink-0 text-amber-500" />{c}</div>))}
              </div>
            </Section>
          </div>
          {resp.draftJustification && (
            <Section title="Draft justification">
              <p className="text-sm leading-relaxed text-muted-foreground">{resp.draftJustification}</p>
            </Section>
          )}
        </>
      )}

      {/* NL-query: a clarifying question when the ask was ambiguous */}
      {resp.clarification && (
        <Section title="Clarifying question" icon={<MessageCircle className="h-4 w-4 text-amber-600" />}>
          <p className="text-sm">{resp.clarification}</p>
          <p className="mt-1 text-xs text-muted-foreground">The question was too ambiguous to translate safely; the agent asks instead of guessing. Any query below is its low-confidence best guess.</p>
        </Section>
      )}

      {/* NL-query: the generated query IS the result */}
      {resp.generatedQuery && (
        <Section title="Generated query" icon={<FileText className="h-4 w-4" />}>
          <div className="mb-2 flex flex-wrap items-center gap-2">
            <Badge variant="secondary">{resp.generatedQueryType}</Badge>
            <Badge variant={resp.validationStatus === "approved" ? "success" : "warning"}>{resp.validationStatus}</Badge>
            {resp.resources && resp.resources.map((r, i) => <Badge key={i} variant="outline">{r}</Badge>)}
          </div>
          {resp.interpretedIntent && <p className="mb-2 text-sm text-muted-foreground">{resp.interpretedIntent}</p>}
          {resp.filters && resp.filters.length > 0 && (
            <ul className="mb-2 space-y-0.5 text-sm text-muted-foreground">
              {resp.filters.map((f, i) => <li key={i}>› {f}</li>)}
            </ul>
          )}
          <CodeBlock language="sql" content={resp.generatedQuery} />
          {resp.resultPreview && resp.resultPreview.length > 0 && (
            <table className="mt-3 w-full text-sm">
              <thead>
                <tr className="border-b text-left text-muted-foreground">
                  {Object.keys(resp.resultPreview[0]).map((k) => <th key={k} className="py-1.5 font-medium">{k}</th>)}
                </tr>
              </thead>
              <tbody>
                {resp.resultPreview.map((row, i) => (
                  <tr key={i} className="border-b last:border-0">
                    {Object.values(row).map((v, j) => <td key={j} className="py-1.5">{String(v)}</td>)}
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          {resp.limitations && resp.limitations.length > 0 && <p className="mt-3 text-xs text-muted-foreground">{resp.limitations.join(" ")}</p>}
        </Section>
      )}

      {/* Custom-schema fields (Studio-built agents): any result keys the named
          renderers above don't know are displayed generically — arrays of
          objects as tables, string arrays as bullets — so an authored
          OutputSchema is visible without a bespoke component. */}
      {(() => {
        const KNOWN = new Set([
          "status", "summary", "findings", "recommendations", "evidence", "source", "aiTrace", "trace", "safety",
          "proposedAction", "requestId", "recipeId", "traceId", "matchCount", "error",
          "sections", "interactions", "gaps", "goals", "nextSteps", "overdueTasks", "suggestedTasks", "needs", "referrals",
          "matches", "followUpQuestions", "riskBand", "riskScore", "thirtyDayEstimate", "riskFactors", "insights", "riskDrivers",
          "acuity", "redFlags", "recommendedNextStep", "patientMessage", "results", "whenToWorry",
          "explained", "overallSummary", "questionsToAsk", "closedLoopSummary", "trackedResults", "patientOutreach", "clinicianNote",
          "policyCriteriaMatched", "missingEvidenceChecklist", "draftJustification", "requestedService",
          "interpretedIntent", "resources", "filters", "confidence", "clarification", "generatedQuery", "generatedQueryType",
          "validationStatus", "resultPreview", "queryExplanation", "limitations",
          "greeting", "questions", "safetyNote", "urgency", "urgencyLabel", "keyFindings", "mappedObservations",
          "missingData",
        ]);
        const extras = Object.entries(resp as unknown as Record<string, unknown>).filter(([k, v]) => !KNOWN.has(k) && v != null && (typeof v === "string" ? v !== "" : true));
        if (extras.length === 0) return null;
        return (
          <Section title="Structured result (custom schema)">
            <div className="space-y-3 text-sm">
              {extras.map(([k, v]) => {
                if (Array.isArray(v) && v.length > 0 && typeof v[0] === "object" && v[0] !== null) {
                  const cols = Object.keys(v[0] as Record<string, unknown>);
                  return (
                    <div key={k}>
                      <div className="mb-1 font-medium">{k}</div>
                      <table className="w-full text-sm">
                        <thead><tr className="border-b text-left text-muted-foreground">{cols.map((c) => <th key={c} className="py-1 pr-3 font-medium">{c}</th>)}</tr></thead>
                        <tbody>
                          {(v as Record<string, unknown>[]).map((row, i) => (
                            <tr key={i} className="border-b last:border-0">{cols.map((c) => <td key={c} className="py-1 pr-3 align-top">{String(row[c] ?? "")}</td>)}</tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  );
                }
                if (Array.isArray(v)) {
                  return (
                    <div key={k}>
                      <div className="mb-1 font-medium">{k}</div>
                      <ul className="space-y-0.5 text-muted-foreground">{(v as unknown[]).map((x, i) => <li key={i}>• {String(x)}</li>)}</ul>
                    </div>
                  );
                }
                if (typeof v === "object") return null;
                return <div key={k}><span className="font-medium">{k}: </span><span className="text-muted-foreground">{String(v)}</span></div>;
              })}
            </div>
          </Section>
        );
      })()}

      {/* Recommendations */}
      {resp.recommendations && resp.recommendations.length > 0 && (
        <Section title="Recommended next steps" icon={<Lightbulb className="h-4 w-4" />}>
          <div className="space-y-2">
            {resp.recommendations.map((r, i) => (
              <div key={i} className="flex items-start gap-2 text-sm">
                <Badge variant={r.priority === "urgent" ? "warning" : "secondary"} className="shrink-0">{r.priority}</Badge>
                <span>{r.text} {r.owner && <span className="text-muted-foreground">({r.owner})</span>}</span>
              </div>
            ))}
          </div>
        </Section>
      )}

      {/* Draft FHIR action */}
      {resp.proposedAction && resp.proposedAction.resourceType && (
        <Card className="border-amber-300">
          <CardHeader>
            <div className="flex items-center justify-between gap-2">
              <CardTitle className="flex items-center gap-2 text-base"><FileText className="h-4 w-4" />Draft {resp.proposedAction.resourceType}</CardTitle>
              <Badge variant="warning" className="gap-1"><ShieldAlert className="h-3 w-3" />Requires human review</Badge>
            </div>
          </CardHeader>
          <CardContent>
            <p className="mb-2 text-xs text-muted-foreground">Nothing is written to the record — this is a draft for a clinician to review and approve (see the Clinical app).</p>
            <CodeBlock language="json" content={JSON.stringify(resp.proposedAction.resource)} />
          </CardContent>
        </Card>
      )}

      <AISafetyChecklist requiresHumanReview={!!resp.proposedAction} />
    </div>
  );
}
