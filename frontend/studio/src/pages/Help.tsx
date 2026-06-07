// Help — the orientation page for anyone new to the Studio (written for a junior
// developer). Explains the mental model, every screen,
// every entity, and how to verify that what they're seeing is real. The guided
// build of a new agent lives on its own page (/walkthrough) and is linked from here.
import { Link } from "react-router-dom";
import {
  Bot, Database, Search, ListChecks, ShieldCheck, Sparkles, BookOpen,
  GraduationCap, PlayCircle, Wrench, Layers, History, FileEdit, Eye,
  CheckCircle2, ExternalLink, ArrowRight, FlaskConical,
} from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@shared/components/ui/card";
import { Badge } from "@shared/components/ui/badge";

function Section({ id, title, children }: { id: string; title: string; children: React.ReactNode }) {
  return (
    <section id={id} className="scroll-mt-20">
      <h2 className="mb-3 text-lg font-semibold tracking-tight">{title}</h2>
      {children}
    </section>
  );
}

function Term({ name, children }: { name: string; children: React.ReactNode }) {
  return (
    <div className="rounded-md border bg-card px-3 py-2.5">
      <p className="text-sm font-medium">{name}</p>
      <p className="text-sm text-muted-foreground">{children}</p>
    </div>
  );
}

function ScreenCard({ icon: Icon, title, to, what, why, tryThis }: {
  icon: typeof Bot;
  title: string;
  to: string;
  what: React.ReactNode;
  why?: React.ReactNode;
  tryThis?: React.ReactNode;
}) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="flex items-center gap-2 text-base">
          <Icon className="h-4 w-4 text-primary" />
          {title}
          <Link to={to} className="ml-auto inline-flex items-center gap-1 text-xs font-medium text-primary hover:underline">
            open <ArrowRight className="h-3 w-3" />
          </Link>
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-2 text-sm">
        <p>{what}</p>
        {why && <p className="text-muted-foreground">{why}</p>}
        {tryThis && (
          <p className="rounded-md bg-secondary/50 px-2.5 py-1.5 text-xs">
            <span className="font-medium">Try it:</span> {tryThis}
          </p>
        )}
      </CardContent>
    </Card>
  );
}

export function Help() {
  return (
    <div className="mx-auto max-w-4xl space-y-8 pb-10">
      <div>
        <h1 className="flex items-center gap-2 text-2xl font-semibold tracking-tight">
          <BookOpen className="h-6 w-6 text-primary" />
          Help — how the Studio works
        </h1>
        <p className="mt-1 max-w-3xl text-muted-foreground">
          Everything on this page assumes no prior knowledge. If you'd rather learn by doing,
          the <Link to="/walkthrough" className="font-medium text-primary hover:underline">guided walkthrough</Link> builds
          a complete new agent in about three minutes.
        </p>
      </div>

      {/* ---------------- the mental model ---------------- */}
      <Section id="model" title="The one-minute mental model">
        <Card>
          <CardContent className="space-y-3 pt-4 text-sm leading-relaxed">
            <p>
              An <span className="font-medium">agent</span> is a small clinical workflow described as data — a JSON
              definition that says what inputs it asks for, what evidence it gathers from the patient's record, what it
              asks an LLM to do with that evidence, and what (draft) action it proposes at the end.
            </p>
            <p>
              When you save an agent, the Studio's compiler turns the definition into runtime artifacts and deploys it
              to a <span className="font-medium">real InterSystems IRIS interoperability production</span>. Every run is a
              genuine message flow — Business Service → Business Process → Business Operations — recorded step by step,
              inspectable down to the engine's own Visual Trace.
            </p>
            <p>
              Each run follows the same pipeline, and the Build tab shows the agent in exactly that shape:
            </p>
            <div className="overflow-x-auto rounded-md bg-secondary/50 px-3 py-2 font-mono text-xs">
              capture inputs → read FHIR → run structured queries → semantic (vector) search → <span className="font-semibold">reason once with AI</span> → propose a draft action
            </div>
            <p>
              Two safety rules hold everywhere: the agent may only <span className="font-medium">read</span> the record
              while gathering evidence (every SQL path is guarded read-only), and anything it wants to{" "}
              <span className="font-medium">write</span> back is a <span className="font-medium">draft</span> a human must
              approve — nothing commits to FHIR automatically.
            </p>
            <p className="text-muted-foreground">
              The Studio is one of two apps over the same backend: here you build, run, and inspect agents; the{" "}
              <a href="/clinical/#/demo" target="fast-clinical" className="font-medium text-primary hover:underline">
                Cedar Valley Health clinical app <ExternalLink className="inline h-3 w-3" />
              </a>{" "}
              shows the same agents surfaced for clinicians — worklists, in-chart advisories, and the sign-off queue
              where drafts get approved or declined.
            </p>
          </CardContent>
        </Card>
      </Section>

      {/* ---------------- the AI tiers ---------------- */}
      <Section id="ai" title="How the AI works (and why no API key is needed)">
        <Card>
          <CardContent className="space-y-3 pt-4 text-sm leading-relaxed">
            <p>Every AI call resolves through three tiers, and every result says honestly which one it used:</p>
            <div className="space-y-2">
              <div className="flex items-start gap-2">
                <Badge className="mt-0.5 shrink-0">cached</Badge>
                <p>
                  The repo bundles <span className="font-medium">real, pre-generated LLM responses</span> (and real
                  embedding vectors) for every demo path. A run whose exact prompt is in the bundle replays the genuine
                  model output — no key, no network. This is the normal demo path.
                </p>
              </div>
              <div className="flex items-start gap-2">
                <Badge variant="secondary" className="mt-0.5 shrink-0">live</Badge>
                <p>
                  For <span className="font-medium">uncached</span> prompts — building a new agent, editing one, custom
                  queries — the demo uses a shared, budget-capped community key so you get live AI with no setup. When that
                  budget is spent it falls back honestly (see deterministic). Add your own OpenAI-compatible key in{" "}
                  <Link to="/admin" className="font-medium text-primary hover:underline">Admin</Link> for unlimited live use.
                </p>
              </div>
              <div className="flex items-start gap-2">
                <Badge variant="outline" className="mt-0.5 shrink-0">deterministic</Badge>
                <p>
                  No cache hit and no key: a plain-code fallback produces a structured result so nothing errors — and
                  the UI tells you explicitly that it is <span className="font-medium">not AI</span>. It is never dressed
                  up as intelligence.
                </p>
              </div>
            </div>
            <p className="text-muted-foreground">
              The full record/replay corpus is browsable in the{" "}
              <Link to="/ai-hub" className="font-medium text-primary hover:underline">AI Hub</Link> — every prompt, every
              verbatim completion, its generation date and cache key.
            </p>
          </CardContent>
        </Card>
      </Section>

      {/* ---------------- the screens ---------------- */}
      <Section id="screens" title="The screens">
        <div className="space-y-3">
          <ScreenCard
            icon={Bot}
            title="Agents"
            to="/agents"
            what={<>The gallery of every agent — twelve built-ins plus anything you create. <span className="font-medium">New Agent</span> opens a wizard with ready-made starters; a starter created unchanged replays a real cached AI result on its very first run, key-free.</>}
            tryThis={<>open any agent — you land in its workspace with four tabs, described below.</>}
          />

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-base">Inside an agent's workspace</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-sm">
              <div className="flex items-start gap-2.5">
                <PlayCircle className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
                <p>
                  <span className="font-medium">Run</span> — give the agent real inputs (the patient picker lists real
                  FHIR patients) and execute it on the live production. You get the structured result, any draft action,
                  and <span className="font-medium">Under the hood</span>: the full LLM transcript (the exact prompt sent
                  and the raw response), the evidence that was retrieved, the step-by-step trace, and a deep link into the
                  IRIS Management Portal's <span className="font-medium">Visual Trace</span> for the same run.
                </p>
              </div>
              <div className="flex items-start gap-2.5">
                <Wrench className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
                <p>
                  <span className="font-medium">Build</span> — the step-rail editor. The agent appears as a numbered
                  pipeline in exactly the order the runtime executes. Pick a <span className="font-medium">test patient</span>,
                  then press <span className="font-medium">Test step</span> on any evidence step to run just that step —
                  the same engine code the production calls — and see its real output (resources, rows, or scored
                  guidance chunks). On the Reason step, <span className="font-medium">Preview prompt</span> shows the exact
                  system and user messages that will be sent, assembled from the steps above. <span className="font-medium">Save
                  &amp; deploy</span> validates, compiles, and deploys in one go. Editing a <em>built-in</em> agent creates an
                  override (with a warning, and a one-click way to discard it); <span className="font-medium">Clone</span> is
                  the safer way to experiment.
                </p>
              </div>
              <div className="flex items-start gap-2.5">
                <Layers className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
                <p>
                  <span className="font-medium">Inspect</span> — what the compiler produced: seven artifacts (recipe,
                  prompt, output schema, FHIR action template, production settings, HealthConnect mapping, IPM
                  module.xml) and the mapping of each part of your agent onto the real Business Service / Process /
                  Operation components that execute it.
                </p>
              </div>
              <div className="flex items-start gap-2.5">
                <History className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
                <p>
                  <span className="font-medium">Activity</span> — the agent's run history, persisted in IRIS. Open any
                  past invocation to revisit its result and trace.
                </p>
              </div>
            </CardContent>
          </Card>

          <ScreenCard
            icon={Search}
            title="Evidence Sources"
            to="/components/evidence-sources"
            what={<>Reusable, parameter-bound evidence steps. Each has a <span className="font-mono text-xs">kind</span> (read FHIR resource types, run a guarded read-only SQL query, semantic vector search, terminology resolve, or a compact whole-record bundle) and a JSON spec with <span className="font-mono text-xs">{"{{patientRef}}"}</span> / <span className="font-mono text-xs">{"{{input.<key>}}"}</span> placeholders bound at run time.</>}
            why={<>They are live components, not documentation: an agent that lists one executes it through the generic Evidence Engine, with its own trace step. Custom SQL steps you write in the builder are saved here.</>}
          />
          <ScreenCard
            icon={ListChecks}
            title="Schemas"
            to="/components/output-schemas"
            what={<>Output contracts — the JSON shape an agent's AI result must satisfy. For agents built in the Studio, the schema you pick is appended verbatim to the LLM's instructions, so <span className="font-medium">the contract you author is the shape you get back</span>.</>}
            tryThis={<>open <span className="font-mono text-xs">renal-safety-result</span> — it shapes the walkthrough agent's per-medication verdicts and its drafted Task.</>}
          />
          <ScreenCard
            icon={ShieldCheck}
            title="Care Rules"
            to="/care-rules"
            what={<>Population-level preventative care. Describe a cohort in plain English ("diabetics whose last HbA1c is over 9") and the AI writes a single read-only SQL query over the FHIR projections; you can see the generated SQL, run it, and keep the resulting worklist.</>}
            why={<>The same three AI tiers and the same read-only guard apply here as everywhere else.</>}
          />
          <ScreenCard
            icon={Sparkles}
            title="AI Hub"
            to="/ai-hub"
            what={<>The transparency centre: the three-tier explainer with live session counters (how many runs were cached / live / deterministic since boot), the connection details, and the <span className="font-medium">browsable record/replay corpus</span> — search and open any cached entry to read the exact prompt and the verbatim model output behind a demo result.</>}
          />
          <ScreenCard
            icon={Database}
            title="Admin"
            to="/admin"
            what={<>The AI connection (bring your own OpenAI-compatible key — held only in the instance's temporary store, never journaled or written to the durable database, wiped on restart, never echoed back; a cache-replay toggle; a live "test connection" ping), runtime status, and the persistent record counts behind the app.</>}
          />
        </div>
      </Section>

      {/* ---------------- glossary ---------------- */}
      <Section id="glossary" title="Glossary — the entities you'll meet">
        <div className="grid gap-2 sm:grid-cols-2">
          <Term name="Agent definition">
            The JSON document that fully describes an agent: trigger, inputs, evidence, the AI instruction + output
            contract, and the draft action. The Build tab is a direct view of it; the compiler consumes it.
          </Term>
          <Term name="Step">
            One stage of the pipeline. Evidence steps gather (FHIR read, structured query, custom SQL, semantic search);
            exactly one Reason step calls the LLM; an optional Action step drafts a FHIR resource. Steps execute in the
            order shown — that's the runtime's real order, not a drawing.
          </Term>
          <Term name="Evidence">
            What the agent retrieved before reasoning: FHIR resources, query rows, and vector-search chunks. It is shown
            with every result, rendered into the prompt, and the AI is instructed to use nothing else.
          </Term>
          <Term name="Output contract (schema)">
            The JSON shape the LLM must return. Built-in agents have hand-tuned contracts; Studio-built agents use a
            Schema component you pick (or author).
          </Term>
          <Term name="Draft action">
            A FHIR resource (Task, ServiceRequest, DocumentReference…) the agent proposes. Always status
            <span className="font-mono text-xs"> draft</span>, always requiring a human to approve before anything is
            committed to the FHIR repository — approvals are audited.
          </Term>
          <Term name="Trace">
            The recorded step-by-step account of one run: every Business Operation called, its request and response
            payloads, and the AI transcript. Deep-links to the engine's own Visual Trace for the same session.
          </Term>
          <Term name="Compiled artifacts">
            The seven files the compiler generates from a definition (recipe, prompt, output schema, FHIR action
            template, production settings, HealthConnect mapping, IPM module). Visible per agent under Inspect.
          </Term>
          <Term name="Test patient">
            The patient a builder session tests against (persisted as the agent's test case). Step tests and prompt
            previews run against this record; the Run tab lets you pick any patient.
          </Term>
          <Term name="Vector search">
            Native IRIS Vector Search: knowledge documents carry real embedding vectors in a VECTOR column and queries
            rank by VECTOR_DOT_PRODUCT. The query text can be built from the patient's own profile, their abnormal
            results, or their screening answers — so each patient retrieves what fits <em>them</em>.
          </Term>
          <Term name="Cached / live / deterministic">
            The three AI tiers (see above). The source badge on every result is the honest record of which tier
            produced it.
          </Term>
        </div>
      </Section>

      {/* ---------------- building ---------------- */}
      <Section id="build" title="Building a new agent (the short version)">
        <Card>
          <CardContent className="space-y-3 pt-4 text-sm leading-relaxed">
            <ol className="list-inside list-decimal space-y-1.5">
              <li><span className="font-medium">Agents → New Agent</span>, pick a starter (or Blank canvas), name it, Create &amp; deploy.</li>
              <li>On <span className="font-medium">Build</span>, set the test patient, then walk the rail: add or adjust evidence steps and press <span className="font-medium">Test step</span> on each until the data looks right.</li>
              <li>On the Reason step: set the role and instruction, pick an output contract, and <span className="font-medium">Preview prompt</span> to read exactly what will be sent.</li>
              <li>Add a draft action if the agent should propose something (it will always require human review).</li>
              <li><span className="font-medium">Save &amp; deploy</span>, then <span className="font-medium">Run agent</span>. Check the result, the source badge, and Under the hood.</li>
            </ol>
            <p className="flex items-center gap-2 rounded-md border border-primary/30 bg-primary/5 px-3 py-2">
              <GraduationCap className="h-4 w-4 shrink-0 text-primary" />
              <span>
                For the full guided version — a real clinical scenario where every step test reveals part of the story —
                follow <Link to="/walkthrough" className="font-medium text-primary hover:underline">the walkthrough</Link>.
              </span>
            </p>
          </CardContent>
        </Card>
      </Section>

      {/* ---------------- verifying ---------------- */}
      <Section id="verify" title="Verifying it's real (for the sceptical)">
        <Card>
          <CardContent className="space-y-2.5 pt-4 text-sm leading-relaxed">
            <p className="flex items-start gap-2">
              <Eye className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
              <span><span className="font-medium">Read the transcript.</span> Every run's Under the hood shows the exact prompt and the raw model response — the JSON the model returned <em>is</em> the result you saw, not a post-edited version.</span>
            </p>
            <p className="flex items-start gap-2">
              <FlaskConical className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
              <span><span className="font-medium">Open the Visual Trace.</span> The link goes to the IRIS Management Portal's own message viewer for the same session — application code can't fake the engine's view of itself.</span>
            </p>
            <p className="flex items-start gap-2">
              <Sparkles className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
              <span><span className="font-medium">Browse the corpus.</span> The AI Hub lists every cached prompt/response pair with dates and hashes. Nothing is a black box.</span>
            </p>
            <p className="flex items-start gap-2">
              <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
              <span><span className="font-medium">Try to break it.</span> Give an agent an input that isn't cached, with no key set — it tells you plainly it fell back to a non-AI path instead of pretending. That honest failure mode is the strongest evidence the successes are real.</span>
            </p>
          </CardContent>
        </Card>
      </Section>

      {/* ---------------- FAQ ---------------- */}
      <Section id="faq" title="FAQ">
        <div className="space-y-2">
          <Term name='Why does my run say "deterministic"?'>
            Its exact prompt isn't in the bundled cache and no API key is configured. Either re-run one of the prepared
            demo paths (unchanged starters, default inputs), or add a key in Admin to go live. The result you got is
            real code over real data — just not AI, and it says so.
          </Term>
          <Term name="I edited a built-in agent and it stopped replaying cached AI. Why?">
            Cached responses are keyed to the exact prompt, and your edit changed it — which the system reports honestly
            instead of replaying a response that no longer matches. Use <span className="font-medium">Discard override</span> on
            the Build tab to restore the built-in (and its cached runs), or add a key to run your edited version live.
          </Term>
          <Term name="Where do drafted actions go?">
            Into a review queue. In the clinical app a clinician opens the draft, sees it in plain language, and signs or
            declines; approval commits the resource to the FHIR repository with a full audit trail. Nothing commits
            without that human step.
          </Term>
          <Term name="Can an agent write to the database while gathering evidence?">
            No. Every SQL evidence path is checked to be a single read-only SELECT before it executes (and the
            natural-language query agent validates its generated SQL twice — in ObjectScript, plus an Embedded Python
            AST parse where the runtime supports it).
          </Term>
          <Term name="Where is the FHIR data?">
            A real IRIS for Health FHIR R4 repository with a ~1,000-patient synthetic population (UK-flavoured, fully
            fictional). The Run tab's patient picker, the worklists, and every evidence step read from it.
          </Term>
        </div>
      </Section>
    </div>
  );
}
