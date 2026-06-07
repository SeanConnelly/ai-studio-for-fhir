import { useState } from "react";
import { ChevronRight, Quote, Cpu, MessagesSquare, ExternalLink } from "lucide-react";
import { Badge } from "@shared/components/ui/badge";
import { CodeBlock } from "@shared/components/ui/code-block";
import { TraceTimeline } from "@shared/components/TraceTimeline";
import { cn } from "@shared/lib/utils";
import type { AgentResponse } from "@shared/api/types";

function sourceBadge(source?: string) {
  if (!source) return null;
  if (source === "cached") return <Badge variant="success">AI: cached real LLM</Badge>;
  if (source.startsWith("live")) return <Badge variant="default">AI: live · {source.replace(/^live \(|\)$/g, "")}</Badge>;
  if (source === "deterministic") return <Badge variant="secondary">AI: deterministic fallback</Badge>;
  return <Badge variant="secondary">AI: {source}</Badge>;
}

/** A labelled, monospace block of prompt/response text. */
function TranscriptBlock({ title, body }: { title: string; body?: string }) {
  if (!body) return null;
  return (
    <div>
      <div className="mb-1 text-xs font-medium text-muted-foreground">{title}</div>
      <pre className="max-h-72 overflow-auto rounded-md border bg-muted/40 p-3 text-xs leading-relaxed whitespace-pre-wrap break-words">
        {body}
      </pre>
    </div>
  );
}

/** Optional diagnostic reveal: exactly how this run executed inside IRIS —
 *  the evidence it gathered, the real LLM completion transcript (base prompt →
 *  combined request → raw response), and the production message trace. */
export function UnderTheHood({ resp }: { resp: AgentResponse }) {
  const [open, setOpen] = useState(false);
  const stepCount = resp.trace?.length ?? 0;
  const ai = resp.aiTrace;

  return (
    <div className="mt-5 rounded-lg border bg-card">
      <button
        onClick={() => setOpen((o) => !o)}
        className="flex w-full items-center justify-between gap-2 px-5 py-3 text-left"
      >
        <span className="flex items-center gap-2 text-sm font-medium">
          <Cpu className="h-4 w-4 text-muted-foreground" />
          Under the hood
          <span className="text-muted-foreground">— {stepCount} interoperability steps</span>
        </span>
        <span className="flex items-center gap-2">
          {sourceBadge(resp.source)}
          <ChevronRight className={cn("h-4 w-4 text-muted-foreground transition-transform", open && "rotate-90")} />
        </span>
      </button>

      {open && (
        <div className="space-y-5 border-t px-5 py-4">
          <p className="text-xs text-muted-foreground">
            This run executed as a real message flow on the IRIS interoperability production — Business Service →
            Process → Operations. The evidence below was gathered by real FHIR / SQL / vector operations, combined
            with the agent's base prompt, and sent to the LLM; the LLM's response is the result shown above.
          </p>

          {/* The real completion transcript — what was actually sent and returned. */}
          {ai && (ai.basePrompt || ai.completionRequest || ai.rawResponse) && (
            <div>
              <div className="mb-2 flex items-center gap-2 text-sm font-medium">
                <MessagesSquare className="h-4 w-4" />
                LLM completion transcript
                {ai.model && <Badge variant="outline" className="font-mono text-[10px]">{ai.model}</Badge>}
                {sourceBadge(ai.source)}
              </div>
              <div className="space-y-3">
                <TranscriptBlock title="1 · Base prompt (system)" body={ai.basePrompt} />
                <TranscriptBlock title="2 · Combined completion request (base prompt + evidence + question)" body={ai.completionRequest} />
                <TranscriptBlock title="3 · Raw LLM response → parsed into the result above" body={ai.rawResponse} />
              </div>
            </div>
          )}

          {resp.evidence && resp.evidence.length > 0 && (
            <div>
              <div className="mb-2 flex items-center gap-2 text-sm font-medium"><Quote className="h-4 w-4" />Evidence gathered (RAG)</div>
              <div className="grid gap-2">
                {resp.evidence.map((e, i) => (
                  <div key={i} className="flex items-start gap-3 rounded-md border p-2.5">
                    <Badge variant="outline" className="shrink-0">{e.evidenceType}</Badge>
                    <div className="min-w-0">
                      <div className="text-sm font-medium">{e.display}</div>
                      <div className="text-xs text-muted-foreground">{e.source} — {e.relevance}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {resp.trace && resp.trace.length > 0 && (
            <div>
              <div className="mb-3 flex items-center justify-between gap-2">
                <span className="text-sm font-medium">Runtime trace</span>
                {resp.sessionId && (
                  <a
                    href={`/csp/healthshare/fast/EnsPortal.VisualTrace.zen?SESSIONID=${resp.sessionId}`}
                    target="iris-portal"
                    rel="noreferrer"
                    className="inline-flex items-center gap-1 text-xs font-medium text-primary hover:underline"
                    title="The same run, in the IRIS Management Portal's engine-level message viewer (session login required)"
                  >
                    Open in IRIS Visual Trace (session {resp.sessionId})
                    <ExternalLink className="h-3 w-3" />
                  </a>
                )}
              </div>
              <TraceTimeline steps={resp.trace} />
            </div>
          )}
        </div>
      )}
    </div>
  );
}
