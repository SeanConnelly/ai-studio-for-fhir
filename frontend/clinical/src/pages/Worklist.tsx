// The clinician's home. The landing view is a TABLE of worklists; clicking one
// opens that worklist's screen. Agent worklists list AI-surfaced findings (one
// row per patient). The Preventative care worklist is rule-driven: pick an
// AI-authored register (built in the Studio), "Find patients due", and the
// matching patients fill a table. The title stays pinned; the table scrolls with
// the page.
import { useEffect, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import {
  Loader2, ChevronRight, ChevronLeft, ClipboardList, Activity, ShieldCheck, HeartHandshake,
  RefreshCw, Users, Sparkles,
} from "lucide-react";
import { api } from "@shared/api/client";
import type { AgentResponse, CareRule, WorklistEntriesResult } from "@shared/api/types";
import { advisorySeverity, isRealAi, type Severity } from "@shared/lib/clinical";
import { WORKLIST, READMISSION_PATIENTS, RESULTS_PATIENTS, type WorklistQueue } from "@/agents";
import { Table, THead, TBody, TR, TH, TD } from "@shared/components/ui/table";

const SEV_DOT: Record<Severity, string> = { critical: "bg-rose-500", warning: "bg-amber-500", info: "bg-sky-500" };

interface Category {
  key: string;
  label: string;
  icon: typeof ClipboardList;
  kind: "agent" | "rules";
  group?: string;
  description: string;
}

const CATEGORIES: Category[] = [
  { key: "safety", label: "Results follow-up", icon: ClipboardList, kind: "agent", group: "Patient safety", description: "Every abnormal imaging and lab result tracked to closure — overdue, pending and closed loops." },
  { key: "discharges", label: "Readmission risk", icon: Activity, kind: "agent", group: "Recent discharges", description: "Every recently discharged patient, AI-scored and ranked by 30-day readmission risk." },
  { key: "preventative", label: "Preventative care", icon: ShieldCheck, kind: "rules", description: "AI-authored screening & monitoring registers — diabetes, breast screening, flu." },
  { key: "social", label: "Social needs", icon: HeartHandshake, kind: "agent", group: "Social needs", description: "Social-needs screening that flagged a barrier." },
];

function firstSentence(s?: string): string {
  if (!s) return "";
  const m = s.match(/^.*?[.!?](\s|$)/);
  return (m ? m[0] : s).trim();
}

// "7123987659" -> "712 398 7659"; pass-through if not a bare 10-digit number
function fmtNhs(nhs?: string): string {
  if (!nhs) return "";
  const s = nhs.replace(/\s/g, "");
  return s.length === 10 ? `${s.slice(0, 3)} ${s.slice(3, 6)} ${s.slice(6)}` : nhs;
}

/** Identifier line under a patient name: NHS number + MRN, like a real PAS list. */
function IdsLine({ nhsNo, mrn }: { nhsNo?: string; mrn?: string }) {
  if (!nhsNo && !mrn) return null;
  return (
    <span className="font-mono text-[11px] text-muted-foreground/80">
      {nhsNo ? `NHS ${fmtNhs(nhsNo)}` : ""}
      {nhsNo && mrn ? " · " : ""}
      {mrn ? `MRN ${mrn}` : ""}
    </span>
  );
}

function AgentRow({ q }: { q: WorklistQueue }) {
  const navigate = useNavigate();
  const id = q.patient.split("/")[1];
  const [name, setName] = useState<string>(id);
  const [ids, setIds] = useState<{ nhsNo?: string; mrn?: string }>({});
  const [resp, setResp] = useState<AgentResponse | null>(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    let alive = true;
    api.everything(q.patient).then((b) => { if (alive) { setName(b.patient || id); setIds({ nhsNo: b.nhsNo, mrn: b.hospitalNo || b.mrn }); } }).catch(() => {});
    api.runAgent(q.agent, { patient: q.patient, ...(q.inputs || {}) })
      .then((r) => alive && setResp(r)).catch(() => {}).finally(() => alive && setLoading(false));
    return () => { alive = false; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [q.key]);
  const sev = resp && isRealAi(resp) ? advisorySeverity(q.agent, resp) : "info";
  const finding = resp && isRealAi(resp) ? firstSentence(resp.summary) : "";
  return (
    <button onClick={() => navigate(`/patient/${id}?focus=${q.agent}`)} className="flex w-full items-start gap-3 rounded-lg border bg-card px-4 py-3 text-left transition-colors hover:border-nhs-300 hover:bg-nhs-50/40">
      <span className={`mt-1.5 h-2 w-2 shrink-0 rounded-full ${SEV_DOT[sev]}`} />
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-baseline gap-x-2"><span className="font-semibold text-foreground">{name}</span><IdsLine {...ids} /><span className="text-xs text-muted-foreground">· {q.title}</span></div>
        {loading ? <div className="mt-1 flex items-center gap-1.5 text-sm text-muted-foreground"><Loader2 className="h-3.5 w-3.5 animate-spin" /> Reviewing chart…</div>
          : <p className="mt-0.5 line-clamp-2 text-sm text-muted-foreground">{finding}</p>}
      </div>
      <ChevronRight className="mt-1 h-4 w-4 shrink-0 text-muted-foreground" />
    </button>
  );
}

/** The Results Follow-Up Tracker worklist: every patient with abnormal
 *  results, their loop states (overdue / pending / closed), worst-first. */
function ResultsPanel() {
  const navigate = useNavigate();
  const [rows, setRows] = useState<{ id: string; name: string; nhsNo?: string; mrn?: string; resp: AgentResponse }[] | null>(null);

  useEffect(() => {
    let alive = true;
    Promise.all(
      RESULTS_PATIENTS.map(async (s) => {
        const id = s.patient.split("/")[1];
        try {
          const [b, resp] = await Promise.all([
            api.everything(s.patient),
            api.runAgent("results-followup", { patient: s.patient, ...(s.inputs || {}) }),
          ]);
          return isRealAi(resp) ? { id, name: b.patient || id, nhsNo: b.nhsNo, mrn: b.hospitalNo || b.mrn, resp } : null;
        } catch { return null; }
      })
    ).then((r) => { if (alive) setRows(r.filter(Boolean) as { id: string; name: string; nhsNo?: string; mrn?: string; resp: AgentResponse }[]); });
    return () => { alive = false; };
  }, []);

  if (!rows) return <p className="flex items-center gap-2 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" /> Checking abnormal results for documented follow-up…</p>;

  const rank = (r: AgentResponse) => {
    const states = (r.trackedResults || []).map((t) => (t.followUpStatus || "").toLowerCase());
    return states.includes("overdue") ? 0 : states.includes("pending") ? 1 : 2;
  };
  const sorted = [...rows].sort((a, b) => rank(a.resp) - rank(b.resp));

  const chip = (s: string) => {
    const v = s.toLowerCase();
    return v === "closed" ? "bg-emerald-100 text-emerald-800" : v === "pending" ? "bg-amber-100 text-amber-800" : "bg-rose-100 text-rose-800";
  };

  return (
    <div className="space-y-3">
      <Table>
        <THead><TR><TH>Patient</TH><TH>Abnormal results</TH><TH>Loop status</TH><TH /></TR></THead>
        <TBody>
          {sorted.map((r) => (
            <TR key={r.id} className="cursor-pointer" onClick={() => navigate(`/patient/${r.id}?focus=results-followup`)}>
              <TD className="font-medium"><div className="flex flex-col">{r.name}<IdsLine nhsNo={r.nhsNo} mrn={r.mrn} /></div></TD>
              <TD className="max-w-[380px] text-muted-foreground">
                {(r.resp.trackedResults || []).map((t) => t.result).join("; ") || r.resp.summary}
              </TD>
              <TD>
                <span className="flex flex-wrap gap-1">
                  {(r.resp.trackedResults || []).map((t, i) => (
                    <span key={i} className={`rounded-full px-2 py-0.5 text-[11px] font-semibold capitalize ${chip(t.followUpStatus || "")}`}>{t.followUpStatus}</span>
                  ))}
                </span>
              </TD>
              <TD className="text-right"><ChevronRight className="ml-auto h-4 w-4 text-muted-foreground" /></TD>
            </TR>
          ))}
        </TBody>
      </Table>
      <p className="flex items-start gap-1.5 px-1 text-[11px] text-muted-foreground"><Sparkles className="mt-0.5 h-3 w-3 shrink-0 text-nhs-600" /> Loop states are AI-assessed from each patient's actual results and follow-up records — open a patient for the full tracker, outreach drafts, and one-click orders.</p>
    </div>
  );
}

/** The Readmission Risk Workbench worklist: every recently-discharged patient,
 *  scored by the agent and ranked high-to-low with a population summary. */
function ReadmissionPanel() {
  const navigate = useNavigate();
  const [rows, setRows] = useState<{ id: string; name: string; nhsNo?: string; mrn?: string; resp: AgentResponse }[] | null>(null);

  useEffect(() => {
    let alive = true;
    Promise.all(
      READMISSION_PATIENTS.map(async (s) => {
        const id = s.patient.split("/")[1];
        try {
          const [b, resp] = await Promise.all([
            api.everything(s.patient),
            api.runAgent("readmission-risk", { patient: s.patient }),
          ]);
          return isRealAi(resp) ? { id, name: b.patient || id, nhsNo: b.nhsNo, mrn: b.hospitalNo || b.mrn, resp } : null;
        } catch { return null; }
      })
    ).then((r) => { if (alive) setRows(r.filter(Boolean) as { id: string; name: string; nhsNo?: string; mrn?: string; resp: AgentResponse }[]); });
    return () => { alive = false; };
  }, []);

  if (!rows) return <p className="flex items-center gap-2 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" /> Scoring recently discharged patients…</p>;

  const sorted = [...rows].sort((a, b) => (b.resp.riskScore ?? 0) - (a.resp.riskScore ?? 0));
  const counts = { high: 0, moderate: 0, low: 0 } as Record<string, number>;
  sorted.forEach((r) => { const b = (r.resp.riskBand || "low").toLowerCase(); counts[b] = (counts[b] || 0) + 1; });

  const bandChip = (band?: string) => {
    const b = (band || "").toLowerCase();
    return b === "high" ? "bg-rose-100 text-rose-800" : b === "moderate" ? "bg-amber-100 text-amber-800" : "bg-emerald-100 text-emerald-800";
  };

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center gap-2 text-sm">
        <span className="text-muted-foreground">{sorted.length} recently discharged patients scored:</span>
        <span className="rounded-full bg-rose-100 px-2.5 py-0.5 text-xs font-semibold text-rose-800">{counts.high} high</span>
        <span className="rounded-full bg-amber-100 px-2.5 py-0.5 text-xs font-semibold text-amber-800">{counts.moderate} moderate</span>
        <span className="rounded-full bg-emerald-100 px-2.5 py-0.5 text-xs font-semibold text-emerald-800">{counts.low} low</span>
      </div>
      <Table>
        <THead><TR><TH>Patient</TH><TH>Risk</TH><TH>30-day est.</TH><TH>Top factors</TH><TH /></TR></THead>
        <TBody>
          {sorted.map((r) => (
            <TR key={r.id} className="cursor-pointer" onClick={() => navigate(`/patient/${r.id}?focus=readmission-risk`)}>
              <TD className="font-medium"><div className="flex flex-col">{r.name}<IdsLine nhsNo={r.nhsNo} mrn={r.mrn} /></div></TD>
              <TD>
                <span className={`inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-[11px] font-semibold capitalize ${bandChip(r.resp.riskBand)}`}>
                  {r.resp.riskBand}{typeof r.resp.riskScore === "number" ? ` · ${r.resp.riskScore}` : ""}
                </span>
              </TD>
              <TD className="text-muted-foreground">{r.resp.thirtyDayEstimate || "—"}</TD>
              <TD className="max-w-[420px] truncate text-muted-foreground">{(r.resp.riskDrivers || []).slice(0, 2).join("; ")}</TD>
              <TD className="text-right"><ChevronRight className="ml-auto h-4 w-4 text-muted-foreground" /></TD>
            </TR>
          ))}
        </TBody>
      </Table>
      <p className="flex items-start gap-1.5 px-1 text-[11px] text-muted-foreground"><Sparkles className="mt-0.5 h-3 w-3 shrink-0 text-nhs-600" /> Scores and factors are AI-generated from each patient's chart — open a patient for the full breakdown and preventive actions.</p>
    </div>
  );
}

function PreventativePanel() {
  const navigate = useNavigate();
  const [rules, setRules] = useState<CareRule[] | null>(null);
  const [active, setActive] = useState<string>("");
  const [wl, setWl] = useState<WorklistEntriesResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [updating, setUpdating] = useState(false);

  const [loadError, setLoadError] = useState(false);

  useEffect(() => {
    api.careRules().then((r) => {
      setRules(r.rules || []);
      if (r.rules?.length) setActive(r.rules[0].slug);
    }).catch(() => { setRules([]); setLoadError(true); });
  }, []);

  useEffect(() => {
    if (!active) return;
    setLoading(true);
    setWl(null);
    api.ruleWorklist(active).then(setWl).catch(() => setLoadError(true)).finally(() => setLoading(false));
  }, [active]);

  async function update() {
    if (!active) return;
    setUpdating(true);
    try { setWl(await api.updateRuleWorklist(active)); } finally { setUpdating(false); }
  }

  if (loadError) {
    return (
      <p className="rounded-lg border border-amber-300 bg-amber-50/50 px-4 py-3 text-sm">
        The registers couldn't be loaded — the backend may be unavailable.{" "}
        <button onClick={() => window.location.reload()} className="font-medium text-nhs-700 underline">Try again</button>
      </p>
    );
  }
  if (!rules) return <p className="flex items-center gap-2 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" /> Loading registers…</p>;
  const activeRule = rules.find((r) => r.slug === active);

  return (
    <div className="grid gap-5 lg:grid-cols-[265px,1fr]">
      {/* Left: the individual registers */}
      <aside className="lg:sticky lg:top-32 lg:self-start">
        <nav className="space-y-0.5">
          {rules.map((r) => (
            <button key={r.slug} onClick={() => setActive(r.slug)}
              className={"flex w-full items-center gap-2.5 rounded-md px-3 py-2 text-left text-sm font-medium transition-colors " + (r.slug === active ? "bg-nhs-600 text-white" : "text-foreground/70 hover:bg-nhs-50 hover:text-nhs-800")}>
              <ShieldCheck className="h-4 w-4 shrink-0" />
              <span className="flex-1 truncate">{r.name}</span>
            </button>
          ))}
        </nav>
        <p className="mt-3 flex items-start gap-1.5 px-1 text-[11px] text-muted-foreground"><Sparkles className="mt-0.5 h-3 w-3 shrink-0 text-nhs-600" /> AI-authored registers, built in the Studio.</p>
      </aside>

      {/* Right: the worklist table for the selected register */}
      <section className="min-w-0">
        <div className="mb-3 flex items-start gap-3">
          <div className="min-w-0 flex-1">
            <div className="font-semibold text-foreground">{activeRule?.name}</div>
            {activeRule?.description && <div className="text-sm text-muted-foreground">{activeRule.description}</div>}
          </div>
          <button onClick={update} disabled={updating || loading}
            className="inline-flex shrink-0 items-center gap-2 rounded-md bg-nhs-600 px-3 py-2 text-sm font-medium text-white hover:bg-nhs-700 disabled:opacity-60">
            {updating ? <Loader2 className="h-4 w-4 animate-spin" /> : <RefreshCw className="h-4 w-4" />}
            {updating ? "Updating…" : "Update worklist"}
          </button>
        </div>

        {typeof wl?.added === "number" && (
          <p className="mb-2 text-sm text-emerald-700">Added {wl.added} new patient{wl.added === 1 ? "" : "s"} to the worklist.</p>
        )}

        {loading ? (
          <p className="flex items-center gap-2 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" /> Loading worklist…</p>
        ) : !wl || wl.entries.length === 0 ? (
          <p className="text-sm text-muted-foreground">No outstanding work items. Use "Update worklist" to find patients who now meet this rule.</p>
        ) : (
          <>
            <div className="mb-1.5 flex items-center gap-1.5 text-sm text-muted-foreground"><Users className="h-4 w-4" /> {wl.count} outstanding</div>
            <Table>
              <THead><TR><TH>Patient</TH><TH>What's due</TH><TH /></TR></THead>
              <TBody>
                {wl.entries.map((p) => (
                  <TR key={p.ref} className="cursor-pointer" onClick={() => navigate(`/patient/${p.id}`)}>
                    <TD className="font-medium">{p.name}</TD>
                    <TD className="text-muted-foreground">{p.detail}</TD>
                    <TD className="text-right"><ChevronRight className="ml-auto h-4 w-4 text-muted-foreground" /></TD>
                  </TR>
                ))}
              </TBody>
            </Table>
          </>
        )}
      </section>
    </div>
  );
}

export function Worklist() {
  const navigate = useNavigate();
  // ?list=<key> deep-links straight into one worklist (used by "The demo" guide)
  const [searchParams, setSearchParams] = useSearchParams();
  const view = searchParams.get("list");
  const setView = (key: string | null) => setSearchParams(key ? { list: key } : {}, { replace: false });
  const cat = view ? CATEGORIES.find((c) => c.key === view) : null;

  // Landing: the worklists as a table.
  if (!cat) {
    return (
      <div className="space-y-4">
        <div>
          <h1 className="text-xl font-semibold">Worklists</h1>
          <p className="text-sm text-muted-foreground">Choose a worklist to review. Each surfaces work across your patient panel.</p>
        </div>
        <Table>
          <THead><TR><TH>Worklist</TH><TH>What it covers</TH><TH>Type</TH><TH /></TR></THead>
          <TBody>
            {CATEGORIES.map((c) => (
              <TR key={c.key} className="cursor-pointer" onClick={() => setView(c.key)}>
                <TD className="font-medium">
                  <span className="inline-flex items-center gap-2"><c.icon className="h-4 w-4 text-nhs-600" />{c.label}</span>
                </TD>
                <TD className="text-muted-foreground">{c.description}</TD>
                <TD>
                  <span className="rounded-full bg-secondary px-2 py-0.5 text-[11px] font-medium text-muted-foreground">{c.kind === "rules" ? "Rule-based" : "AI agent"}</span>
                </TD>
                <TD className="text-right"><ChevronRight className="ml-auto h-4 w-4 text-muted-foreground" /></TD>
              </TR>
            ))}
          </TBody>
        </Table>
      </div>
    );
  }

  // Detail: a single worklist. Title pinned; content scrolls with the page.
  const agentQueues = cat.kind === "agent" ? WORKLIST.filter((q) => q.group === cat.group) : [];
  return (
    <div className="-mt-6">
      <div className="sticky top-0 z-20 bg-background pb-3 pt-3">
        <button onClick={() => setView(null)} className="mb-1 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
          <ChevronLeft className="h-4 w-4" /> Worklists
        </button>
        <h1 className="flex items-center gap-2 text-xl font-semibold"><cat.icon className="h-5 w-5 text-nhs-600" /> {cat.label} worklist</h1>
      </div>
      <div className="pb-6">
        {cat.kind === "rules" ? (
          <PreventativePanel />
        ) : cat.key === "discharges" ? (
          <ReadmissionPanel />
        ) : cat.key === "safety" ? (
          <ResultsPanel />
        ) : (
          <div className="space-y-2">
            {agentQueues.map((q) => <AgentRow key={q.key} q={q} />)}
          </div>
        )}
      </div>
    </div>
  );
}
