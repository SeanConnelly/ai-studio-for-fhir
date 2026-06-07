// The left-hand chart navigation (an EHR "Table of Contents"). On a single
// scrolling chart, each entry jumps to (and highlights) its section card.
import type { LucideIcon } from "lucide-react";
import { cn } from "@shared/lib/utils";

export interface ChartMenuItem {
  key: string;
  label: string;
  icon: LucideIcon;
  ai?: boolean;
  /** A small alert count chip (e.g. overdue preventative items). */
  badge?: number;
}

export function ChartMenu({
  items,
  activeKey,
  onJump,
}: {
  items: ChartMenuItem[];
  activeKey?: string;
  onJump: (key: string) => void;
}) {
  return (
    <nav className="space-y-0.5">
      {items.map(({ key, label, icon: Icon, ai, badge }) => {
        const active = key === activeKey;
        return (
          <button
            key={key}
            onClick={() => onJump(key)}
            className={cn(
              "flex w-full items-center gap-2.5 rounded-md px-3 py-2 text-left text-sm font-medium transition-colors",
              active ? "bg-nhs-600 text-white" : "text-foreground/70 hover:bg-nhs-50 hover:text-nhs-800"
            )}
          >
            <Icon className="h-4 w-4 shrink-0" />
            <span className="flex-1 truncate">{label}</span>
            {badge ? (
              <span className={cn("shrink-0 rounded-full px-1.5 text-[10px] font-bold", active ? "bg-white text-nhs-700" : "bg-amber-500 text-white")}>{badge}</span>
            ) : null}
            {ai && (
              <span className={cn("shrink-0 text-[9px] font-semibold uppercase tracking-wide", active ? "text-white/80" : "text-nhs-600")}>AI</span>
            )}
          </button>
        );
      })}
    </nav>
  );
}
