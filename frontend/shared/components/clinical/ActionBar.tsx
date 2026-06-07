// CC-06 ActionBar — the review controls for a proposed (draft) FHIR write-back.
// Approve / Edit / Reject; nothing is committed without an explicit Approve.
import { Check, Pencil, X } from "lucide-react";
import { Button } from "@shared/components/ui/button";

export interface ActionBarProps {
  resourceType?: string;
  disabled?: boolean;
  busy?: boolean;
  onApprove?: () => void;
  onEdit?: () => void;
  onReject?: () => void;
}

export function ActionBar({ resourceType, disabled, busy, onApprove, onEdit, onReject }: ActionBarProps) {
  return (
    <div className="flex flex-wrap items-center gap-2">
      <span className="mr-auto text-xs text-muted-foreground">
        {resourceType ? `Draft ${resourceType} — requires human review before it is committed.` : "Requires human review before it is committed."}
      </span>
      {onEdit && (
        <Button variant="outline" size="sm" disabled={disabled || busy} onClick={onEdit}>
          <Pencil className="mr-1 h-3.5 w-3.5" /> Edit
        </Button>
      )}
      {onReject && (
        <Button variant="outline" size="sm" disabled={disabled || busy} onClick={onReject}>
          <X className="mr-1 h-3.5 w-3.5" /> Reject
        </Button>
      )}
      {onApprove && (
        <Button size="sm" disabled={disabled || busy} onClick={onApprove}>
          <Check className="mr-1 h-3.5 w-3.5" /> {busy ? "Committing…" : "Approve & commit"}
        </Button>
      )}
    </div>
  );
}
