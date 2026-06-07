// CC-05 StatusRiskBadgeBar — a row of status / acuity / risk badges.
import { Badge } from "@shared/components/ui/badge";

export interface StatusBadge {
  label: string;
  tone?: "default" | "secondary" | "outline" | "success" | "warning" | "accent" | "danger";
}

function variantFor(tone?: StatusBadge["tone"]) {
  if (tone === "danger") return "warning" as const; // reuse amber/destructive styling
  return (tone ?? "secondary") as "default" | "secondary" | "outline" | "success" | "warning" | "accent";
}

/** Map a clinical status/acuity/risk word to a badge tone. */
export function toneForStatus(s?: string): StatusBadge["tone"] {
  const v = (s || "").toLowerCase();
  if (["high", "emergent", "major", "overdue", "needs_review", "rejected"].includes(v)) return "danger";
  if (["moderate", "urgent", "open", "uncertain"].includes(v)) return "warning";
  if (["low", "routine", "completed", "met", "eligible", "approved", "on track", "improving"].includes(v)) return "success";
  return "secondary";
}

export function StatusRiskBadgeBar({ badges }: { badges: StatusBadge[] }) {
  return (
    <div className="flex flex-wrap items-center gap-2">
      {badges.map((b, i) => (
        <Badge key={i} variant={b.tone === "danger" ? "warning" : variantFor(b.tone)} className={b.tone === "danger" ? "bg-destructive" : undefined}>
          {b.label}
        </Badge>
      ))}
    </div>
  );
}
