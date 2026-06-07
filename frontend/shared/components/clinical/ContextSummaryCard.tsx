// CC-02 ContextSummaryCard — a labelled card listing short items (problems,
// meds, allergies, a summary section, etc.).
import { Card, CardContent, CardHeader, CardTitle } from "@shared/components/ui/card";

export interface ContextSummaryCardProps {
  heading: string;
  items: string[];
  empty?: string;
}

export function ContextSummaryCard({ heading, items, empty = "None recorded" }: ContextSummaryCardProps) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm">{heading}</CardTitle>
      </CardHeader>
      <CardContent>
        {items.length === 0 ? (
          <p className="text-sm text-muted-foreground">{empty}</p>
        ) : (
          <ul className="space-y-1 text-sm">
            {items.map((it, i) => (
              <li key={i} className="flex gap-2">
                <span className="mt-1.5 h-1 w-1 shrink-0 rounded-full bg-muted-foreground/50" />
                <span>{it}</span>
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}
