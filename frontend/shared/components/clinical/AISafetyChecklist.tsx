// CC-08 AISafetyChecklist — the guardrails attached to an AI result: human review
// required, grounded in the record, no autonomous write-backs.
import { ShieldCheck } from "lucide-react";

export interface AISafetyChecklistProps {
  requiresHumanReview?: boolean;
  items?: string[];
}

export function AISafetyChecklist({ requiresHumanReview = true, items }: AISafetyChecklistProps) {
  const checks = items ?? [
    "Grounded only in the patient's real FHIR record and retrieved guidance",
    requiresHumanReview ? "Any write-back is a draft requiring human review" : "Read-only — no write-back proposed",
    "Not a substitute for clinical judgement",
  ];
  return (
    <div className="rounded-md border bg-muted/30 px-4 py-3">
      <div className="mb-2 flex items-center gap-2 text-sm font-medium text-foreground">
        <ShieldCheck className="h-4 w-4 text-emerald-600" /> Safety
      </div>
      <ul className="space-y-1 text-xs text-muted-foreground">
        {checks.map((c, i) => (
          <li key={i} className="flex gap-2">
            <span className="text-emerald-600">✓</span>
            <span>{c}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
