// A clinician-reviewable draft order/task — the human-readable form of a
// proposed FHIR write-back. Clinicians read a plain order summary and
// Sign / Modify / Decline; they never read or edit raw JSON (that stays in the
// collapsed "Technical details"). Nothing is committed without an explicit Sign.
import * as React from "react";
import { Check, Pencil, X, FileText, ClipboardList, FlaskConical, MessageSquare } from "lucide-react";
import { Button } from "@shared/components/ui/button";
import { CodeBlock } from "@shared/components/ui/code-block";
import { cn } from "@shared/lib/utils";

export interface DraftActionCardProps {
  resourceType: string;
  resource: Record<string, any>;
  busy?: boolean;
  /** Set once a decision has been recorded. */
  decided?: { decision: string; reviewer?: string; committedRef?: string; note?: string } | null;
  onSign?: () => void;
  onDecline?: () => void;
  onModify?: () => void;
  className?: string;
}

interface Readable {
  title: string;
  icon: React.ReactNode;
  lead?: string;
  lines: { label: string; value: string }[];
}

function cleanRef(v?: string): string | undefined {
  if (!v) return undefined;
  // Drop bare "ResourceType/id" references a clinician won't recognise.
  return v.includes("/") ? undefined : v;
}

function summarize(resourceType: string, r: Record<string, any>): Readable {
  const lines: { label: string; value: string }[] = [];
  const push = (label: string, value?: any) => {
    const v = value == null ? "" : String(value).trim();
    if (v) lines.push({ label, value: v });
  };
  switch (resourceType) {
    case "Task":
      push("Priority", r.priority);
      push("Due", r.restriction?.period?.end || r.executionPeriod?.end);
      push("Assigned to", r.owner?.display || cleanRef(r.owner?.reference));
      return {
        title: "Follow-up task",
        icon: <ClipboardList className="h-4 w-4" />,
        lead: r.description || r.code?.text,
        lines,
      };
    case "ServiceRequest":
      push("Priority", r.priority);
      push("When", r.occurrenceDateTime || r.occurrencePeriod?.start);
      return {
        title: "Order request",
        icon: <FlaskConical className="h-4 w-4" />,
        lead: r.code?.text || r.code?.coding?.[0]?.display,
        lines,
      };
    case "DocumentReference":
      push("Type", r.type?.text || r.type?.coding?.[0]?.display);
      push("Category", r.category?.[0]?.text);
      return {
        title: "Clinical document",
        icon: <FileText className="h-4 w-4" />,
        lead: r.description || "Document prepared for the record",
        lines,
      };
    case "Communication": {
      const msg = (r.payload || []).map((p: any) => p.contentString).filter(Boolean).join(" ");
      push("To", r.recipient?.[0]?.display);
      return {
        title: "Patient message",
        icon: <MessageSquare className="h-4 w-4" />,
        lead: msg || r.note?.[0]?.text,
        lines,
      };
    }
    default:
      push("Detail", r.description || r.title || r.code?.text);
      return { title: `Draft ${resourceType}`, icon: <FileText className="h-4 w-4" />, lines };
  }
}

export function DraftActionCard({
  resourceType,
  resource,
  busy,
  decided,
  onSign,
  onDecline,
  onModify,
  className,
}: DraftActionCardProps) {
  const s = summarize(resourceType, resource || {});
  return (
    <div className={cn("rounded-md border border-amber-300 bg-amber-50/40", className)}>
      <div className="flex flex-wrap items-center gap-2 border-b border-amber-200 px-4 py-2">
        <span className="text-amber-700">{s.icon}</span>
        <span className="text-sm font-semibold text-foreground">{s.title}</span>
        <span className="rounded-full bg-amber-100 px-2 py-0.5 text-[11px] font-medium text-amber-800">
          Draft · needs your sign-off
        </span>
      </div>
      <div className="px-4 py-3">
        {s.lead && <p className="text-sm leading-relaxed text-foreground">{s.lead}</p>}
        {s.lines.length > 0 && (
          <dl className="mt-2 grid grid-cols-[auto,1fr] gap-x-3 gap-y-1 text-sm">
            {s.lines.map((l, i) => (
              <React.Fragment key={i}>
                <dt className="text-muted-foreground">{l.label}</dt>
                <dd className="font-medium text-foreground">{l.value}</dd>
              </React.Fragment>
            ))}
          </dl>
        )}
      </div>

      <div className="border-t border-amber-200 px-4 py-2.5">
        {decided ? (
          <div className="text-sm">
            <span
              className={cn(
                "rounded-full px-2 py-0.5 text-[11px] font-medium",
                decided.decision === "approved" ? "bg-emerald-100 text-emerald-800" : "bg-rose-100 text-rose-800"
              )}
            >
              {decided.decision === "approved" ? "Signed & committed" : "Declined"}
            </span>
            {decided.reviewer && <span className="ml-2 text-muted-foreground">by {decided.reviewer}</span>}
            {decided.committedRef && (
              <div className="mt-1 text-xs text-muted-foreground">Saved to the record: {decided.committedRef}</div>
            )}
          </div>
        ) : (
          <div className="flex flex-wrap items-center gap-2">
            <span className="mr-auto text-xs text-muted-foreground">Nothing is saved until you sign.</span>
            {onModify && (
              <Button variant="outline" size="sm" disabled={busy} onClick={onModify}>
                <Pencil className="mr-1 h-3.5 w-3.5" /> Modify
              </Button>
            )}
            {onDecline && (
              <Button variant="outline" size="sm" disabled={busy} onClick={onDecline}>
                <X className="mr-1 h-3.5 w-3.5" /> Decline
              </Button>
            )}
            {onSign && (
              <Button size="sm" disabled={busy} onClick={onSign}>
                <Check className="mr-1 h-3.5 w-3.5" /> {busy ? "Signing…" : "Sign & commit"}
              </Button>
            )}
          </div>
        )}
      </div>

      <details className="border-t border-amber-200 px-4 py-2 text-xs">
        <summary className="cursor-pointer text-muted-foreground/70 hover:text-muted-foreground">
          Technical details (for developers)
        </summary>
        <div className="mt-2">
          <CodeBlock language="json" content={JSON.stringify(resource)} />
        </div>
      </details>
    </div>
  );
}
