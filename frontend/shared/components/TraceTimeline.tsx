import { useState } from "react";
import {
  Radio, GitBranch, Database, Search, Sparkles, FileEdit, ChevronRight, CheckCircle2, FileWarning,
} from "lucide-react";
import { cn } from "@shared/lib/utils";
import { Badge } from "@shared/components/ui/badge";
import { CodeBlock } from "@shared/components/ui/code-block";
import type { TraceStep } from "@shared/api/types";

const ICONS: Record<string, typeof Radio> = {
  AgentTriggerService: Radio,
  AgentOrchestratorProcess: GitBranch,
  FHIRReadOperation: Database,
  SQLQueryOperation: Database,
  VectorSearchOperation: Search,
  AIHubOperation: Sparkles,
  FHIRWritebackOperation: FileEdit,
};

function statusBadge(status: string) {
  if (status === "drafted") return <Badge variant="warning">drafted</Badge>;
  if (status === "error") return <Badge variant="warning">error</Badge>;
  return <Badge variant="success">ok</Badge>;
}

export function TraceTimeline({ steps }: { steps: TraceStep[] }) {
  return (
    <ol className="relative ml-3 border-l-2 border-border">
      {steps.map((s, i) => (
        <TraceRow key={i} step={s} last={i === steps.length - 1} />
      ))}
    </ol>
  );
}

/** Split a step payload into request / response blocks where the message flow is
 *  captured (RAG ops record {request,response}; AIHub records the LLM transcript). */
function splitIO(payload: any): { label: string; content: string }[] | null {
  if (payload == null || typeof payload !== "object") return null;
  if ("request" in payload || "response" in payload) {
    const out: { label: string; content: string }[] = [];
    if (payload.request != null) out.push({ label: "Request sent to the operation", content: JSON.stringify(payload.request, null, 2) });
    if (payload.response != null) out.push({ label: "Response returned", content: JSON.stringify(payload.response, null, 2) });
    return out;
  }
  if ("completionRequest" in payload || "rawResponse" in payload) {
    const out: { label: string; content: string }[] = [];
    if (payload.completionRequest) out.push({ label: "Combined completion request", content: String(payload.completionRequest) });
    if (payload.rawResponse) out.push({ label: "Raw LLM response", content: String(payload.rawResponse) });
    return out.length ? out : null;
  }
  return null;
}

function TraceRow({ step, last }: { step: TraceStep; last: boolean }) {
  const [open, setOpen] = useState(false);
  const Icon = ICONS[step.componentName] ?? CheckCircle2;
  const hasPayload = step.payload != null;
  const io = splitIO(step.payload);
  return (
    <li className={cn("relative pl-8", last ? "pb-0" : "pb-5")}>
      <span className="absolute -left-[13px] flex h-6 w-6 items-center justify-center rounded-full bg-primary text-primary-foreground ring-4 ring-background">
        <Icon className="h-3.5 w-3.5" />
      </span>
      <div className="rounded-md border bg-card p-3">
        <div className="flex items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <span className="text-[11px] font-medium uppercase tracking-wide text-muted-foreground">{step.componentType}</span>
            <span className="font-medium">{step.componentName}</span>
          </div>
          <div className="flex items-center gap-2">
            {step.durationMs > 0 && <span className="text-xs text-muted-foreground">{step.durationMs} ms</span>}
            {statusBadge(step.status)}
          </div>
        </div>
        <p className="mt-1 text-sm text-muted-foreground">{step.detail}</p>
        {hasPayload && (
          <>
            <button
              onClick={() => setOpen((o) => !o)}
              className="mt-2 inline-flex items-center gap-1 text-xs font-medium text-primary hover:underline"
            >
              <ChevronRight className={cn("h-3.5 w-3.5 transition-transform", open && "rotate-90")} />
              {open ? "Hide messages" : "Show request & response"}
            </button>
            {open && (
              io ? (
                <div className="mt-2 space-y-2">
                  {io.map((b, i) => (
                    <div key={i}>
                      <div className="mb-1 text-[11px] font-medium uppercase tracking-wide text-muted-foreground">{b.label}</div>
                      <CodeBlock language="json" content={b.content} />
                    </div>
                  ))}
                </div>
              ) : (
                <CodeBlock className="mt-2" language="json" content={JSON.stringify(step.payload, null, 2)} />
              )
            )}
          </>
        )}
      </div>
    </li>
  );
}

export { FileWarning };
