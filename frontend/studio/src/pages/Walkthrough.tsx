// The guided walkthrough: build the thirteenth agent yourself, step by step, with
// a checkpoint after every action so you know it worked. This is the demo-ware
// counterpart to the Help page — a real clinical scenario (active metformin vs an
// eGFR of 22) where each step test reveals part of the story before the AI runs.
// It is also the exact script of the "build the thirteenth agent" video.
import { Link } from "react-router-dom";
import {
  GraduationCap, CheckCircle2, ArrowRight, Sparkles, PlayCircle, Eye, Wrench,
  Database, Search, FileEdit, ExternalLink, AlertTriangle, Layers, BookOpen,
} from "lucide-react";
import { Card, CardContent } from "@shared/components/ui/card";
import { Badge } from "@shared/components/ui/badge";

function Step({ n, title, children, checkpoint }: {
  n: number;
  title: React.ReactNode;
  children: React.ReactNode;
  checkpoint?: React.ReactNode;
}) {
  return (
    <div className="relative pl-10">
      <div className="absolute left-3 top-0 h-full w-px bg-border" aria-hidden />
      <div className="absolute left-0 top-2 flex h-6 w-6 items-center justify-center rounded-full border border-primary/40 bg-card text-xs font-bold text-primary">{n}</div>
      <div className="mb-4">
        <h3 className="mb-1 pt-1 font-semibold">{title}</h3>
        <div className="space-y-2 text-sm leading-relaxed">{children}</div>
        {checkpoint && (
          <p className="mt-2 flex items-start gap-1.5 rounded-md border border-emerald-300 bg-emerald-50/60 px-3 py-2 text-sm text-emerald-800">
            <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0" />
            <span><span className="font-medium">Checkpoint:</span> {checkpoint}</span>
          </p>
        )}
      </div>
    </div>
  );
}

export function Walkthrough() {
  return (
    <div className="mx-auto max-w-4xl space-y-6 pb-10">
      <div>
        <h1 className="flex items-center gap-2 text-2xl font-semibold tracking-tight">
          <GraduationCap className="h-6 w-6 text-primary" />
          Build the thirteenth agent
        </h1>
        <p className="mt-1 max-w-3xl text-muted-foreground">
          The twelve agents in the gallery were all built here. This walkthrough builds a thirteenth — a real
          medication-safety monitor — in about three minutes, testing every step as you go.{" "}
          <span className="font-medium text-foreground">No API key needed.</span>
        </p>
      </div>

      {/* the clinical story */}
      <Card className="border-primary/30 bg-primary/5">
        <CardContent className="pt-4 text-sm leading-relaxed">
          <p className="mb-1 font-semibold">The scenario (everything in it is really in the dataset)</p>
          <p>
            Alexander Gresham is on <span className="font-medium">active metformin</span> for type 2 diabetes. His latest
            kidney-function result is an <span className="font-medium">eGFR of 22</span> — and the clinical guidance corpus
            contains the rule that metformin is <span className="font-medium">contraindicated below 30</span> (risk of lactic
            acidosis). Nobody has connected those three facts. Your agent will — and you'll watch each fact surface in a
            step test <em>before</em> the AI ever runs.
          </p>
        </CardContent>
      </Card>

      <div>
        <Step
          n={1}
          title={<>Create the agent from its starter</>}
          checkpoint={<>you land in the agent's workspace, and the save banner reports it compiled and deployed.</>}
        >
          <p>
            Open <Link to="/agents" className="font-medium text-primary hover:underline">Agents</Link> and press{" "}
            <span className="font-medium">New Agent</span>. Pick the <span className="font-medium">Metformin renal
            safety</span> starter, keep the suggested name (that's what makes the key-free AI replay work — more in step
            7), and press <span className="font-medium">Create &amp; deploy</span>. One click ran the whole authoring
            pipeline: validate → compile seven artifacts → deploy to the live interoperability production.
          </p>
        </Step>

        <Step
          n={2}
          title={<>Read the pipeline <Wrench className="ml-1 inline h-4 w-4 text-muted-foreground" /></>}
        >
          <p>
            Open the <span className="font-medium">Build</span> tab. The agent is a numbered rail of steps — and this is
            not a diagram of intent, it's the literal execution order of the runtime: capture inputs → read the FHIR
            record → run the eGFR query → semantic search → reason with AI → propose a draft action. Note the{" "}
            <span className="font-medium">test patient</span> at the top is already set to Alexander.
          </p>
        </Step>

        <Step
          n={3}
          title={<>Test the FHIR read <Database className="ml-1 inline h-4 w-4 text-muted-foreground" /></>}
          checkpoint={<>about 10 real resources, grouped by type — Conditions include type 2 diabetes and CKD, and MedicationRequests include <span className="font-medium">metformin (active)</span>. Fact one.</>}
        >
          <p>
            Expand step ② <span className="font-medium">Read the FHIR record</span> and press{" "}
            <span className="font-medium">Test step</span>. This runs the same engine code the production's
            FHIRRead operation calls — against the real repository, right now.
          </p>
        </Step>

        <Step
          n={4}
          title={<>Test the eGFR query <Database className="ml-1 inline h-4 w-4 text-muted-foreground" /></>}
          checkpoint={<>one row: <span className="font-mono">eGFR 22</span>. Fact two — and it's below every metformin threshold in use.</>}
        >
          <p>
            Expand the <span className="font-medium">Kidney function (eGFR) results</span> step. This is a reusable
            evidence component: a read-only SQL query over the FHIR projections with a{" "}
            <span className="font-mono text-xs">{"{{patientRef}}"}</span> placeholder bound at run time (open it later in{" "}
            <Link to="/components/evidence-sources" className="font-medium text-primary hover:underline">Evidence Sources</Link>).
            Press <span className="font-medium">Test step</span>.
          </p>
        </Step>

        <Step
          n={5}
          title={<>Test the semantic search <Search className="ml-1 inline h-4 w-4 text-muted-foreground" /></>}
          checkpoint={<>three scored guidance chunks. Among them: <span className="font-medium">"Metformin and renal function… contraindicated when the estimated GFR is below 30"</span>. Fact three. (The ACE-inhibitor chunk ranks high too — he takes lisinopril with kidney disease. Remember it for step 8.)</>}
        >
          <p>
            Expand the <span className="font-medium">Semantic search</span> step. This is native IRIS Vector Search over
            the drug-guidance corpus, and the query is built from <em>this patient's</em> profile — his age, conditions,
            medications, and key results — so each patient retrieves the guidance that fits them. Press{" "}
            <span className="font-medium">Test step</span>.
          </p>
        </Step>

        <Step
          n={6}
          title={<>Preview the exact prompt <Eye className="ml-1 inline h-4 w-4 text-muted-foreground" /></>}
          checkpoint={<>the system message carries the pharmacist role, the instruction, and the output contract; the user message contains the record, the eGFR row, and the guidance chunks you just saw. Nothing else. No hidden prompt engineering.</>}
        >
          <p>
            Expand step ⑤ <span className="font-medium">Reason with AI</span>. Read the role and instruction, and note the{" "}
            <span className="font-medium">output contract</span> (<span className="font-mono text-xs">renal-safety-result</span>) —
            a Schema component whose JSON shape genuinely becomes the LLM's required output (see{" "}
            <Link to="/components/output-schemas" className="font-medium text-primary hover:underline">Schemas</Link>).
            Then press <span className="font-medium">Preview prompt</span>: the evidence steps above are gathered and the{" "}
            <em>exact</em> system + user messages appear — assembled by the same code path the runtime uses. No AI call is
            made yet.
          </p>
        </Step>

        <Step
          n={7}
          title={<>Run it <PlayCircle className="ml-1 inline h-4 w-4 text-muted-foreground" /></>}
          checkpoint={<>status <span className="font-medium">needs review</span>; metformin <span className="font-medium">contraindicated at eGFR 22</span>; and a drafted <span className="font-medium">urgent Task</span> for the prescriber, marked "requires human review".</>}
        >
          <p>
            Switch to the <span className="font-medium">Run</span> tab and press <span className="font-medium">Run
            agent</span>. The run executes as real interoperability messages — Business Service → Process → the
            Operations you just tested one by one — and the AI reasons over exactly the prompt you previewed.
          </p>
          <p className="flex items-start gap-1.5 rounded-md bg-secondary/50 px-3 py-2 text-xs">
            <Sparkles className="mt-0.5 h-3.5 w-3.5 shrink-0 text-primary" />
            <span>
              <span className="font-medium">Why was that instant, with no API key?</span> Expand{" "}
              <span className="font-medium">Under the hood</span>: the source badge says{" "}
              <span className="font-mono">cached</span>. The repo bundles the real model response for this exact starter
              — created unchanged, your first run replays genuine AI output key-free. The transcript shows the full
              prompt and the raw response; the Visual Trace link opens the engine's own message view of this very run.
            </span>
          </p>
        </Step>

        <Step
          n={8}
          title={<>Notice what it caught beyond the obvious</>}
        >
          <p>
            Read the result closely: besides stopping metformin, the agent flags <span className="font-medium">lisinopril
            for dose review with electrolyte monitoring</span> — because the profile-driven search also retrieved the
            ACE-inhibitor/hyperkalemia guidance for this CKD patient. The drafted Task covers both. That's the point of
            evidence-grounded agents: the retrieval shapes the reasoning, and you watched both happen.
          </p>
        </Step>

        <Step
          n={9}
          title={<>Make it yours</>}
          checkpoint={<>your edited agent runs honestly: with a key it goes <span className="font-mono">live</span>; without one it tells you plainly the result is the non-AI fallback. Nothing pretends.</>}
        >
          <p>
            Back on <span className="font-medium">Build</span>, change anything — rewrite the instruction, add a step
            with <span className="font-medium">+ Custom SQL</span> (write your own read-only query and Test it as you
            type), swap the output contract — then Save &amp; deploy and run again. Edits change the prompt, so the
            cached response honestly no longer applies:
          </p>
          <p className="flex items-start gap-1.5 text-xs text-muted-foreground">
            <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0" />
            <span>
              To run your own variations as live AI, add any OpenAI-compatible key in{" "}
              <Link to="/admin" className="font-medium text-primary hover:underline">Admin</Link> (never stored — wiped on restart).
            </span>
          </p>
        </Step>

        <Step
          n={10}
          title={<>Where to go next</>}
        >
          <ul className="list-inside list-disc space-y-1">
            <li>
              <span className="font-medium">Inspect</span> tab <Layers className="inline h-3.5 w-3.5 text-muted-foreground" /> —
              the seven compiled artifacts your three minutes produced, and the mapping onto real BS/BP/BO components.
            </li>
            <li>
              <Link to="/ai-hub" className="font-medium text-primary hover:underline">AI Hub</Link> — find your run's
              cached entry in the browsable corpus.
            </li>
            <li>
              <a href="/clinical/#/demo" target="fast-clinical" className="font-medium text-primary hover:underline">
                The clinical demo <ExternalLink className="inline h-3 w-3" />
              </a>{" "}
              — the guided tour of all twelve built-in agents surfaced for clinicians, including the sign-off queue
              where drafts like yours get approved.
            </li>
            <li>
              <Link to="/help" className="font-medium text-primary hover:underline">Help</Link>{" "}
              <BookOpen className="inline h-3.5 w-3.5 text-muted-foreground" /> — the full reference for every screen and
              entity you just used.
            </li>
          </ul>
        </Step>
      </div>

      <Card>
        <CardContent className="flex items-start gap-2 pt-4 text-sm text-muted-foreground">
          <FileEdit className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
          <p>
            <span className="font-medium text-foreground">Worth noticing:</span> nothing about your agent is
            special-cased. It went through the same compiler, deploys to the same production, records the same trace,
            and obeys the same draft-and-sign safety rules as the twelve built-ins.{" "}
            <Badge variant="secondary" className="align-middle">Drafts always require human review</Badge>
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
