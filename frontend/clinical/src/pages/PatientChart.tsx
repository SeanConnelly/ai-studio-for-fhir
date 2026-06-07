// Patient chart - a single scrolling clinical record. A fixed Storyboard banner
// and a fixed left "table of contents" stay put; only the record scrolls (behind
// padding around the banner, never flush against it). AI-generated content (the
// Smart Summary narrative and its recommended actions) lives in clearly-labelled
// AI cards, kept separate from the real chart data (Problems, Medications, ...).
// No developer/technical detail is shown - that lives in the Studio.
import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { useParams, useSearchParams } from "react-router-dom";
import {
  Loader2, Sparkles, Lightbulb, ClipboardList, Pill, TriangleAlert, Activity,
  FlaskConical, CalendarDays, Syringe, Stethoscope, Target, ClipboardPlus, ShieldCheck, Compass, HeartHandshake, Microscope, MessageSquareText,
} from "lucide-react";
import { api } from "@shared/api/client";
import type { AgentResponse, EverythingBundle, PreventativeResult } from "@shared/api/types";
import { isRealAi } from "@shared/lib/clinical";
import { PatientBanner } from "@shared/components/clinical";
import { AdvisoryCard } from "@shared/components/clinical/AdvisoryCard";
import { ChartMenu, type ChartMenuItem } from "@/components/ChartMenu";
import { OrdersSection } from "@/components/OrdersSection";
import { PreventativeSection } from "@/components/PreventativeSection";
import { CarePlanNavigator } from "@/components/CarePlanNavigator";
import { SocialCareSection } from "@/components/SocialCareSection";
import { TrialsSection } from "@/components/TrialsSection";
import { ChartAgentSection } from "@/components/ChartAgentSection";
import { ReadmissionSection } from "@/components/ReadmissionSection";
import { ResultsFollowUpSection } from "@/components/ResultsFollowUpSection";
import { LabExplainerSection } from "@/components/LabExplainerSection";
import { hasScenario } from "@/agents";

type SecKey =
  | "summary" | "recommendations" | "problems" | "medications" | "allergies"
  | "vitals" | "results" | "results-fu" | "med-safety" | "lab-explainer" | "encounters" | "orders" | "preventative" | "social" | "trials" | "readmission" | "recent-triage" | "immunisations" | "procedures" | "documents" | "careplan" | "care-navigator";

interface SecDef { key: SecKey; label: string; icon: ChartMenuItem["icon"]; ai?: boolean; core?: boolean; }

// The chart's table of contents. Core clinical sections always appear; optional
// ones only when the record has data. AI sections are flagged.
const SECTIONS: SecDef[] = [
  { key: "summary", label: "Summary", icon: Sparkles, ai: true },
  { key: "readmission", label: "Readmission risk", icon: Activity, ai: true },
  { key: "recommendations", label: "Recommended actions", icon: Lightbulb, ai: true },
  { key: "problems", label: "Problems", icon: ClipboardList, core: true },
  { key: "medications", label: "Medications", icon: Pill, core: true },
  { key: "med-safety", label: "Medication safety", icon: ShieldCheck, ai: true },
  { key: "orders", label: "Orders", icon: ClipboardPlus, core: true },
  { key: "allergies", label: "Allergies", icon: TriangleAlert, core: true },
  { key: "vitals", label: "Vitals", icon: Activity, core: true },
  { key: "results", label: "Results", icon: FlaskConical, core: true },
  { key: "results-fu", label: "Results follow-up", icon: ClipboardList, ai: true },
  { key: "lab-explainer", label: "Results, explained", icon: Sparkles, ai: true },
  { key: "encounters", label: "Encounters", icon: CalendarDays, core: true },
  { key: "preventative", label: "Preventative care", icon: ShieldCheck, core: true },
  { key: "social", label: "Social care", icon: HeartHandshake, ai: true },
  { key: "trials", label: "Clinical trials", icon: Microscope, ai: true },
  { key: "recent-triage", label: "Recent triage", icon: MessageSquareText },
  { key: "careplan", label: "Care plan", icon: Target, core: true },
  { key: "care-navigator", label: "Care Plan Navigator", icon: Compass, ai: true, core: true },
  { key: "immunisations", label: "Immunisations", icon: Syringe },
  { key: "procedures", label: "Procedures", icon: Stethoscope },
  { key: "documents", label: "Documents", icon: ClipboardList },
];

const VITAL_HINTS = ["blood pressure", "body mass", "pulse", "heart rate", "temperature", "respiratory", "oxygen satur"];
const isVital = (s: string) => VITAL_HINTS.some((h) => s.toLowerCase().includes(h));
const isAbnormal = (s: string) => /\[(hh?|ll?)\]/i.test(s);

// Which chart section a worklist deep-link (?focus=<agent>) should land on.
const FOCUS_SECTION: Record<string, SecKey> = {
  "sdoh-referral": "social",
  "gaps-in-care": "preventative",
  "care-plan-navigator": "care-navigator",
  "clinical-trial-matcher": "trials",
  "medication-safety": "med-safety",
  "lab-explainer": "lab-explainer",
  "smart-patient-summary": "summary",
  "readmission-risk": "readmission",
  "results-followup": "results-fu",
};

export function PatientChart() {
  const { id = "" } = useParams();
  const ref = `Patient/${id}`;
  const [searchParams] = useSearchParams();
  // ?focus= accepts an agent slug (mapped) or a section key directly
  const focusRaw = searchParams.get("focus") || "";
  const focusKey = FOCUS_SECTION[focusRaw] || (SECTIONS.some((s) => s.key === focusRaw) ? (focusRaw as SecKey) : undefined);

  const [bundle, setBundle] = useState<EverythingBundle | null>(null);
  const [bundleError, setBundleError] = useState(false);
  const [summary, setSummary] = useState<AgentResponse | null>(null);
  const [summaryLoading, setSummaryLoading] = useState(true);
  const [prevent, setPrevent] = useState<PreventativeResult | null>(null);
  const [activeKey, setActiveKey] = useState<SecKey>("summary");

  const bandRef = useRef<HTMLDivElement>(null);
  const [bandH, setBandH] = useState(120);

  useEffect(() => {
    setBundle(null);
    setSummary(null);
    setSummaryLoading(true);
    setPrevent(null);
    bandRef.current?.closest("main")?.scrollTo({ top: 0 });
    setBundleError(false);
    api.everything(ref).then(setBundle).catch(() => setBundleError(true));
    api.patientPreventative(id).then(setPrevent).catch(() => {});
    api
      .runAgent("smart-patient-summary", { patient: ref })
      .then(setSummary)
      .catch(() => setSummary(null))
      .finally(() => setSummaryLoading(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  // Measure the sticky banner band so the menu sits just beneath it and section
  // jumps / scroll-spy align to the same line.
  useLayoutEffect(() => {
    if (!bandRef.current) return;
    const measure = () => setBandH(bandRef.current!.offsetHeight);
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(bandRef.current);
    return () => ro.disconnect();
  }, [bundle, summary]);

  const sec = bundle?.sections ?? {};
  const obs = sec["Observation"] ?? [];
  const vitals = useMemo(() => obs.filter(isVital), [bundle]);
  const labs = useMemo(() => obs.filter((o) => !isVital(o)), [bundle]);
  // QuestionnaireResponses split by kind: social-needs screenings vs saved triage conversations
  const qrs = sec["QuestionnaireResponse"] ?? [];
  const screenings = useMemo(() => qrs.filter((q) => q.startsWith("Social needs screening")), [bundle]);
  const triageSessions = useMemo(() => qrs.filter((q) => q.startsWith("Triage conversation")), [bundle]);

  const aiSummary = summary && isRealAi(summary) ? summary : null;
  const recs = aiSummary?.recommendations ?? [];

  const itemsFor = useCallback(
    (key: SecKey): string[] => {
      switch (key) {
        case "problems": return sec["Condition"] ?? [];
        case "medications": return sec["MedicationRequest"] ?? [];
        case "allergies": return sec["AllergyIntolerance"] ?? [];
        case "vitals": return vitals;
        case "results": return [...labs, ...(sec["DiagnosticReport"] ?? [])];
        case "encounters": return sec["Encounter"] ?? [];
        case "immunisations": return sec["Immunization"] ?? [];
        case "procedures": return sec["Procedure"] ?? [];
        case "documents": return sec["DocumentReference"] ?? [];
        case "careplan": return sec["CarePlan"] ?? [];
        default: return [];
      }
    },
    [bundle, vitals, labs]
  );

  const visible = useMemo(
    () =>
      SECTIONS.filter((s) => {
        if (s.key === "summary") return true;
        if (s.key === "recommendations") return recs.length > 0;
        // Social care appears only when the patient has a social-needs screening
        if (s.key === "social") return screenings.length > 0;
        // Recent triage appears once a conversation has been completed + saved
        if (s.key === "recent-triage") return triageSessions.length > 0;
        // Clinical trials only for patients with a cached match run
        if (s.key === "trials") return hasScenario(id, "clinical-trial-matcher");
        // in-chart decision support, only where a cached run exists
        if (s.key === "med-safety") return hasScenario(id, "medication-safety");
        if (s.key === "lab-explainer") return hasScenario(id, "lab-explainer");
        if (s.key === "readmission") return hasScenario(id, "readmission-risk");
        if (s.key === "results-fu") return hasScenario(id, "results-followup");
        if (s.core) return true;
        return itemsFor(s.key).length > 0;
      }),
    [bundle, summary, recs.length, itemsFor]
  );

  // Scroll-spy: the active section is the last one whose top has scrolled up to
  // the line just below the fixed banner band - i.e. the section currently at the
  // top of the record. Same line the jumps land on, so click + highlight agree.
  useEffect(() => {
    const scroller = bandRef.current?.closest("main");
    if (!scroller) return;
    const onScroll = () => {
      const line = scroller.getBoundingClientRect().top + bandH + 8;
      let cur: SecKey | undefined = visible[0]?.key;
      for (const s of visible) {
        const el = document.getElementById("sec-" + s.key);
        if (el && el.getBoundingClientRect().top <= line + 4) cur = s.key;
      }
      if (cur) setActiveKey(cur);
    };
    onScroll();
    scroller.addEventListener("scroll", onScroll, { passive: true });
    return () => scroller.removeEventListener("scroll", onScroll);
  }, [visible, bandH]);

  const jump = useCallback((key: string) => {
    const el = document.getElementById("sec-" + key);
    if (el) {
      setActiveKey(key as SecKey);
      el.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }, []);

  // Worklist deep-link: once the chart has rendered, land on the focused section.
  useEffect(() => {
    if (!focusKey || !bundle) return;
    const t = setTimeout(() => jump(focusKey), 150);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [focusKey, bundle]);

  function renderSection(s: SecDef): ReactNode {
    const anchor = { scrollMarginTop: bandH + 8 };

    if (s.key === "summary") {
      return (
        <section id="sec-summary" key="summary" style={anchor}>
          {aiSummary ? (
            <AdvisoryCard title="Smart patient summary" accent={false} summary={aiSummary.summary} />
          ) : summaryLoading ? (
            <div className="flex items-center gap-2 rounded-lg border bg-card px-4 py-3 text-sm text-muted-foreground shadow-sm">
              <Loader2 className="h-4 w-4 animate-spin" /> Preparing summary…
            </div>
          ) : (
            <div className="rounded-lg border bg-card px-4 py-3 text-sm text-muted-foreground shadow-sm">
              An AI summary hasn't been generated for this patient — the record sections below are complete.
              Pre-generated summaries cover the demo cohort; connecting an AI key in the Studio's Admin
              generates one live for any patient.
            </div>
          )}
        </section>
      );
    }

    if (s.key === "recommendations") {
      return (
        <section id="sec-recommendations" key="recommendations" style={anchor}>
          <AdvisoryCard title="Recommended next steps" accent={false}>
            <div className="space-y-1.5">
              {recs.map((r, i) => (
                <div key={i} className="flex items-start gap-2.5 text-sm">
                  <span
                    className={
                      "inline-flex w-16 shrink-0 justify-center rounded-full px-2 py-0.5 text-[11px] font-medium capitalize " +
                      (["urgent", "high"].includes((r.priority || "").toLowerCase())
                        ? "bg-amber-100 text-amber-800"
                        : "bg-sky-100 text-sky-800")
                    }
                  >
                    {r.priority}
                  </span>
                  <span>
                    {r.text} {r.owner && <span className="text-muted-foreground">({r.owner})</span>}
                  </span>
                </div>
              ))}
            </div>
          </AdvisoryCard>
        </section>
      );
    }

    if (s.key === "orders") {
      return (
        <section id="sec-orders" key="orders" style={anchor}>
          <OrdersSection patientId={id} />
        </section>
      );
    }

    if (s.key === "preventative") {
      return (
        <section id="sec-preventative" key="preventative" style={anchor}>
          <PreventativeSection patientId={id} items={prevent?.overdue || []} />
        </section>
      );
    }

    if (s.key === "social") {
      return (
        <section id="sec-social" key="social" style={anchor}>
          <SocialCareSection patientId={id} screening={screenings} />
        </section>
      );
    }

    if (s.key === "recent-triage") {
      // each display: "Triage conversation (date) | What brings you in today? -> ... | Q -> A | ..."
      return (
        <section id="sec-recent-triage" key="recent-triage" style={anchor}>
          <div className="rounded-lg border bg-card shadow-sm">
            <div className="flex items-center gap-2 border-b px-4 py-2.5 text-sm font-semibold">
              <MessageSquareText className="h-4 w-4 text-nhs-600" /> Recent triage
              <span className="ml-auto text-xs font-normal text-muted-foreground">{triageSessions.length}</span>
            </div>
            <div className="space-y-3 px-4 py-3">
              {triageSessions.map((t, i) => {
                const parts = t.split(" | ");
                const date = parts[0]?.match(/\(([\d-]+)\)/)?.[1] || "";
                const qa = parts.slice(1).map((p) => p.split(" -> "));
                return (
                  <div key={i} className="rounded-md border p-3 text-sm">
                    <div className="mb-1.5 flex items-center gap-2">
                      <span className="font-medium">Triage conversation</span>
                      {date && <span className="text-xs text-muted-foreground">{date}</span>}
                    </div>
                    <div className="space-y-1">
                      {qa.map(([q, a], j) => (
                        <div key={j} className="text-muted-foreground"><span className="text-foreground">{q}</span> — &ldquo;{a}&rdquo;</div>
                      ))}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </section>
      );
    }

    if (s.key === "trials") {
      return (
        <section id="sec-trials" key="trials" style={anchor}>
          <TrialsSection patientId={id} />
        </section>
      );
    }

    if (s.key === "readmission") {
      return (
        <section id="sec-readmission" key="readmission" style={anchor}>
          <ReadmissionSection patientId={id} onJump={jump} />
        </section>
      );
    }

    if (s.key === "results-fu") {
      return (
        <section id="sec-results-fu" key="results-fu" style={anchor}>
          <ResultsFollowUpSection patientId={id} />
        </section>
      );
    }

    if (s.key === "med-safety") {
      return (
        <section id="sec-med-safety" key="med-safety" style={anchor}>
          <ChartAgentSection patientId={id} agent="medication-safety" title="Medication safety review" />
        </section>
      );
    }

    if (s.key === "lab-explainer") {
      return (
        <section id="sec-lab-explainer" key="lab-explainer" style={anchor}>
          <LabExplainerSection patientId={id} />
        </section>
      );
    }

    if (s.key === "care-navigator") {
      return (
        <section id="sec-care-navigator" key="care-navigator" style={anchor}>
          <CarePlanNavigator patientId={id} />
        </section>
      );
    }

    const items = itemsFor(s.key);
    const Icon = s.icon;
    const highlight = s.key === "results" || s.key === "vitals";
    return (
      <section id={"sec-" + s.key} key={s.key} style={anchor}>
        <div className="rounded-lg border bg-card shadow-sm">
          <div className="flex items-center gap-2 border-b px-4 py-2.5 text-sm font-semibold text-foreground">
            <Icon className="h-4 w-4 text-nhs-600" />
            {s.label}
            <span className="ml-auto text-xs font-normal text-muted-foreground">{items.length}</span>
          </div>
          <div className="px-4 py-3">
            {items.length ? (
              <ul className="space-y-1.5 text-sm">
                {items.map((it, i) => (
                  <li key={i} className="flex gap-2">
                    <span className={"mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full " + (highlight && isAbnormal(it) ? "bg-amber-500" : "bg-nhs-300")} />
                    <span className={highlight && isAbnormal(it) ? "text-amber-700" : ""}>{it}</span>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-sm text-muted-foreground">None recorded</p>
            )}
          </div>
        </div>
      </section>
    );
  }

  const menuItems: ChartMenuItem[] = visible.map((s) => ({
    key: s.key,
    label: s.label,
    icon: s.icon,
    ai: s.ai,
    badge: s.key === "preventative" ? (prevent?.count || 0) : 0,
  }));

  return (
    // -mt-6 cancels the shell's top padding so the banner band sits flush at the
    // top of the scroll area and never moves on scroll (it is sticky top-0).
    <div className="-mt-6">
      <div ref={bandRef} className="sticky top-0 z-20 bg-background pb-3 pt-3">
        <PatientBanner
          name={bundle?.patient || ref}
          gender={bundle?.gender}
          birthDate={bundle?.birthDate}
          nhsNo={bundle?.nhsNo}
          hospitalNo={bundle?.hospitalNo}
          address={bundle?.address}
          gp={bundle?.gp}
          allergies={sec["AllergyIntolerance"]}
          alerts={bundle?.alerts}
        />
      </div>

      <div className="grid gap-5 pb-6 lg:grid-cols-[210px,1fr]">
        <aside className="hidden lg:block">
          <div className="sticky" style={{ top: bandH }}>
            <ChartMenu items={menuItems} activeKey={activeKey} onJump={jump} />
          </div>
        </aside>
        <div className="min-w-0 space-y-5">
          {bundleError ? (
            <div className="rounded-lg border border-amber-300 bg-amber-50/50 px-4 py-3 text-sm">
              The chart couldn't be loaded — the backend may be unavailable.{" "}
              <button onClick={() => window.location.reload()} className="font-medium text-nhs-700 underline">Try again</button>
            </div>
          ) : !bundle ? (
            <p className="text-sm text-muted-foreground">Loading chart…</p>
          ) : (
            visible.map(renderSection)
          )}
        </div>
      </div>
    </div>
  );
}
