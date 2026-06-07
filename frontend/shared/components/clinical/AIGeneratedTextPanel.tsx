// CC-07 AIGeneratedTextPanel — wraps any AI-authored content with a clear AI
// label, the review state (Draft / Reviewed / Edited / Approved / Rejected), the
// source badge (cached / live / deterministic), and optional review actions.
// All AI output in both apps is rendered through this so it is never mistaken for
// a human-authored or system-of-record fact.
import * as React from "react";
import { Sparkles } from "lucide-react";
import { Badge } from "@shared/components/ui/badge";
import { cn } from "@shared/lib/utils";

export type ReviewState = "draft" | "reviewed" | "edited" | "approved" | "rejected";

export interface AIGeneratedTextPanelProps {
  title?: string;
  source?: string; // cached | live (model) | deterministic
  reviewState?: ReviewState;
  model?: string;
  children: React.ReactNode;
  footer?: React.ReactNode;
  className?: string;
}

const stateLabel: Record<ReviewState, string> = {
  draft: "Draft", reviewed: "Reviewed", edited: "Edited", approved: "Approved", rejected: "Rejected",
};

export function AIGeneratedTextPanel({ title = "AI-generated", source, reviewState = "draft", model, children, footer, className }: AIGeneratedTextPanelProps) {
  return (
    <div className={cn("rounded-lg border border-primary/30 bg-primary/[0.03]", className)}>
      <div className="flex flex-wrap items-center gap-2 border-b border-primary/20 px-4 py-2">
        <Sparkles className="h-4 w-4 text-primary" />
        <span className="text-sm font-medium text-foreground">{title}</span>
        <Badge variant="outline" className="border-primary/40 text-primary">AI · {stateLabel[reviewState]}</Badge>
        {source && <Badge variant="secondary">{source}</Badge>}
        <span className="ml-auto text-[11px] text-muted-foreground">
          AI-generated — verify before acting{model ? ` · ${model}` : ""}
        </span>
      </div>
      <div className="px-4 py-3 text-sm text-foreground">{children}</div>
      {footer && <div className="border-t border-primary/20 px-4 py-2">{footer}</div>}
    </div>
  );
}
