import { useEffect, useState } from "react";
import { useParams, useNavigate, Link } from "react-router-dom";
import { ArrowLeft, PlayCircle, Wrench, Layers, History } from "lucide-react";
import { Badge } from "@shared/components/ui/badge";
import { cn } from "@shared/lib/utils";
import { api } from "@shared/api/client";
import type { AgentDetail } from "@shared/api/types";
import { RunPanel } from "@/components/run/RunPanel";
import { BuildView } from "@/components/agent/BuildView";
import { InspectView } from "@/components/agent/InspectView";
import { ActivityView } from "@/components/agent/ActivityView";

const TABS = [
  { key: "run", label: "Run", icon: PlayCircle },
  { key: "build", label: "Build", icon: Wrench },
  { key: "inspect", label: "Inspect", icon: Layers },
  { key: "activity", label: "Activity", icon: History },
] as const;

export function AgentWorkspace() {
  const { slug = "", tab = "run" } = useParams();
  const navigate = useNavigate();
  const [agent, setAgent] = useState<AgentDetail | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setAgent(null);
    setError(null);
    api.agent(slug).then(setAgent).catch((e) => setError((e as Error).message));
  }, [slug]);

  return (
    <div className="mx-auto max-w-5xl">
      <Link to="/agents" className="mb-4 inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground">
        <ArrowLeft className="h-4 w-4" />
        All agents
      </Link>

      {error && <div className="mb-4 rounded-md bg-destructive/10 px-4 py-2 text-sm text-destructive">{error}</div>}

      {agent && (
        <>
          <div className="mb-4">
            <div className="mb-1 flex items-center gap-2">
              <h1 className="text-2xl font-semibold tracking-tight">{agent.name}</h1>
              <Badge variant="secondary">{agent.category}</Badge>
            </div>
            <p className="max-w-3xl text-muted-foreground">{agent.description}</p>
          </div>

          <div className="mb-6 inline-flex items-center gap-1 rounded-md bg-secondary p-1">
            {TABS.map(({ key, label, icon: Icon }) => (
              <button
                key={key}
                onClick={() => navigate(`/agent/${slug}/${key}`)}
                className={cn(
                  "inline-flex items-center gap-1.5 rounded px-3 py-1.5 text-sm font-medium transition-colors",
                  tab === key ? "bg-card text-foreground shadow-sm" : "text-muted-foreground hover:text-foreground"
                )}
              >
                <Icon className="h-4 w-4" />
                {label}
              </button>
            ))}
          </div>

          {tab === "run" && <RunPanel slug={slug} definition={agent.definition} />}
          {tab === "build" && (
            <BuildView
              definition={agent.definition}
              slug={slug}
              isSystem={!!agent.isSystemTemplate}
              hasOverride={!!agent.hasOverride}
            />
          )}
          {tab === "inspect" && <InspectView slug={slug} />}
          {tab === "activity" && <ActivityView slug={slug} />}
        </>
      )}
    </div>
  );
}
