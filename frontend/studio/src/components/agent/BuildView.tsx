// Step-by-step Agent Builder (Studio v3). The agent is presented exactly as the
// runtime executes it: an ordered pipeline of steps — capture inputs → gather
// evidence (FHIR / SQL / vector / library sources) → reason once with AI →
// propose a draft action. Every evidence step is testable in isolation against a
// chosen test patient via /authoring/step-test, which calls the SAME engine code
// the production Business Operations call; the Reason step previews the EXACT
// prompt the runtime will send via /authoring/prompt-preview (no LLM call).
// The step list is a pure projection of the agent definition JSON — saving still
// validates → compiles → deploys through the authoring API, and the definition
// shape is unchanged, so the 12 built-in agents are untouched.
import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  Zap, Sparkles, FileEdit, Save, Copy, CheckCircle2, Database, Search, Plus,
  Trash2, AlertTriangle, Boxes, SlidersHorizontal, PlayCircle, Loader2, Eye,
  ChevronDown, ChevronRight, FlaskConical, Undo2,
} from "lucide-react";
import { Card, CardContent } from "@shared/components/ui/card";
import { Badge } from "@shared/components/ui/badge";
import { Button } from "@shared/components/ui/button";
import { Input } from "@shared/components/ui/input";
import { Textarea } from "@shared/components/ui/textarea";
import { Label } from "@shared/components/ui/label";
import { Dialog } from "@shared/components/ui/dialog";
import { api } from "@shared/api/client";
import type { AgentDefinition, InputField, PatientOption, PromptPreviewResult, StepTestResult } from "@shared/api/types";
import { cn } from "@shared/lib/utils";

type Options = Awaited<ReturnType<typeof api.optionsEvidence>>;

const INPUT_TYPES = ["patient", "text", "fhir-reference", "enum"];
const TRIGGER_TYPES = ["manual", "manual-or-api", "event"];
const ACTION_RESOURCES = ["Task", "ServiceRequest", "DocumentReference", "DetectedIssue", "CarePlan"];
const VECTOR_QUERY_MODES: { value: string; label: string }[] = [
  { value: "", label: "Agent description (default)" },
  { value: "patient-profile", label: "Patient profile (age/sex, problems, meds, key results)" },
  { value: "abnormal-results", label: "The patient's flagged/abnormal results" },
  { value: "social-screening", label: "The patient's social-needs screening answers" },
];

// ---------- step model: a pure projection of the definition ----------

type Step =
  | { key: string; kind: "inputs" }
  | { key: string; kind: "fhir" }
  | { key: string; kind: "sql"; index: number; name: string }
  | { key: string; kind: "vector"; index: number; collection: string }
  | { key: string; kind: "source"; index: number; slug: string }
  | { key: string; kind: "reason" }
  | { key: string; kind: "action" };

function deriveSteps(d: AgentDefinition): Step[] {
  const steps: Step[] = [{ key: "inputs", kind: "inputs" }];
  const ev = d.evidence ?? { fhir: [], sql: [], vector: [] };
  if (ev.fhir?.length) steps.push({ key: "fhir", kind: "fhir" });
  (ev.sql ?? []).forEach((name, index) => steps.push({ key: `sql:${name}`, kind: "sql", index, name }));
  (ev.vector ?? []).forEach((collection, index) => steps.push({ key: `vector:${collection}`, kind: "vector", index, collection }));
  (ev.sources ?? []).forEach((slug, index) => steps.push({ key: `source:${slug}`, kind: "source", index, slug }));
  steps.push({ key: "reason", kind: "reason" });
  if (d.action?.type && d.action.type !== "none") steps.push({ key: "action", kind: "action" });
  return steps;
}

const STEP_META: Record<Step["kind"], { icon: typeof Database; title: string; runtime: string }> = {
  inputs: { icon: SlidersHorizontal, title: "Capture inputs", runtime: "Run panel form" },
  fhir: { icon: Database, title: "Read the FHIR record", runtime: "BO · FHIRReadOperation" },
  sql: { icon: Database, title: "Structured query", runtime: "BO · SQLQueryOperation" },
  vector: { icon: Search, title: "Semantic search", runtime: "BO · VectorSearchOperation" },
  source: { icon: Boxes, title: "Evidence source", runtime: "Evidence Engine" },
  reason: { icon: Sparkles, title: "Reason with AI", runtime: "BO · AIHubOperation" },
  action: { icon: FileEdit, title: "Propose draft action", runtime: "BO · FHIRWritebackOperation" },
};

// ---------- generic result rendering for the per-step test drawers ----------

function RowsTable({ rows }: { rows: Record<string, unknown>[] }) {
  if (!rows.length) return <p className="text-xs text-muted-foreground">No rows.</p>;
  const cols = Array.from(new Set(rows.slice(0, 5).flatMap((r) => Object.keys(r))));
  const shown = rows.slice(0, 8);
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-xs">
        <thead>
          <tr className="border-b text-left text-muted-foreground">
            {cols.map((c) => <th key={c} className="py-1 pr-3 font-medium">{c}</th>)}
          </tr>
        </thead>
        <tbody>
          {shown.map((r, i) => (
            <tr key={i} className="border-b border-border/50">
              {cols.map((c) => <td key={c} className="py-1 pr-3">{String(r[c] ?? "")}</td>)}
            </tr>
          ))}
        </tbody>
      </table>
      {rows.length > shown.length && <p className="mt-1 text-xs text-muted-foreground">…and {rows.length - shown.length} more</p>}
    </div>
  );
}

function TestResultBody({ res }: { res: StepTestResult }) {
  const r = res.result;
  if (!r) return null;
  // vector: chunks with scores
  if (Array.isArray(r.chunks)) {
    return (
      <div className="space-y-1.5">
        {r.queryText && <p className="text-xs text-muted-foreground">Query text: <span className="italic">“{String(r.queryText).slice(0, 180)}{String(r.queryText).length > 180 ? "…" : ""}”</span></p>}
        {r.chunks.map((c: any, i: number) => (
          <div key={i} className="rounded border bg-secondary/30 p-2 text-xs">
            <div className="mb-0.5 flex items-center justify-between gap-2">
              <span className="font-medium">{c.title ?? c.documentId}</span>
              <Badge variant="secondary" className="font-mono">{Number(c.score).toFixed(3)}</Badge>
            </div>
            <p className="line-clamp-3 text-muted-foreground">{c.chunkText}</p>
          </div>
        ))}
      </div>
    );
  }
  // FHIR: resources grouped by type
  if (Array.isArray(r.resources)) {
    const byType: Record<string, string[]> = {};
    for (const o of r.resources) (byType[o.resourceType] ??= []).push(o.display ?? o.id ?? "");
    return (
      <div className="space-y-1 text-xs">
        {Object.entries(byType).map(([t, items]) => (
          <div key={t}>
            <span className="font-medium">{t}</span> <Badge variant="secondary">{items.length}</Badge>
            <p className="line-clamp-2 text-muted-foreground">{items.slice(0, 6).join("; ")}{items.length > 6 ? "; …" : ""}</p>
          </div>
        ))}
      </div>
    );
  }
  // custom SQL: rows
  if (Array.isArray(r.rows)) return <RowsTable rows={r.rows} />;
  // named queries: first array-of-objects property (conditions / labs / encounters / …)
  for (const [k, v] of Object.entries(r)) {
    if (Array.isArray(v) && v.length && typeof v[0] === "object") {
      return (
        <div>
          <p className="mb-1 text-xs font-medium text-muted-foreground">{k}</p>
          <RowsTable rows={v as Record<string, unknown>[]} />
        </div>
      );
    }
  }
  return <pre className="max-h-48 overflow-auto rounded bg-secondary/40 p-2 text-xs">{JSON.stringify(r, null, 2).slice(0, 3000)}</pre>;
}

// ---------- the step rail shell ----------

function StepShell({ n, kind, summary, state, open, onToggle, onRemove, children }: {
  n: number;
  kind: Step["kind"];
  summary: string;
  state?: { running?: boolean; res?: StepTestResult };
  open: boolean;
  onToggle: () => void;
  onRemove?: () => void;
  children: React.ReactNode;
}) {
  const meta = STEP_META[kind];
  const Icon = meta.icon;
  const ok = state?.res && state.res.ok === 1 && !state.res.error;
  const failed = state?.res && (!state.res.ok || state.res.error);
  return (
    <div className="relative pl-10">
      {/* rail */}
      <div className="absolute left-3 top-0 h-full w-px bg-border" aria-hidden />
      <div className={cn(
        "absolute left-0 top-3 flex h-6 w-6 items-center justify-center rounded-full border bg-card text-xs font-semibold",
        ok ? "border-emerald-400 text-emerald-600" : failed ? "border-destructive text-destructive" : "border-border text-muted-foreground"
      )}>
        {n}
      </div>
      <Card className="mb-3">
        <button type="button" onClick={onToggle} className="flex w-full items-center gap-2.5 px-4 py-3 text-left">
          <Icon className="h-4 w-4 shrink-0 text-primary" />
          <span className="font-medium">{meta.title}</span>
          <span className="min-w-0 flex-1 truncate text-sm text-muted-foreground">{summary}</span>
          {state?.running && <Loader2 className="h-4 w-4 animate-spin text-muted-foreground" />}
          {!state?.running && ok && (
            <span className="inline-flex items-center gap-1 text-xs font-medium text-emerald-600">
              <CheckCircle2 className="h-3.5 w-3.5" />{state!.res!.summary ?? "ok"} · {state!.res!.ms} ms
            </span>
          )}
          {!state?.running && failed && (
            <span className="inline-flex items-center gap-1 text-xs font-medium text-destructive">
              <AlertTriangle className="h-3.5 w-3.5" />failed
            </span>
          )}
          <Badge variant="outline" className="hidden shrink-0 font-normal text-muted-foreground sm:inline-flex">{meta.runtime}</Badge>
          {onRemove && (
            <span
              role="button"
              tabIndex={0}
              onClick={(e) => { e.stopPropagation(); onRemove(); }}
              onKeyDown={(e) => { if (e.key === "Enter") { e.stopPropagation(); onRemove(); } }}
              className="rounded p-1 text-muted-foreground hover:bg-secondary hover:text-destructive"
              title="Remove step"
            >
              <Trash2 className="h-4 w-4" />
            </span>
          )}
          {open ? <ChevronDown className="h-4 w-4 shrink-0 text-muted-foreground" /> : <ChevronRight className="h-4 w-4 shrink-0 text-muted-foreground" />}
        </button>
        {open && <CardContent className="border-t pt-3">{children}</CardContent>}
      </Card>
    </div>
  );
}

// ---------- the builder ----------

type CustomDraft = { name: string; sql: string; readonly?: boolean; kindLabel?: string; dirty?: boolean; loaded: boolean };

export function BuildView({ definition, slug, isSystem = false, hasOverride = false }: {
  definition: AgentDefinition;
  slug: string;
  isSystem?: boolean;
  hasOverride?: boolean;
}) {
  const navigate = useNavigate();
  const [d, setD] = useState<AgentDefinition>(definition);
  const [opts, setOpts] = useState<Options | null>(null);
  const [patients, setPatients] = useState<PatientOption[]>([]);
  const [testPatient, setTestPatient] = useState<string>(definition.testCase?.patientId || "");
  const [open, setOpen] = useState<Record<string, boolean>>({});
  const [tests, setTests] = useState<Record<string, { running?: boolean; res?: StepTestResult }>>({});
  const [drafts, setDrafts] = useState<Record<string, CustomDraft>>({});
  const [preview, setPreview] = useState<{ running?: boolean; res?: PromptPreviewResult } | null>(null);
  const [saving, setSaving] = useState(false);
  const [result, setResult] = useState<{ ok: boolean; msg: string; errors?: string[] } | null>(null);
  const [cloneOpen, setCloneOpen] = useState(false);
  const [cloneSlug, setCloneSlug] = useState(`${slug}-copy`);
  const [cloneName, setCloneName] = useState(`${definition.name} (copy)`);

  useEffect(() => { setD(definition); setTests({}); setPreview(null); }, [definition]);
  useEffect(() => { api.optionsEvidence().then(setOpts).catch(() => setOpts(null)); }, []);
  useEffect(() => {
    api.optionsPatients().then((r) => {
      setPatients(r.patients);
      setTestPatient((p) => p || r.patients[0]?.ref || "");
    }).catch(() => setPatients([]));
  }, []);

  const steps = useMemo(() => deriveSteps(d), [d]);
  const dirty = useMemo(
    () => JSON.stringify(d) !== JSON.stringify(definition) || Object.values(drafts).some((c) => c.dirty),
    [d, definition, drafts]
  );

  // the context every step test runs with: input defaults + the test case context
  const testContext = useMemo(() => {
    const ctx: Record<string, unknown> = {};
    for (const i of d.inputs ?? []) if (i.default) ctx[i.key] = i.default;
    Object.assign(ctx, d.testCase?.context ?? {});
    if (testPatient) ctx.patient = testPatient;
    return ctx;
  }, [d, testPatient]);

  function set<K extends keyof AgentDefinition>(k: K, v: AgentDefinition[K]) {
    setD({ ...d, [k]: v });
  }
  function setEv(patch: Partial<AgentDefinition["evidence"]>) {
    set("evidence", { ...d.evidence, ...patch });
  }
  function setInput(i: number, patch: Partial<InputField>) {
    const inputs = [...(d.inputs ?? [])];
    inputs[i] = { ...inputs[i], ...patch };
    set("inputs", inputs);
  }
  function pickTestPatient(ref: string) {
    setTestPatient(ref);
    setD({ ...d, testCase: { patientId: ref, context: (d.testCase?.context ?? {}) as Record<string, unknown> } });
    setTests({});
    setPreview(null);
  }

  // lazily load an evidence-source component when its step is expanded
  async function ensureDraft(srcSlug: string) {
    if (drafts[srcSlug]) return;
    setDrafts((p) => ({ ...p, [srcSlug]: { name: srcSlug, sql: "", loaded: false } }));
    try {
      const c = await api.component<any>("evidence-sources", srcSlug);
      const spec = typeof c.spec === "string" ? JSON.parse(c.spec || "{}") : (c.spec ?? {});
      setDrafts((p) => ({
        ...p,
        [srcSlug]: {
          name: c.name ?? srcSlug,
          sql: spec.sql ?? "",
          readonly: !!c.isSystem || c.kind !== "sql",
          kindLabel: c.kind,
          loaded: true,
        },
      }));
    } catch {
      // not saved yet — a brand-new custom step
      setDrafts((p) => ({ ...p, [srcSlug]: { name: srcSlug, sql: "", dirty: true, loaded: true } }));
    }
  }

  // ---------- per-step testing ----------

  async function runTest(key: string, body: Record<string, unknown>) {
    setTests((p) => ({ ...p, [key]: { running: true } }));
    try {
      const res = await api.stepTest({ ...body, patientRef: testPatient, context: testContext });
      setTests((p) => ({ ...p, [key]: { res } }));
    } catch (e) {
      setTests((p) => ({ ...p, [key]: { res: { ok: 0, kind: String(body.kind), ms: 0, error: (e as Error).message } } }));
    }
  }

  async function runPreview() {
    setPreview({ running: true });
    try {
      const res = await api.promptPreview({ ...d, id: d.id || slug }, testPatient, testContext);
      setPreview({ res });
    } catch (e) {
      setPreview({ res: { ok: 0, ms: 0, error: (e as Error).message } });
    }
  }

  // ---------- save / clone / discard ----------

  const warnings = useMemo(() => {
    const w: string[] = [];
    if (!d.name?.trim()) w.push("Name is empty.");
    if (!d.agent?.instruction?.trim()) w.push("The Reason step's instruction is empty — the agent won't know its job.");
    if (!d.agent?.outputSchema) w.push("Pick an output contract on the Reason step — save requires one.");
    const ev = d.evidence ?? { fhir: [], sql: [], vector: [] };
    if (!(ev.fhir?.length || ev.sql?.length || ev.vector?.length || ev.sources?.length)) {
      w.push("No evidence steps — the agent will reason without any patient data.");
    }
    return w;
  }, [d]);

  async function save(): Promise<boolean> {
    setSaving(true);
    setResult(null);
    try {
      // persist edited custom SQL sources first (they're real EvidenceSource components)
      for (const [srcSlug, c] of Object.entries(drafts)) {
        if (!c.dirty || c.readonly) continue;
        await api.updateComponent("evidence-sources", srcSlug, {
          slug: srcSlug, name: c.name, kind: "sql",
          spec: JSON.stringify({ sql: c.sql }),
          description: `Custom query for agent "${d.name}"`,
        });
        setDrafts((p) => ({ ...p, [srcSlug]: { ...p[srcSlug], dirty: false } }));
      }
      const r = await api.updateFlow(slug, d);
      setResult({
        ok: r.compiled && r.deployed,
        msg: r.compiled ? `Saved, compiled${r.deployed ? " & deployed — ready to run" : ""}.` : "Saved as draft — fix the compile errors below.",
        errors: r.errors || [],
      });
      return r.compiled && r.deployed;
    } catch (e: any) {
      setResult({ ok: false, msg: e.message });
      return false;
    } finally {
      setSaving(false);
    }
  }

  async function saveAndRun() {
    if (!dirty || (await save())) navigate(`/agent/${slug}/run`);
  }

  async function doClone() {
    try {
      await api.cloneFlow(slug, cloneSlug, cloneName);
      setCloneOpen(false);
      navigate(`/agent/${cloneSlug}/build`);
    } catch (e: any) {
      setResult({ ok: false, msg: e.message });
    }
  }

  async function discardOverride() {
    try {
      await api.deleteFlow(slug);
      setResult({ ok: true, msg: "Override discarded — the built-in agent (and its bundled cached AI runs) is restored. Reload the page." });
    } catch (e: any) {
      setResult({ ok: false, msg: e.message });
    }
  }

  // ---------- add-step palette ----------

  const canAddFhir = !(d.evidence?.fhir?.length);
  const canAddAction = !d.action?.type || d.action.type === "none";
  function addSql() {
    const free = (opts?.sqlQueries ?? []).find((q) => !(d.evidence.sql ?? []).includes(q));
    if (free) setEv({ sql: [...(d.evidence.sql ?? []), free] });
  }
  function addVector() {
    const free = (opts?.vectorCollections ?? []).find((c) => !(d.evidence.vector ?? []).includes(c));
    if (free) setEv({ vector: [...(d.evidence.vector ?? []), free] });
  }
  function addLibrarySource() {
    const free = (opts?.evidenceSources ?? []).map((s) => s.slug).find((s) => !(d.evidence.sources ?? []).includes(s));
    if (free) setEv({ sources: [...(d.evidence.sources ?? []), free] });
  }
  function addCustomSql() {
    let n = 1;
    while ((d.evidence.sources ?? []).includes(`${slug}-q${n}`) || drafts[`${slug}-q${n}`]) n++;
    const srcSlug = `${slug}-q${n}`;
    setDrafts((p) => ({
      ...p,
      [srcSlug]: {
        name: `Custom query ${n}`,
        sql: "SELECT TOP 10 o.dateStart AS Observed, vq.value AS Value, vq.unit AS Unit\nFROM HSFHIR_X0001_S.Observation o\nJOIN HSFHIR_X0001_S_Observation.valueQuantity vq ON vq.Key = o.Key\nWHERE o.patient = '{{patientRef}}' AND o.code LIKE '%33914-3%'\nORDER BY o.dateStart DESC",
        dirty: true,
        loaded: true,
      },
    }));
    setEv({ sources: [...(d.evidence.sources ?? []), srcSlug] });
    setOpen((p) => ({ ...p, [`source:${srcSlug}`]: true }));
  }
  function addAction() {
    set("action", { type: "draft-fhir-create", resourceType: "Task", approvalRequired: true });
  }

  const schemaKnown = !d.agent?.outputSchema || (opts?.outputSchemas ?? []).some((s) => s.slug === d.agent.outputSchema);

  // ---------- render ----------

  let stepNo = 0;

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-muted-foreground">
          Steps run top to bottom, exactly as the runtime executes them:{" "}
          <span className="font-medium text-foreground">gather evidence → reason once with AI → propose a draft action</span>.
          Test each step as you build — every test runs the same code the production calls.
        </p>
        <div className="flex gap-2">
          <Button variant="outline" size="sm" onClick={() => setCloneOpen(true)}><Copy className="mr-1 h-4 w-4" />Clone</Button>
          <Button variant="outline" size="sm" onClick={saveAndRun} disabled={saving}><PlayCircle className="mr-1 h-4 w-4" />Run agent</Button>
          <Button size="sm" onClick={save} disabled={saving}><Save className="mr-1 h-4 w-4" />{saving ? "Saving…" : "Save & deploy"}</Button>
        </div>
      </div>

      {isSystem && (dirty || hasOverride) && (
        <div className="flex items-start justify-between gap-3 rounded-md border border-amber-300 bg-amber-50/50 px-3 py-2 text-sm text-amber-800">
          <span className="flex items-start gap-1.5">
            <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0" />
            This is a built-in agent. Saving creates an override that takes precedence at run time — its runs leave the
            bundled response cache (they go live with a key, or deterministic without) until the override is discarded.
            Clone it instead to experiment freely.
          </span>
          {hasOverride && (
            <Button variant="outline" size="sm" className="shrink-0" onClick={discardOverride}>
              <Undo2 className="mr-1 h-3.5 w-3.5" />Discard override
            </Button>
          )}
        </div>
      )}

      {result && (
        <div className={`rounded-md border px-3 py-2 text-sm ${result.ok ? "border-emerald-300 bg-emerald-50/50 text-emerald-700" : "border-destructive/40 bg-destructive/10 text-destructive"}`}>
          <div className="flex items-center gap-2">{result.ok && <CheckCircle2 className="h-4 w-4" />}{result.msg}</div>
          {result.errors && result.errors.length > 0 && (
            <ul className="mt-1 list-inside list-disc">{result.errors.map((e, i) => <li key={i}>{e}</li>)}</ul>
          )}
        </div>
      )}
      {warnings.length > 0 && (
        <div className="rounded-md border border-amber-300 bg-amber-50/50 px-3 py-2 text-sm text-amber-800">
          {warnings.map((w, i) => <div key={i} className="flex items-start gap-1.5"><AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0" />{w}</div>)}
        </div>
      )}

      {/* identity + trigger + the test patient the step tests run against */}
      <Card>
        <CardContent className="grid gap-3 pt-4 md:grid-cols-2">
          <div className="space-y-1"><Label>Name</Label><Input value={d.name ?? ""} onChange={(e) => set("name", e.target.value)} /></div>
          <div className="space-y-1"><Label>Category</Label><Input value={d.category ?? ""} onChange={(e) => set("category", e.target.value)} /></div>
          <div className="space-y-1 md:col-span-2"><Label>Description</Label><Input value={d.description ?? ""} onChange={(e) => set("description", e.target.value)} /></div>
          <div className="grid grid-cols-3 gap-3 md:col-span-1">
            <div className="space-y-1">
              <Label className="flex items-center gap-1"><Zap className="h-3 w-3" />Trigger</Label>
              <select className="h-9 w-full rounded-md border bg-background px-2 text-sm" value={d.trigger?.type ?? "manual"} onChange={(e) => set("trigger", { ...d.trigger, type: e.target.value })}>
                {TRIGGER_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
              </select>
            </div>
            <div className="space-y-1">
              <Label>Resource</Label>
              <select className="h-9 w-full rounded-md border bg-background px-2 text-sm" value={d.trigger?.resourceType ?? ""} onChange={(e) => set("trigger", { ...d.trigger, resourceType: e.target.value || null })}>
                <option value="">—</option>
                {(opts?.fhirTypes ?? []).map((t) => <option key={t} value={t}>{t}</option>)}
              </select>
            </div>
            <div className="space-y-1"><Label>Condition</Label><Input value={d.trigger?.condition ?? ""} onChange={(e) => set("trigger", { ...d.trigger, condition: e.target.value })} /></div>
          </div>
          <div className="space-y-1">
            <Label className="flex items-center gap-1"><FlaskConical className="h-3 w-3" />Test patient <span className="font-normal text-muted-foreground">— step tests run against this record</span></Label>
            <select className="h-9 w-full rounded-md border bg-background px-2 text-sm" value={testPatient} onChange={(e) => pickTestPatient(e.target.value)}>
              {testPatient && !patients.some((p) => p.ref === testPatient) && <option value={testPatient}>{testPatient}</option>}
              {patients.map((p) => <option key={p.ref} value={p.ref}>{p.label} ({p.ref})</option>)}
            </select>
          </div>
        </CardContent>
      </Card>

      {/* ---------- the pipeline ---------- */}
      <div>
        {steps.map((s) => {
          stepNo += 1;
          const n = stepNo;
          const st = tests[s.key];
          const isOpen = !!open[s.key];
          const toggle = () => {
            setOpen((p) => ({ ...p, [s.key]: !p[s.key] }));
            if (s.kind === "source") void ensureDraft(s.slug);
          };

          if (s.kind === "inputs") {
            const summary = (d.inputs ?? []).map((i) => i.key + (i.required ? "*" : "")).join(", ") || "none";
            return (
              <StepShell key={s.key} n={n} kind="inputs" summary={summary} open={isOpen} onToggle={toggle}>
                <div className="space-y-2">
                  {(d.inputs ?? []).map((inp, i) => (
                    <div key={i} className="grid items-end gap-2 rounded-md border p-2.5 md:grid-cols-[1fr,1fr,1fr,1fr,auto,auto]">
                      <div className="space-y-1"><Label className="text-xs">Key</Label><Input value={inp.key ?? ""} onChange={(e) => setInput(i, { key: e.target.value })} /></div>
                      <div className="space-y-1">
                        <Label className="text-xs">Type</Label>
                        <select className="h-9 w-full rounded-md border bg-background px-3 text-sm" value={inp.type ?? "text"} onChange={(e) => setInput(i, { type: e.target.value as InputField["type"] })}>
                          {INPUT_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
                        </select>
                      </div>
                      <div className="space-y-1"><Label className="text-xs">Label</Label><Input value={inp.label ?? ""} onChange={(e) => setInput(i, { label: e.target.value })} /></div>
                      <div className="space-y-1"><Label className="text-xs">Default</Label><Input value={(inp.default as string) ?? ""} onChange={(e) => setInput(i, { default: e.target.value })} /></div>
                      <label className="flex items-center gap-1.5 pb-2 text-xs"><input type="checkbox" className="h-3.5 w-3.5" checked={!!inp.required} onChange={(e) => setInput(i, { required: e.target.checked })} />required</label>
                      <Button variant="ghost" size="sm" onClick={() => set("inputs", (d.inputs ?? []).filter((_, j) => j !== i))} title="Remove input"><Trash2 className="h-4 w-4 text-muted-foreground" /></Button>
                    </div>
                  ))}
                  <Button variant="outline" size="sm" onClick={() => set("inputs", [...(d.inputs ?? []), { key: "", type: "text", label: "", required: false, default: "" } as InputField])}>
                    <Plus className="mr-1 h-4 w-4" />Add input
                  </Button>
                </div>
              </StepShell>
            );
          }

          if (s.kind === "fhir") {
            const summary = (d.evidence.fhir ?? []).join(" · ");
            return (
              <StepShell key={s.key} n={n} kind="fhir" summary={summary} state={st} open={isOpen} onToggle={toggle}
                onRemove={() => setEv({ fhir: [] })}>
                <div className="space-y-3">
                  <div className="flex flex-wrap gap-1.5">
                    {(opts?.fhirTypes ?? d.evidence.fhir ?? []).map((t) => {
                      const on = (d.evidence.fhir ?? []).includes(t);
                      return (
                        <button key={t} type="button"
                          onClick={() => setEv({ fhir: on ? (d.evidence.fhir ?? []).filter((x) => x !== t) : [...(d.evidence.fhir ?? []), t] })}
                          className={`rounded-full border px-2.5 py-1 text-xs font-medium transition-colors ${on ? "border-primary bg-primary text-primary-foreground" : "text-muted-foreground hover:bg-secondary"}`}>
                          {t}
                        </button>
                      );
                    })}
                  </div>
                  <Button variant="secondary" size="sm" disabled={st?.running || !testPatient}
                    onClick={() => runTest(s.key, { kind: "fhir", resourceTypes: d.evidence.fhir })}>
                    <PlayCircle className="mr-1 h-4 w-4" />Test step
                  </Button>
                  {st?.res && <TestResultBody res={st.res} />}
                  {st?.res?.error && <p className="text-sm text-destructive">{st.res.error}</p>}
                </div>
              </StepShell>
            );
          }

          if (s.kind === "sql") {
            return (
              <StepShell key={s.key} n={n} kind="sql" summary={s.name} state={st} open={isOpen} onToggle={toggle}
                onRemove={() => setEv({ sql: (d.evidence.sql ?? []).filter((_, j) => j !== s.index) })}>
                <div className="space-y-3">
                  <div className="space-y-1">
                    <Label>Named query <span className="font-normal text-muted-foreground">— structured facts over the FHIR repository</span></Label>
                    <select className="h-9 w-full rounded-md border bg-background px-3 text-sm" value={s.name}
                      onChange={(e) => { const sql = [...(d.evidence.sql ?? [])]; sql[s.index] = e.target.value; setEv({ sql }); }}>
                      {(opts?.sqlQueries ?? [s.name]).map((q) => <option key={q} value={q}>{q}</option>)}
                    </select>
                  </div>
                  <Button variant="secondary" size="sm" disabled={st?.running || !testPatient}
                    onClick={() => runTest(s.key, { kind: "sql-named", name: s.name })}>
                    <PlayCircle className="mr-1 h-4 w-4" />Test step
                  </Button>
                  {st?.res && <TestResultBody res={st.res} />}
                  {st?.res?.error && <p className="text-sm text-destructive">{st.res.error}</p>}
                </div>
              </StepShell>
            );
          }

          if (s.kind === "vector") {
            return (
              <StepShell key={s.key} n={n} kind="vector" summary={`${s.collection} · top ${d.evidence.vectorTopK ?? 3}`} state={st} open={isOpen} onToggle={toggle}
                onRemove={() => setEv({ vector: (d.evidence.vector ?? []).filter((_, j) => j !== s.index) })}>
                <div className="space-y-3">
                  <div className="grid gap-3 md:grid-cols-3">
                    <div className="space-y-1">
                      <Label>Collection <span className="font-normal text-muted-foreground">— native IRIS Vector Search</span></Label>
                      <select className="h-9 w-full rounded-md border bg-background px-3 text-sm" value={s.collection}
                        onChange={(e) => { const vector = [...(d.evidence.vector ?? [])]; vector[s.index] = e.target.value; setEv({ vector }); }}>
                        {(opts?.vectorCollections ?? [s.collection]).map((c) => <option key={c} value={c}>{c}</option>)}
                      </select>
                    </div>
                    <div className="space-y-1">
                      <Label>Query built from</Label>
                      <select className="h-9 w-full rounded-md border bg-background px-3 text-sm" value={d.evidence.vectorQueryFrom ?? ""}
                        onChange={(e) => setEv({ vectorQueryFrom: e.target.value })}>
                        {VECTOR_QUERY_MODES.map((m) => <option key={m.value} value={m.value}>{m.label}</option>)}
                      </select>
                    </div>
                    <div className="space-y-1">
                      <Label>Top K chunks</Label>
                      <Input type="number" min={1} max={12} value={d.evidence.vectorTopK ?? 3} onChange={(e) => setEv({ vectorTopK: Number(e.target.value) || 3 })} />
                    </div>
                  </div>
                  {(d.evidence.vector ?? []).length > 1 && (
                    <p className="text-xs text-muted-foreground">Query mode and Top K apply to every semantic-search step in this agent.</p>
                  )}
                  <Button variant="secondary" size="sm" disabled={st?.running || !testPatient}
                    onClick={() => runTest(s.key, { kind: "vector", collection: s.collection, queryFrom: d.evidence.vectorQueryFrom ?? "", topK: d.evidence.vectorTopK ?? 3, description: d.description })}>
                    <PlayCircle className="mr-1 h-4 w-4" />Test step
                  </Button>
                  {st?.res && <TestResultBody res={st.res} />}
                  {st?.res?.error && <p className="text-sm text-destructive">{st.res.error}</p>}
                </div>
              </StepShell>
            );
          }

          if (s.kind === "source") {
            const draft = drafts[s.slug];
            const custom = draft && !draft.readonly;
            const libName = (opts?.evidenceSources ?? []).find((x) => x.slug === s.slug)?.name;
            return (
              <StepShell key={s.key} n={n} kind="source" summary={draft?.name ?? libName ?? s.slug} state={st} open={isOpen} onToggle={toggle}
                onRemove={() => setEv({ sources: (d.evidence.sources ?? []).filter((_, j) => j !== s.index) })}>
                <div className="space-y-3">
                  {!draft?.loaded && <p className="text-sm text-muted-foreground">Loading…</p>}
                  {draft?.loaded && custom && (
                    <>
                      <div className="space-y-1"><Label>Step name</Label>
                        <Input value={draft.name} onChange={(e) => setDrafts((p) => ({ ...p, [s.slug]: { ...p[s.slug], name: e.target.value, dirty: true } }))} />
                      </div>
                      <div className="space-y-1">
                        <Label>Read-only SQL <span className="font-normal text-muted-foreground">— {"{{patientRef}}"} and {"{{input.<key>}}"} are bound at run time; guarded read-only</span></Label>
                        <Textarea className="min-h-[120px] font-mono text-xs" value={draft.sql}
                          onChange={(e) => setDrafts((p) => ({ ...p, [s.slug]: { ...p[s.slug], sql: e.target.value, dirty: true } }))} />
                      </div>
                    </>
                  )}
                  {draft?.loaded && !custom && (
                    <p className="text-sm text-muted-foreground">
                      Library component <span className="font-medium text-foreground">{draft.name}</span> ({draft.kindLabel}) — executed by the Evidence Engine.
                      Manage it in <span className="font-medium">Evidence Sources</span>.
                    </p>
                  )}
                  <Button variant="secondary" size="sm" disabled={st?.running || !testPatient || !draft?.loaded}
                    onClick={() => custom
                      ? runTest(s.key, { kind: "source-spec", sourceKind: "sql", spec: { sql: draft!.sql } })
                      : runTest(s.key, { kind: "source", slug: s.slug })}>
                    <PlayCircle className="mr-1 h-4 w-4" />Test step
                  </Button>
                  {st?.res && <TestResultBody res={st.res} />}
                  {st?.res?.error && <p className="text-sm text-destructive">{st.res.error}</p>}
                </div>
              </StepShell>
            );
          }

          if (s.kind === "reason") {
            const pv = preview?.res;
            return (
              <StepShell key={s.key} n={n} kind="reason"
                summary={`${d.agent?.role || "—"} · ${d.agent?.outputSchema || "no contract"}`}
                state={pv ? { res: { ok: pv.ok, kind: "reason", ms: pv.ms, summary: "prompt assembled", error: pv.error } } : preview?.running ? { running: true } : undefined}
                open={isOpen} onToggle={toggle}>
                <div className="space-y-3">
                  <div className="space-y-1"><Label>Role / persona</Label><Input value={d.agent?.role ?? ""} onChange={(e) => set("agent", { ...d.agent, role: e.target.value })} /></div>
                  <div className="space-y-1"><Label>Instruction</Label><Textarea className="min-h-[100px]" value={d.agent?.instruction ?? ""} onChange={(e) => set("agent", { ...d.agent, instruction: e.target.value })} /></div>
                  <div className="space-y-1">
                    <Label>Output contract <span className="font-normal text-muted-foreground">— genuinely shapes the LLM's JSON at run time</span></Label>
                    <select className="h-9 w-full rounded-md border bg-background px-3 text-sm" value={d.agent?.outputSchema ?? ""} onChange={(e) => set("agent", { ...d.agent, outputSchema: e.target.value })}>
                      <option value="">— pick a contract (required) —</option>
                      {(opts?.outputSchemas ?? []).map((sc) => <option key={sc.slug} value={sc.slug}>{sc.slug} — {sc.name}</option>)}
                      {d.agent?.outputSchema && !schemaKnown && <option value={d.agent.outputSchema}>{d.agent.outputSchema} (not in library)</option>}
                    </select>
                    <p className="text-xs text-muted-foreground">Author or edit contracts under <span className="font-medium">Schemas</span> in the side nav.</p>
                  </div>
                  <div className="flex items-center gap-2">
                    <Button variant="secondary" size="sm" disabled={preview?.running || !testPatient} onClick={runPreview}>
                      <Eye className="mr-1 h-4 w-4" />Preview prompt
                    </Button>
                    <span className="text-xs text-muted-foreground">Gathers the evidence steps above and shows the exact messages the runtime will send. No AI call is made.</span>
                  </div>
                  {pv && pv.ok === 1 && (
                    <div className="space-y-2">
                      <div className="flex flex-wrap items-center gap-1.5 text-xs">
                        <Badge variant="secondary">assembled in {pv.ms} ms</Badge>
                        {Object.entries(pv.evidence ?? {}).filter(([k]) => k !== "vectorQueryText").map(([k, v]) => (
                          <Badge key={k} variant="outline">{k}: {String(v)}</Badge>
                        ))}
                      </div>
                      <div>
                        <p className="mb-1 text-xs font-medium text-muted-foreground">System message</p>
                        <pre className="max-h-44 overflow-auto whitespace-pre-wrap rounded bg-secondary/40 p-2 text-xs">{pv.system}</pre>
                      </div>
                      <div>
                        <p className="mb-1 text-xs font-medium text-muted-foreground">User message (the gathered evidence)</p>
                        <pre className="max-h-64 overflow-auto whitespace-pre-wrap rounded bg-secondary/40 p-2 text-xs">{pv.user}</pre>
                      </div>
                      <p className="text-xs text-muted-foreground">
                        Assembled by the same code path the runtime uses. <span className="font-medium">Run agent</span> sends it through the real
                        interoperability production (cached → live → deterministic, honestly badged).
                      </p>
                    </div>
                  )}
                  {pv?.error && <p className="text-sm text-destructive">{pv.error}</p>}
                </div>
              </StepShell>
            );
          }

          // action
          return (
            <StepShell key={s.key} n={n} kind="action"
              summary={`${d.action?.resourceType ?? "—"} · ${d.action?.approvalRequired ? "requires human review" : "no review"}`}
              open={isOpen} onToggle={toggle}
              onRemove={() => set("action", { type: "none", resourceType: null, approvalRequired: false })}>
              <div className="grid gap-3 md:grid-cols-3">
                <div className="space-y-1">
                  <Label>Drafted resource</Label>
                  <select className="h-9 w-full rounded-md border bg-background px-3 text-sm" value={d.action?.resourceType ?? ""} onChange={(e) => set("action", { ...d.action, resourceType: e.target.value || null })}>
                    {ACTION_RESOURCES.map((t) => <option key={t} value={t}>{t}</option>)}
                  </select>
                </div>
                <div className="flex items-end gap-2 pb-1">
                  <input id="approval" type="checkbox" className="h-4 w-4" checked={!!d.action?.approvalRequired} onChange={(e) => set("action", { ...d.action, approvalRequired: e.target.checked })} />
                  <Label htmlFor="approval">Requires human review</Label>
                </div>
                <p className="self-end pb-1 text-xs text-muted-foreground md:col-span-1">
                  Drafts are never auto-committed — a clinician approves or rejects each one.
                </p>
              </div>
            </StepShell>
          );
        })}

        {/* add-step palette */}
        <div className="relative pl-10">
          <div className="absolute left-0 top-1 flex h-6 w-6 items-center justify-center rounded-full border border-dashed text-muted-foreground"><Plus className="h-3.5 w-3.5" /></div>
          <div className="flex flex-wrap items-center gap-2 pb-2 pt-1">
            <span className="text-xs font-medium text-muted-foreground">Add step:</span>
            {canAddFhir && <Button variant="outline" size="sm" onClick={() => setEv({ fhir: ["Patient", "Condition", "Observation"] })}><Database className="mr-1 h-3.5 w-3.5" />FHIR record</Button>}
            <Button variant="outline" size="sm" onClick={addSql} disabled={!opts?.sqlQueries?.some((q) => !(d.evidence.sql ?? []).includes(q))}><Database className="mr-1 h-3.5 w-3.5" />Named query</Button>
            <Button variant="outline" size="sm" onClick={addCustomSql}><Database className="mr-1 h-3.5 w-3.5" />Custom SQL</Button>
            <Button variant="outline" size="sm" onClick={addVector} disabled={!opts?.vectorCollections?.some((c) => !(d.evidence.vector ?? []).includes(c))}><Search className="mr-1 h-3.5 w-3.5" />Semantic search</Button>
            <Button variant="outline" size="sm" onClick={addLibrarySource} disabled={!opts?.evidenceSources?.some((x) => !(d.evidence.sources ?? []).includes(x.slug))}><Boxes className="mr-1 h-3.5 w-3.5" />Library source</Button>
            {canAddAction && <Button variant="outline" size="sm" onClick={addAction}><FileEdit className="mr-1 h-3.5 w-3.5" />Draft action</Button>}
          </div>
          <p className="pb-2 text-xs text-muted-foreground">
            Evidence steps run before the AI step; the AI reasons over everything gathered. New evidence steps slot into pipeline order automatically.
          </p>
        </div>
      </div>

      <Dialog
        open={cloneOpen}
        onClose={() => setCloneOpen(false)}
        title="Clone agent"
        description="Create an editable copy under a new slug."
        footer={<><Button variant="outline" onClick={() => setCloneOpen(false)}>Cancel</Button><Button onClick={doClone}>Clone</Button></>}
      >
        <div className="space-y-3">
          <div className="space-y-1"><Label>New slug</Label><Input value={cloneSlug} onChange={(e) => setCloneSlug(e.target.value)} /></div>
          <div className="space-y-1"><Label>New name</Label><Input value={cloneName} onChange={(e) => setCloneName(e.target.value)} /></div>
        </div>
      </Dialog>
    </div>
  );
}
