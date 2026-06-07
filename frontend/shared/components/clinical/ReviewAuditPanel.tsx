// CC-10 ReviewAuditPanel — the audit trail of human decisions on agent-proposed
// actions (approve / edit / reject), with the committed FHIR reference.
import { Badge } from "@shared/components/ui/badge";
import { toneForStatus } from "@shared/components/clinical/StatusRiskBadgeBar";
import type { AuditEntry } from "@shared/api/types";

export function ReviewAuditPanel({ audit }: { audit: AuditEntry[] }) {
  if (!audit || audit.length === 0) {
    return <p className="text-sm text-muted-foreground">No review decisions recorded yet.</p>;
  }
  return (
    <ul className="space-y-2">
      {audit.map((a, i) => (
        <li key={i} className="rounded-md border bg-card px-3 py-2 text-sm">
          <div className="flex items-center gap-2">
            <Badge variant={toneForStatus(a.decision) === "success" ? "success" : toneForStatus(a.decision) === "danger" ? "warning" : "secondary"}>
              {a.decision}
            </Badge>
            <span className="font-medium">{a.reviewer}</span>
            <span className="ml-auto text-xs text-muted-foreground">{a.timestamp}</span>
          </div>
          {a.committedResourceRef && (
            <div className="mt-1 text-xs text-muted-foreground">Committed: <span className="font-mono">{a.committedResourceRef}</span></div>
          )}
          {a.note && <div className="mt-1 text-xs text-muted-foreground">“{a.note}”</div>}
        </li>
      ))}
    </ul>
  );
}
