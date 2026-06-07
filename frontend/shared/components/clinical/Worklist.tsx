// CC-11 Worklist — a prioritised, cohort-backed list of patients for a clinical
// queue (abnormal results, care gaps, readmission risk, prior-auth, etc.). Each
// row may carry a one-line AI summary and a suggested next action.
import { ChevronRight } from "lucide-react";
import { Badge } from "@shared/components/ui/badge";
import { toneForStatus, type StatusBadge } from "@shared/components/clinical/StatusRiskBadgeBar";
import { cn } from "@shared/lib/utils";

export interface WorklistRow {
  ref: string;
  name: string;
  secondary?: string;
  status?: string;
  summary?: string;
  nextAction?: string;
}

export interface WorklistProps {
  rows: WorklistRow[];
  onOpen?: (ref: string) => void;
  emptyText?: string;
}

export function Worklist({ rows, onOpen, emptyText = "No patients in this worklist." }: WorklistProps) {
  if (rows.length === 0) return <p className="text-sm text-muted-foreground">{emptyText}</p>;
  return (
    <ul className="divide-y rounded-lg border bg-card">
      {rows.map((r) => {
        const tone = toneForStatus(r.status) as StatusBadge["tone"];
        return (
          <li
            key={r.ref}
            className={cn("flex items-center gap-3 px-4 py-3", onOpen && "cursor-pointer hover:bg-secondary/50")}
            onClick={() => onOpen?.(r.ref)}
          >
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2">
                <span className="truncate font-medium text-foreground">{r.name}</span>
                {r.status && (
                  <Badge variant={tone === "danger" ? "warning" : tone === "success" ? "success" : "secondary"} className={tone === "danger" ? "bg-destructive" : undefined}>
                    {r.status}
                  </Badge>
                )}
              </div>
              {r.secondary && <div className="text-xs text-muted-foreground">{r.secondary}</div>}
              {r.summary && <div className="mt-0.5 truncate text-sm text-muted-foreground">{r.summary}</div>}
              {r.nextAction && <div className="mt-0.5 text-xs text-primary">Next: {r.nextAction}</div>}
            </div>
            {onOpen && <ChevronRight className="h-4 w-4 shrink-0 text-muted-foreground" />}
          </li>
        );
      })}
    </ul>
  );
}
