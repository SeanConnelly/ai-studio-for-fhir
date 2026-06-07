// A clinician-facing Clinical Decision Support card, shaped after the HL7 CDS
// Hooks "Card" (summary · severity indicator · plain-language source · optional
// suggestions). Replaces the developer result chrome in the clinician app: no
// "FHIR/SQL/vector/cached/model" wording — that lives only in the collapsed
// "Technical details" disclosure, for the curious.
import * as React from "react";
import { Info, AlertTriangle, OctagonAlert, HelpCircle, ChevronDown, Sparkles } from "lucide-react";
import { cn } from "@shared/lib/utils";
import type { Severity, PlainSourceGroup } from "@shared/lib/clinical";

const SEV: Record<Severity, { ring: string; icon: React.ReactNode; chip: string; label: string }> = {
  info: {
    ring: "border-l-sky-400",
    chip: "bg-sky-100 text-sky-800",
    label: "Advisory",
    icon: <Info className="h-4 w-4 text-sky-500" />,
  },
  warning: {
    ring: "border-l-amber-400",
    chip: "bg-amber-100 text-amber-800",
    label: "Attention",
    icon: <AlertTriangle className="h-4 w-4 text-amber-500" />,
  },
  critical: {
    ring: "border-l-rose-500",
    chip: "bg-rose-100 text-rose-800",
    label: "Critical",
    icon: <OctagonAlert className="h-4 w-4 text-rose-500" />,
  },
};

export interface AdvisoryCardProps {
  title: string;
  severity?: Severity;
  summary?: string;
  sources?: PlainSourceGroup[];
  /** Collapsed, dev-only disclosure (resource JSON, transcript, trace). */
  technical?: React.ReactNode;
  aiDrafted?: boolean;
  /** Coloured left-edge severity accent. Off for the clean chart AI cards. */
  accent?: boolean;
  children?: React.ReactNode;
  footer?: React.ReactNode;
  className?: string;
}

export function AdvisoryCard({
  title,
  severity = "info",
  summary,
  sources,
  technical,
  aiDrafted = true,
  accent = true,
  children,
  footer,
  className,
}: AdvisoryCardProps) {
  const [showWhy, setShowWhy] = React.useState(false);
  const sev = SEV[severity];
  return (
    <div className={cn("rounded-lg border bg-card shadow-sm", accent && "border-l-4", accent && sev.ring, className)}>
      <div className="flex flex-wrap items-center gap-2 px-4 pt-3">
        {accent && sev.icon}
        <span className="font-semibold text-foreground">{title}</span>
        {accent && <span className={cn("rounded-full px-2 py-0.5 text-[11px] font-medium", sev.chip)}>{sev.label}</span>}
        <span className="ml-auto inline-flex items-center gap-1 rounded-full bg-nhs-600 px-2.5 py-1 text-[11px] font-bold uppercase tracking-wide text-white shadow-sm">
          <Sparkles className="h-3.5 w-3.5" /> AI generated
        </span>
      </div>
      <div className="px-4 py-3">
        {summary && <p className="leading-relaxed text-foreground">{summary}</p>}
        {children && <div className={cn(summary && "mt-3")}>{children}</div>}
      </div>

      {footer && <div className="border-t px-4 py-3">{footer}</div>}

      {(aiDrafted || (sources && sources.length > 0) || technical) && (
        <div className="border-t bg-muted/30 px-4 py-2">
          <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-[11px] text-muted-foreground">
            {aiDrafted && <span>AI-generated from this patient's chart — verify before acting.</span>}
            {sources && sources.length > 0 && (
              <button
                onClick={() => setShowWhy((v) => !v)}
                className="inline-flex items-center gap-1 font-medium text-foreground/70 hover:text-foreground"
              >
                <HelpCircle className="h-3.5 w-3.5" />
                Why am I seeing this?
                <ChevronDown className={cn("h-3 w-3 transition-transform", showWhy && "rotate-180")} />
              </button>
            )}
          </div>
          {showWhy && sources && (
            <div className="mt-2 space-y-2">
              {sources.map((g, i) => (
                <div key={i} className="text-xs">
                  <div className="font-medium text-foreground">{g.label}</div>
                  <div className="text-muted-foreground">{g.items.join(" · ")}</div>
                </div>
              ))}
            </div>
          )}
          {technical && (
            <details className="mt-2 text-xs">
              <summary className="cursor-pointer text-muted-foreground/70 hover:text-muted-foreground">
                Technical details (for developers)
              </summary>
              <div className="mt-2">{technical}</div>
            </details>
          )}
        </div>
      )}
    </div>
  );
}
