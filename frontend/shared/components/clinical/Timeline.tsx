// CC-04 Timeline — a simple chronological list (results, encounters, events).
import { cn } from "@shared/lib/utils";

export interface TimelineEvent {
  date: string;
  title: string;
  detail?: string;
  tone?: "default" | "abnormal";
}

export function Timeline({ events }: { events: TimelineEvent[] }) {
  if (events.length === 0) return <p className="text-sm text-muted-foreground">No events.</p>;
  return (
    <ol className="relative border-l border-border pl-4">
      {events.map((e, i) => (
        <li key={i} className="mb-4 last:mb-0">
          <span
            className={cn(
              "absolute -left-[5px] mt-1.5 h-2.5 w-2.5 rounded-full border-2 border-background",
              e.tone === "abnormal" ? "bg-destructive" : "bg-primary"
            )}
          />
          <div className="text-xs text-muted-foreground">{e.date}</div>
          <div className="text-sm font-medium text-foreground">{e.title}</div>
          {e.detail && <div className="text-sm text-muted-foreground">{e.detail}</div>}
        </li>
      ))}
    </ol>
  );
}
