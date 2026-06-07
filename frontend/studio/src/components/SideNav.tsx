import { NavLink } from "react-router-dom";
import { Bot, Database, Search, ListChecks, ShieldCheck, Sparkles, ExternalLink, BookOpen, GraduationCap } from "lucide-react";
import { cn } from "@shared/lib/utils";

// Agents lead; the library pages that follow are the REAL reusable parts an
// agent's steps reference (evidence sources are executed by the Evidence
// Engine; output schemas genuinely shape the LLM contract). Prompts live on
// each agent's Reason step — assembled from the definition and previewable
// there — so there is no separate prompt manager.
const items = [
  { to: "/agents", label: "Agents", icon: Bot },
  { to: "/components/evidence-sources", label: "Evidence Sources", icon: Search },
  { to: "/components/output-schemas", label: "Schemas", icon: ListChecks },
  { to: "/care-rules", label: "Care Rules", icon: ShieldCheck },
  { to: "/ai-hub", label: "AI Hub", icon: Sparkles },
  { to: "/admin", label: "Admin", icon: Database },
];

// Learning pages, visually separated below the working pages.
const learnItems = [
  { to: "/walkthrough", label: "Walkthrough", icon: GraduationCap },
  { to: "/help", label: "Help", icon: BookOpen },
];

export function SideNav() {
  return (
    <nav className="flex w-56 shrink-0 flex-col gap-1 overflow-y-auto border-r bg-card px-3 py-4">
      {/* The guided tour of all 12 use cases (lives in the clinical app) */}
      <a
        href="/clinical/#/demo"
        target="fast-clinical"
        className="mb-1 flex items-center gap-3 rounded-md border border-primary/30 bg-primary/5 px-3 py-2 text-sm font-medium text-primary hover:bg-primary/10"
      >
        <Sparkles className="h-4 w-4" />
        The demo
        <ExternalLink className="ml-auto h-3.5 w-3.5 opacity-60" />
      </a>
      {items.map(({ to, label, icon: Icon }) => (
        <NavLink
          key={to}
          to={to}
          className={({ isActive }) =>
            cn(
              "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
              isActive ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:bg-secondary hover:text-foreground"
            )
          }
        >
          <Icon className="h-4 w-4" />
          {label}
        </NavLink>
      ))}
      <div className="my-2 border-t" aria-hidden />
      {learnItems.map(({ to, label, icon: Icon }) => (
        <NavLink
          key={to}
          to={to}
          className={({ isActive }) =>
            cn(
              "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
              isActive ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:bg-secondary hover:text-foreground"
            )
          }
        >
          <Icon className="h-4 w-4" />
          {label}
        </NavLink>
      ))}
    </nav>
  );
}
