// Cedar Valley Health — the clinician-facing app shell. A teal hospital brand,
// clearly distinct from the developer Studio. Top bar + primary nav
// (Patient Search, Worklists); the patient chart carries its own left-hand menu.
import { NavLink, Outlet } from "react-router-dom";
import { TreePine, ListChecks, Users, FileCheck2, Search, MessageSquareText, Microscope, Sparkles } from "lucide-react";
import { cn } from "@shared/lib/utils";

const nav = [
  { to: "/demo", label: "The demo", icon: Sparkles, end: false },
  { to: "/", label: "Worklist", icon: ListChecks, end: true },
  { to: "/search", label: "Patients", icon: Users, end: false },
  { to: "/prior-auth", label: "PA Queue", icon: FileCheck2, end: false },
  { to: "/trials", label: "Trials", icon: Microscope, end: false },
  { to: "/ask", label: "Ask", icon: Search, end: false },
  { to: "/triage", label: "Triage", icon: MessageSquareText, end: false },
];

export function ClinicalShell() {
  return (
    <div className="flex h-full flex-col bg-background text-foreground">
      <header className="shrink-0 border-b bg-nhs-600 text-white">
        <div className="mx-auto flex max-w-6xl items-center gap-3 px-6 py-3">
          <div className="flex items-center gap-2">
            <div className="flex h-8 w-8 items-center justify-center rounded-md bg-white/15">
              <TreePine className="h-5 w-5" />
            </div>
            <div className="leading-tight">
              <div className="text-base font-semibold tracking-tight">Cedar Valley Health</div>
              <div className="text-[10px] uppercase tracking-wide text-white/70">Clinician workspace</div>
            </div>
          </div>
          <nav className="ml-6 flex items-center gap-1">
            {nav.map(({ to, label, icon: Icon, end }) => (
              <NavLink
                key={to}
                to={to}
                end={end}
                className={({ isActive }) =>
                  cn(
                    "flex items-center gap-1.5 rounded-md px-3 py-1.5 text-sm font-medium transition-colors",
                    isActive ? "bg-white/20" : "text-white/80 hover:bg-white/10 hover:text-white"
                  )
                }
              >
                <Icon className="h-4 w-4" />
                {label}
              </NavLink>
            ))}
          </nav>
          <div className="ml-auto flex items-center gap-4">
            <a href="/clinical/#/portal" target="fast-phone" className="text-xs text-white/60 hover:text-white" title="Open the patient portal (simulated phone app)">Patient portal →</a>
            <a href="/fhir-agent-studio/" target="fast-studio" className="text-xs text-white/60 hover:text-white" title="Open the developer Studio">Studio →</a>
          </div>
        </div>
      </header>
      <main className="flex-1 overflow-y-auto">
        <div className="mx-auto max-w-6xl px-6 py-6">
          <Outlet />
        </div>
      </main>
    </div>
  );
}
