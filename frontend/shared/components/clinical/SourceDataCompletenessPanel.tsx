// CC-09 SourceDataCompletenessPanel — shows which evidence categories were
// available vs missing for a run, so the clinician can judge how complete the
// AI's inputs were.
import { Check, Minus } from "lucide-react";

export interface CompletenessItem {
  label: string;
  present: boolean;
  count?: number;
}

export function SourceDataCompletenessPanel({ items }: { items: CompletenessItem[] }) {
  return (
    <div className="rounded-md border bg-card">
      <div className="border-b px-4 py-2 text-sm font-medium">Source data completeness</div>
      <ul className="divide-y">
        {items.map((it, i) => (
          <li key={i} className="flex items-center gap-2 px-4 py-1.5 text-sm">
            {it.present ? <Check className="h-3.5 w-3.5 text-emerald-600" /> : <Minus className="h-3.5 w-3.5 text-muted-foreground" />}
            <span className={it.present ? "text-foreground" : "text-muted-foreground"}>{it.label}</span>
            {typeof it.count === "number" && it.present && (
              <span className="ml-auto text-xs text-muted-foreground">{it.count}</span>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
}
