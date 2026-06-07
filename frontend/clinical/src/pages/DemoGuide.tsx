// "The demo" — the guided tour. All twelve AI use cases, each in an
// expandable card: what it does (in plain words anyone can follow), exactly
// where to click to see it working, what to notice while it runs, and an
// "under the hood" link into the developer Studio for the technically curious.
// Every link lands on real, cached-AI-backed demo data — no API key needed.
import { useEffect, useState, type ReactNode } from "react";
import { Link } from "react-router-dom";
import {
  Sparkles, ChevronDown, ExternalLink, ArrowRight, ListChecks, Activity,
  ShieldCheck, HeartHandshake, Pill, FlaskConical, Compass, Microscope,
  FileCheck2, Search, MessageSquareText, Smartphone, Wand2, FileText,
} from "lucide-react";
import { api } from "@shared/api/client";

// ---- the twelve use cases ----------------------------------------------------

interface Step {
  text: ReactNode;
}
interface Demo {
  n: number;
  key: string;
  icon: typeof Sparkles;
  title: string;
  tagline: string;
  what: string;
  steps: Step[];
  notice: string;
  studio: string; // agent slug for the under-the-hood link
}

/** A patient-name placeholder that fills in once the chart name loads. */
function P({ id, names }: { id: string; names: Record<string, string> }) {
  return <span className="font-medium">{names[id] || "the demo patient"}</span>;
}

function GoLink({ to, children }: { to: string; children: ReactNode }) {
  // The patient portal is "another app" (the simulated phone): open it in its
  // own NAMED tab so repeated clicks reuse one phone tab instead of stacking.
  if (to.startsWith("/portal")) {
    return (
      <a
        href={`/clinical/#${to}`}
        target="fast-phone"
        className="inline-flex items-center gap-1 rounded-md bg-nhs-50 px-2 py-0.5 font-medium text-nhs-700 hover:bg-nhs-100"
      >
        {children} <ArrowRight className="h-3.5 w-3.5" />
      </a>
    );
  }
  return (
    <Link
      to={to}
      className="inline-flex items-center gap-1 rounded-md bg-nhs-50 px-2 py-0.5 font-medium text-nhs-700 hover:bg-nhs-100"
    >
      {children} <ArrowRight className="h-3.5 w-3.5" />
    </Link>
  );
}

const PATIENT_IDS = ["syn-pat-0001", "syn-pat-0003", "syn-pat-0061", "syn-pat-0085", "syn-pat-0075", "pat-abnormal-001"];

function buildDemos(names: Record<string, string>): { group: string; blurb: ReactNode; demos: Demo[] }[] {
  return [
    {
      group: "Start at the worklists",
      blurb: "These agents watch the whole hospital and surface the patients who need attention — before anyone asks.",
      demos: [
        {
          n: 1, key: "results", icon: ListChecks,
          title: "Imaging & Results Follow-Up Tracker",
          tagline: "Tracks every abnormal result to closure — before someone falls through the cracks.",
          what: "Hospitals run thousands of tests and scans, and sometimes an abnormal one slips through without anyone booking the follow-up - a classic source of serious harm. This agent reads every abnormal imaging report and lab value, hunts the record for a follow-up plan that addresses each one, and grades every loop: overdue (red), pending (yellow), or safely closed (green).",
          steps: [
            { text: <>Open <GoLink to="/?list=safety">the Results follow-up worklist</GoLink> — four patients, worst first: an overdue <span className="font-medium">BI-RADS 4 mammogram</span> with no follow-up, an open high HbA1c, a lung nodule with a CT already planned, and a fully closed loop.</> },
            { text: <>Open <GoLink to="/patient/syn-pat-0003?focus=results-followup"><P id="syn-pat-0003" names={names} />'s tracker</GoLink> — it shows the suspicious mammogram, "None documented" for follow-up, an AI-drafted <span className="font-medium">message to the patient</span> and a <span className="font-medium">note to her clinician</span>, and a draft biopsy referral ready to sign.</> },
            { text: <>Press <span className="font-medium">Sign</span> — the order is committed to the real record with an audit trail, and the loop closes.</> },
          ],
          notice: "The green 'closed' rows matter as much as the red ones — the agent proves the loop is closed by citing the actual completed task, not by staying silent.",
          studio: "results-followup",
        },
        {
          n: 2, key: "readmission", icon: Activity,
          title: "Readmission Risk Workbench",
          tagline: "Scores every recently discharged patient before they bounce back.",
          what: "Patients discharged after a hospital stay sometimes end up back in within weeks. This agent reads each patient's discharge history, medications and test results, scores their 30-day readmission risk, and explains exactly why - so the care team can put support in place first.",
          steps: [
            { text: <>Open <GoLink to="/?list=discharges">the Readmission risk worklist</GoLink> — all twelve recently discharged patients, AI-scored and ranked high to low with a population summary.</> },
            { text: <>Click the top patient (<P id="syn-pat-0085" names={names} />) — her chart's <span className="font-medium">Readmission risk</span> section shows the score, the factor-by-factor breakdown (BNP, rising creatinine, repeat admissions…), and the AI's narrative.</> },
            { text: <>Press <span className="font-medium">Accept all &amp; create tasks</span> to turn the preventive plan into real tasks in the record — and note the one-click links into Medication safety and Social needs.</> },
          ],
          notice: "Every factor cites the actual value and date from the chart — and the green \"low\" factors are shown too, because reassurance is information.",
          studio: "readmission-risk",
        },
        {
          n: 3, key: "preventative", icon: ShieldCheck,
          title: "Preventative Care Registers",
          tagline: "AI writes the database query; the worklist fills itself.",
          what: "\"Find every diabetic whose blood test is overdue\" is normally a job for a database specialist. Here, a clinician describes the rule in plain English, the AI writes the safe, read-only SQL, and the register fills with matching patients - live, against 1,000 patients of real FHIR data.",
          steps: [
            { text: <>Open <GoLink to="/?list=preventative">the Preventative care worklist</GoLink> and pick a register on the left (diabetes, breast screening, flu).</> },
            { text: <>Press <span className="font-medium">Update worklist</span> — the AI-written rule runs against the live data and new matching patients append to the table.</> },
            { text: <>For the authoring side, open <a className="inline-flex items-center gap-1 rounded-md bg-nhs-50 px-2 py-0.5 font-medium text-nhs-700 hover:bg-nhs-100" href="/fhir-agent-studio/#/care-rules" target="fast-studio">Care Rules in the Studio <ExternalLink className="h-3.5 w-3.5" /></a> to see each rule's plain-English description next to the SQL the AI wrote.</> },
          ],
          notice: "The SQL is shown, validated read-only, and executed for real — not a canned list.",
          studio: "gaps-in-care",
        },
        {
          n: 4, key: "social", icon: HeartHandshake,
          title: "Social Prescribing Matcher",
          tagline: "Matches what patients say to real local help — by meaning, not keywords.",
          what: "Health isn't only medical: not affording food, or missing appointments because of transport, can matter more than any prescription. Patients answer a screening in their own words, and the agent matches those words to a directory of 40 local services using vector search - so \"skipping meals\" finds the meal-box service, not just anything labelled \"food\".",
          steps: [
            { text: <>Open <GoLink to="/?list=social">the Social needs worklist</GoLink> — <P id="syn-pat-0061" names={names} /> reported skipping meals and missing appointments.</> },
            { text: <>Click through to his chart's <span className="font-medium">Social care</span> section: his own words, the evidence-backed needs, and the matched services with a <span className="font-medium">Best match</span>.</> },
            { text: <>Sign the draft referral, then see the same offer the way the <GoLink to="/portal">patient sees it on their phone</GoLink> — warm, simple, with a one-tap reply.</> },
          ],
          notice: "Every identified need quotes its evidence — the patient's words or the missed appointments in the record. The services come only from the real directory; the AI cannot invent one.",
          studio: "sdoh-referral",
        },
      ],
    },
    {
      group: "Inside one patient's chart",
      blurb: <>Open {names["syn-pat-0001"] || "Archie Patel"}'s chart once and five agents go to work in their own sections.</>,
      demos: [
        {
          n: 5, key: "summary", icon: FileText,
          title: "Smart Patient Summary",
          tagline: "The whole chart, read and retold as a clinician's handover note.",
          what: "Instead of a clinician spending ten minutes piecing together problems, medications and results, the agent reads the entire record and writes the kind of summary an experienced doctor would hand over - citing the real numbers and dates as it goes.",
          steps: [
            { text: <>Open <GoLink to="/patient/syn-pat-0001">{names["syn-pat-0001"] || "the flagship patient"}'s chart</GoLink> — the summary is the first card and writes itself on arrival.</> },
            { text: <>Cross-check it: every value it quotes (HbA1c 11.4%, LDL 205…) is in the data sections below.</> },
          ],
          notice: "AI content always sits in clearly-labelled AI cards, separate from the real chart data.",
          studio: "smart-patient-summary",
        },
        {
          n: 6, key: "medsafety", icon: Pill,
          title: "Medication Safety Review",
          tagline: "A second pair of eyes across the whole medication list.",
          what: "The agent reviews everything the patient takes against their conditions and kidney function, looking for interactions, duplications and doses that need adjusting - and says clearly when everything is fine, which matters just as much.",
          steps: [
            { text: <>On the same chart, jump to <GoLink to="/patient/syn-pat-0001?focus=med-safety">Medication safety</GoLink> from the left-hand menu.</> },
          ],
          notice: "An honest \"no issues found\" is shown as exactly that — the agent never manufactures drama.",
          studio: "medication-safety",
        },
        {
          n: 7, key: "labs", icon: FlaskConical,
          title: "Lab Results, Explained",
          tagline: "Lab numbers become colour bars, trends, and words a patient can understand.",
          what: "An HbA1c of 11.4% means little to most people. This agent turns each result into a colour-coded range bar, a plain-language meaning grounded in trusted patient-education content, the trend across their real readings, practical suggestions, and questions to take to the doctor.",
          steps: [
            { text: <>Jump to <GoLink to="/patient/syn-pat-0001?focus=lab-explainer">Results, explained</GoLink> on the chart — the clinician previews exactly what the patient will see, then presses <span className="font-medium">Approve &amp; send</span>.</> },
            { text: <>See the patient side: open <GoLink to="/portal">the phone app</GoLink> and tap the <span className="font-medium">Results</span> tab — every demo patient has their own explanation, with the trend sparkline drawn from their real readings.</> },
          ],
          notice: "The explanations are grounded in vetted patient-education extracts retrieved by vector search for THIS patient's abnormal results — and the trend cites their actual prior values.",
          studio: "lab-explainer",
        },
        {
          n: 8, key: "careplan", icon: Compass,
          title: "Care Plan Navigator",
          tagline: "Where the care plan stands, what's overdue, and what to do next.",
          what: "Care plans drift: tasks go overdue, goals slip off track. The navigator reads the plan, the goals and the diary, then lays out what's going well, what's behind, and the next steps - with new tasks it proposes, each with its reasoning. One click turns accepted tasks into real entries in the record.",
          steps: [
            { text: <>Jump to <GoLink to="/patient/syn-pat-0001?focus=care-navigator">Care Plan Navigator</GoLink> — note the overdue items and the AI-suggested tasks with their "why".</> },
            { text: <>Press <span className="font-medium">Accept &amp; create tasks</span> to commit them, then see the patient-facing version on <GoLink to="/portal">the phone app</GoLink> — same plan, warm plain language, progress bars.</> },
          ],
          notice: "Clinician view and patient view are deliberately different renderings of the same AI run.",
          studio: "care-plan-navigator",
        },
        {
          n: 9, key: "trials", icon: Microscope,
          title: "Clinical Trial Matcher",
          tagline: "Grades a patient against a trial registry — and asks for what's missing.",
          what: "Matching patients to research trials normally means a coordinator reading pages of eligibility criteria. The agent retrieves the right trials for this patient's profile, grades each one likely / maybe / unlikely with the criteria it checked, flags problems like medication washouts - and when information is missing, it asks.",
          steps: [
            { text: <>Open the <GoLink to="/trials">Trials</GoLink> page with {names["syn-pat-0001"] || "the flagship patient"} selected. Note CARDIA-DM2 is <span className="font-medium">unlikely</span> purely because of his age — the criteria are checked arithmetically.</> },
            { text: <>Scroll to <span className="font-medium">"The agent needs more information"</span>, press <span className="font-medium">Use example answer</span>, then <span className="font-medium">Update matches</span> — watch LIPID-REACH upgrade from Maybe to Likely.</> },
            { text: <>Switch the picker to <P id="syn-pat-0075" names={names} /> for the washout story: one obesity trial excludes his current semaglutide, its sister trial permits it — the agent catches the difference.</> },
          ],
          notice: "The registry is retrieved by vector search over the patient's own profile — different patients genuinely get different trials.",
          studio: "clinical-trial-matcher",
        },
      ],
    },
    {
      group: "Standalone tools",
      blurb: "Three agents that work as tools in their own right.",
      demos: [
        {
          n: 10, key: "pa", icon: FileCheck2,
          title: "Prior Authorisation Evidence",
          tagline: "Builds the insurer's evidence packet, then tracks the decision.",
          what: "Some medicines and tests need insurer approval first - normally hours of paperwork. Placing one of those orders makes the agent assemble the evidence packet from the record, check it against the payer's actual policy criteria (found by vector search), and list exactly what's still missing.",
          steps: [
            { text: <>On <GoLink to="/patient/syn-pat-0001?focus=orders">the chart's Orders section</GoLink>, place an order that needs authorisation (try the CGM or semaglutide).</> },
            { text: <>Read the packet: criteria met (with the supporting values), what's missing, and the drafted justification.</> },
            { text: <>Open the <GoLink to="/prior-auth">PA Queue</GoLink> and press <span className="font-medium">Submit</span> — the claim and the payer's response are real FHIR Claim / ClaimResponse resources.</> },
          ],
          notice: "The payer decision is the one simulated element (there's no real insurer here) — everything else, including the FHIR paperwork, is real.",
          studio: "prior-auth",
        },
        {
          n: 11, key: "ask", icon: Search,
          title: "Ask — plain English to database query",
          tagline: "Type a question; see how the AI read it, the SQL it wrote, and live results.",
          what: "\"Show diabetic patients with HbA1c above 9 in the last 6 months\" - the agent translates the question into SQL against the FHIR data, shows its working (the resources it identified, the filters it extracted, how confident it is), the platform validates the query is strictly read-only, runs it for real, and the results export to CSV.",
          steps: [
            { text: <>Open <GoLink to="/ask">Ask</GoLink> and click through the example chips — a cohort, a medication combination, a complex multi-part question, and a trend comparison.</> },
            { text: <>For each one, read the <span className="font-medium">"How the AI read your question"</span> panel next to the generated SQL — resources, extracted filters, and a confidence score.</> },
            { text: <>Now try the <span className="font-medium">Ambiguous</span> chip ("Which patients are getting worse?") — instead of silently guessing, the agent asks you a clarifying question.</> },
          ],
          notice: "The result table is computed live against the 1,000-patient dataset on every run — only the AI translation is cached. The read-only guard is enforced by the platform, not the model.",
          studio: "nl-to-fhir-query",
        },
        {
          n: 12, key: "triage", icon: MessageSquareText,
          title: "Conversational Triage",
          tagline: "A guided chat with the patient becomes a colour-coded clinician handoff.",
          what: "The agent designs a short, friendly question set for THIS patient and THEIR complaint - a red-flag safety check first, then duration, related symptoms, and whether they've missed their actual medications. The patient taps through the chat, and the answers become a colour-coded handoff for the care team, saved to the record.",
          steps: [
            { text: <>Open <GoLink to="/triage">Triage</GoLink> and tap through the conversation — answer however you like; every path works.</> },
            { text: <>Read the handoff: urgency (green / yellow / red), findings that <span className="font-medium">quote the patient's answers</span>, the answers mapped to FHIR observations, and a signable draft request.</> },
            { text: <>Press <span className="font-medium">Restart conversation</span> and answer <span className="font-medium">yes</span> to the first safety question — watch the urgency go red and the advice change to emergency care.</> },
            { text: <>Patients can do this themselves: open <GoLink to="/portal">the phone app</GoLink>, pick the first patient, and tap the <span className="font-medium">Symptoms</span> tab.</> },
          ],
          notice: "The whole conversation is stored in the FHIR repository as a QuestionnaireResponse — patient-reported data becomes part of the real record.",
          studio: "conversational-triage",
        },
      ],
    },
  ];
}

// ---- the page -----------------------------------------------------------------

function DemoCard({ demo, open, onToggle, names }: { demo: Demo; open: boolean; onToggle: () => void; names: Record<string, string> }) {
  const Icon = demo.icon;
  return (
    <div className={`overflow-hidden rounded-xl border bg-card shadow-sm transition-shadow ${open ? "shadow-md ring-1 ring-nhs-200" : "hover:shadow-md"}`}>
      <button onClick={onToggle} className="flex w-full items-center gap-3 px-4 py-3.5 text-left">
        <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-nhs-600 text-sm font-bold text-white">{demo.n}</span>
        <Icon className="h-5 w-5 shrink-0 text-nhs-600" />
        <span className="min-w-0 flex-1">
          <span className="block font-semibold leading-tight text-foreground">{demo.title}</span>
          <span className="block truncate text-sm text-muted-foreground">{demo.tagline}</span>
        </span>
        <ChevronDown className={`h-4 w-4 shrink-0 text-muted-foreground transition-transform ${open ? "rotate-180" : ""}`} />
      </button>
      {open && (
        <div className="space-y-4 border-t bg-muted/20 px-4 py-4 md:px-6">
          <p className="max-w-3xl text-sm leading-relaxed text-foreground">{demo.what}</p>
          <div>
            <div className="mb-1.5 text-xs font-semibold uppercase tracking-wide text-nhs-700">Try it</div>
            <ol className="space-y-2">
              {demo.steps.map((s, i) => (
                <li key={i} className="flex gap-2.5 text-sm leading-relaxed">
                  <span className="mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-nhs-100 text-[11px] font-bold text-nhs-700">{i + 1}</span>
                  <span className="min-w-0">{s.text}</span>
                </li>
              ))}
            </ol>
          </div>
          <div className="flex flex-wrap items-start justify-between gap-3 border-t pt-3">
            <p className="flex max-w-xl items-start gap-1.5 text-sm text-muted-foreground">
              <Wand2 className="mt-0.5 h-4 w-4 shrink-0 text-nhs-600" />
              <span><span className="font-medium text-foreground">Worth noticing:</span> {demo.notice}</span>
            </p>
            <a
              href={`/fhir-agent-studio/#/agent/${demo.studio}/run`}
              target="fast-studio"
              className="inline-flex shrink-0 items-center gap-1.5 rounded-md border px-2.5 py-1.5 text-xs font-medium text-muted-foreground hover:bg-muted/50 hover:text-foreground"
            >
              Under the hood in the Studio <ExternalLink className="h-3.5 w-3.5" />
            </a>
          </div>
        </div>
      )}
    </div>
  );
}

export function DemoGuide() {
  const [open, setOpen] = useState<string | null>(null);
  const [names, setNames] = useState<Record<string, string>>({});

  useEffect(() => {
    PATIENT_IDS.forEach((id) => {
      api.everything(`Patient/${id}`).then((b) => setNames((n) => ({ ...n, [id]: b.patient || id }))).catch(() => {});
    });
  }, []);

  const groups = buildDemos(names);

  return (
    <div className="space-y-8 pb-10">
      {/* Hero */}
      <div className="-mx-6 -mt-6 bg-gradient-to-br from-nhs-700 via-nhs-600 to-nhs-500 px-6 py-10 text-white">
        <div className="mx-auto max-w-3xl">
          <div className="mb-2 inline-flex items-center gap-1.5 rounded-full bg-white/15 px-3 py-1 text-xs font-semibold uppercase tracking-wide">
            <Sparkles className="h-3.5 w-3.5" /> The demo
          </div>
          <h1 className="text-3xl font-bold leading-tight">Twelve AI agents, one hospital.</h1>
          <p className="mt-2 max-w-2xl text-[15px] leading-relaxed text-white/85">
            Cedar Valley Health is a working mini hospital system: 1,000 patients of rich FHIR data, a real
            interoperability engine underneath, and twelve AI agents woven into the places clinicians actually work.
            This page walks you through every one — each card says what the agent does, where to click, and what to
            notice. No API key, no setup: every step below lands on real, working demo data.
          </p>
          <div className="mt-4 flex flex-wrap gap-2 text-xs font-medium">
            <span className="rounded-full bg-white/15 px-3 py-1">Real FHIR R4 repository</span>
            <span className="rounded-full bg-white/15 px-3 py-1">Real IRIS Vector Search</span>
            <span className="rounded-full bg-white/15 px-3 py-1">Real LLM output, replayed key-free</span>
            <span className="rounded-full bg-white/15 px-3 py-1">Drafts only — a human signs everything</span>
          </div>
        </div>
      </div>

      {/* Groups */}
      <div className="mx-auto max-w-3xl space-y-8">
        {groups.map((g) => (
          <section key={g.group}>
            <h2 className="text-lg font-semibold">{g.group}</h2>
            <p className="mb-3 text-sm text-muted-foreground">{g.blurb}</p>
            <div className="space-y-2.5">
              {g.demos.map((d) => (
                <DemoCard key={d.key} demo={d} open={open === d.key} onToggle={() => setOpen(open === d.key ? null : d.key)} names={names} />
              ))}
            </div>
          </section>
        ))}

        {/* Build the thirteenth agent yourself */}
        <section>
          <h2 className="text-lg font-semibold">Then build the thirteenth yourself</h2>
          <p className="mb-3 text-sm text-muted-foreground">
            The twelve agents above were all built in the developer Studio — and so can yours, in about two minutes,
            without writing code.
          </p>
          <div className="overflow-hidden rounded-xl border bg-card shadow-sm">
            <div className="space-y-4 px-5 py-4">
              <ol className="space-y-2">
                {[
                  <>Open <a className="inline-flex items-center gap-1 rounded-md bg-nhs-50 px-2 py-0.5 font-medium text-nhs-700 hover:bg-nhs-100" href="/fhir-agent-studio/#/agents" target="fast-studio">the Studio's Agents page <ExternalLink className="h-3.5 w-3.5" /></a> and press <span className="font-medium">New Agent</span>.</>,
                  <>Pick the <span className="font-medium">Metformin renal safety</span> starter and keep the suggested name — then <span className="font-medium">Create &amp; deploy</span>. Your agent is compiled into real artifacts and deployed to the live interoperability runtime in one step.</>,
                  <>On the <span className="font-medium">Build</span> tab the agent is a numbered pipeline — exactly the steps the runtime executes. Press <span className="font-medium">Test step</span> on the eGFR query (one row: <span className="font-medium">eGFR 22</span>) and on the semantic search (profile-driven retrieval brings back ACE-inhibitor guidance — he takes lisinopril — and the metformin rule: <span className="font-medium">contraindicated below 30</span>). The collision is visible before the agent has even run.</>,
                  <>On the Reason step, press <span className="font-medium">Preview prompt</span> — the exact system and user messages the runtime will send, assembled from the steps you just tested. The <span className="font-medium">output contract</span> it references genuinely shapes the AI's JSON (see Schemas in the side nav — the contract you author is the shape you get).</>,
                  <>On the <span className="font-medium">Run</span> tab, press <span className="font-medium">Run agent</span> — real AI flags metformin as contraindicated at eGFR 22 and drafts a prescriber Task that requires human sign-off. Open <span className="font-medium">Inspect</span> to see the seven compiled artifacts and the mapping onto real Business Service → Process → Operations.</>,
                  <>Now make it yours: add evidence steps (including your own read-only SQL, testable as you type it), swap the output contract, rewrite the instruction — Save &amp; deploy, run again. Edited agents run live with an API key (add one in Admin); unchanged starters replay instantly key-free.</>,
                ].map((step, i) => (
                  <li key={i} className="flex gap-2.5 text-sm leading-relaxed">
                    <span className="mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-nhs-100 text-[11px] font-bold text-nhs-700">{i + 1}</span>
                    <span className="min-w-0">{step}</span>
                  </li>
                ))}
              </ol>
              <p className="flex items-start gap-1.5 border-t pt-3 text-sm text-muted-foreground">
                <Wand2 className="mt-0.5 h-4 w-4 shrink-0 text-nhs-600" />
                <span><span className="font-medium text-foreground">Worth noticing:</span> nothing about your agent is special-cased — it goes through the same compiler, the same production, the same trace, and the same draft-and-sign safety rules as the twelve built-ins.</span>
              </p>
            </div>
          </div>
        </section>

        {/* Prove it's real */}
        <section>
          <h2 className="text-lg font-semibold">Don't take our word for it</h2>
          <p className="mb-3 text-sm text-muted-foreground">
            Three ways to verify the AI is real, in increasing order of paranoia:
          </p>
          <div className="overflow-hidden rounded-xl border bg-card shadow-sm">
            <ol className="space-y-2 px-5 py-4">
              {[
                <>On any agent run in the Studio, open <span className="font-medium">"Under the hood"</span> — the exact prompt sent (including every piece of patient evidence) and the raw model response that became the result. Then click <span className="font-medium">"Open in IRIS Visual Trace"</span>: the same run as engine-level messages in the Management Portal, which application code cannot forge.</>,
                <>Browse the <a className="inline-flex items-center gap-1 rounded-md bg-nhs-50 px-2 py-0.5 font-medium text-nhs-700 hover:bg-nhs-100" href="/fhir-agent-studio/#/ai-hub" target="fast-studio">AI Hub <ExternalLink className="h-3.5 w-3.5" /></a> — the entire bundled response corpus is open for inspection: every cached reply is a real Grok completion with its prompt preview, generation date and hash key. The key covers the <span className="font-medium">whole prompt including the evidence</span>, so a changed chart can never replay a stale answer.</>,
                <>Run the falsifiability test: change any input on any agent and watch the badge honestly drop out of "cached"; then add your own OpenAI-compatible key in the Studio's Admin and re-run — a live model returns a differently-worded answer that agrees in substance. Canned output can't do that.</>,
              ].map((step, i) => (
                <li key={i} className="flex gap-2.5 text-sm leading-relaxed">
                  <span className="mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-nhs-100 text-[11px] font-bold text-nhs-700">{i + 1}</span>
                  <span className="min-w-0">{step}</span>
                </li>
              ))}
            </ol>
          </div>
        </section>

        {/* The patient's phone */}
        <section className="overflow-hidden rounded-xl border bg-gradient-to-r from-nhs-50 to-white shadow-sm">
          <div className="flex flex-wrap items-center gap-4 px-5 py-4">
            <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-nhs-600 text-white"><Smartphone className="h-5 w-5" /></span>
            <div className="min-w-0 flex-1">
              <div className="font-semibold">Don't leave without seeing the patient's phone</div>
              <p className="text-sm text-muted-foreground">
                The same AI that briefs clinicians also writes to patients — warm, plain words, one-tap replies.
                Two agents power it: the Care Plan Navigator ("My plan") and the Social Prescribing Matcher ("Local support").
              </p>
            </div>
            <a href="/clinical/#/portal" target="fast-phone" className="inline-flex shrink-0 items-center gap-1.5 rounded-md bg-nhs-600 px-3.5 py-2 text-sm font-semibold text-white hover:bg-nhs-700">
              Open the patient portal <ArrowRight className="h-4 w-4" />
            </a>
          </div>
        </section>

        <p className="text-center text-xs text-muted-foreground">
          Everything here runs on InterSystems IRIS for Health: the FHIR repository, the interoperability production
          behind every agent run, the vector search, and the SQL — one platform, no other backend.
        </p>
      </div>
    </div>
  );
}
