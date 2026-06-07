import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { ArrowRight, Plus } from "lucide-react";
import { Card, CardContent } from "@shared/components/ui/card";
import { Badge } from "@shared/components/ui/badge";
import { Button } from "@shared/components/ui/button";
import { Input } from "@shared/components/ui/input";
import { Label } from "@shared/components/ui/label";
import { Dialog } from "@shared/components/ui/dialog";
import { api } from "@shared/api/client";
import type { TemplateSummary } from "@shared/api/types";
// Wizard starters: single source of truth shared with the starter-cache builder
// (anyone who creates a starter unchanged gets pre-cached real AI on first run).
import starterCatalogue from "../../../../seed/demo-inputs/agent-starters.json";

const STARTERS = starterCatalogue.starters;

function slugify(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 60) || "new-agent";
}

export function Agents() {
  const navigate = useNavigate();
  const [agents, setAgents] = useState<TemplateSummary[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [newOpen, setNewOpen] = useState(false);
  const [newName, setNewName] = useState("");
  const [starter, setStarter] = useState(STARTERS[0].key);
  const [creating, setCreating] = useState(false);

  useEffect(() => {
    api.agents().then((r) => setAgents(r.templates)).catch((e) => setError((e as Error).message));
  }, []);

  function pickStarter(key: string) {
    setStarter(key);
    const s = STARTERS.find((x) => x.key === key);
    if (s?.suggestedName) setNewName(s.suggestedName);
  }

  async function createAgent() {
    const name = newName.trim();
    if (!name) return;
    const slug = slugify(name);
    const s = STARTERS.find((x) => x.key === starter) ?? STARTERS[0];
    setCreating(true);
    setError(null);
    try {
      await api.saveFlow({ ...s.definition, id: slug, name });
      setNewOpen(false);
      navigate(`/agent/${slug}/build`);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setCreating(false);
    }
  }

  const sorted = [...agents].sort((a, b) => a.name.localeCompare(b.name));

  return (
    <div className="mx-auto max-w-6xl">
      <div className="mb-6 flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Agents</h1>
          <p className="text-muted-foreground">
            Healthcare AI agents you can run and inspect. Open one to give it real inputs and watch it work — every run
            executes on a live IRIS interoperability production.{" "}
            <Link to="/walkthrough" className="font-medium text-primary hover:underline">New here? Build your first agent →</Link>
          </p>
        </div>
        <Button onClick={() => setNewOpen(true)}><Plus className="mr-1 h-4 w-4" />New Agent</Button>
      </div>

      {error && <div className="mb-4 rounded-md bg-destructive/10 px-4 py-2 text-sm text-destructive">{error}</div>}

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {sorted.map((a) => {
          return (
            <Card
              key={a.slug}
              onClick={() => navigate(`/agent/${a.slug}`)}
              className="group flex cursor-pointer flex-col transition-colors hover:border-primary/50 hover:shadow-md"
            >
              <CardContent className="flex flex-1 flex-col p-5">
                <div className="mb-2 flex items-center gap-2">
                  <Badge variant="secondary">{a.category}</Badge>
                </div>
                <h3 className="font-semibold leading-tight">{a.name}</h3>
                <p className="mt-1.5 line-clamp-3 flex-1 text-sm text-muted-foreground">{a.description}</p>
                <div className="mt-4 inline-flex items-center gap-1.5 text-sm font-medium text-primary">
                  Open
                  <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5" />
                </div>
              </CardContent>
            </Card>
          );
        })}
      </div>

      <Dialog
        open={newOpen}
        onClose={() => setNewOpen(false)}
        title="New agent"
        description="Pick a starting point, name it, and it deploys instantly — then refine it in the builder."
        footer={<><Button variant="outline" onClick={() => setNewOpen(false)} disabled={creating}>Cancel</Button><Button onClick={createAgent} disabled={creating || !newName.trim()}>{creating ? "Creating…" : "Create & deploy"}</Button></>}
      >
        <div className="space-y-3">
          <div className="space-y-1.5">
            <Label>Start from</Label>
            <div className="space-y-1.5">
              {STARTERS.map((s) => (
                <button
                  key={s.key}
                  type="button"
                  onClick={() => pickStarter(s.key)}
                  className={`w-full rounded-md border p-2.5 text-left text-sm transition-colors ${starter === s.key ? "border-primary bg-primary/5 ring-1 ring-primary/30" : "hover:bg-secondary/50"}`}
                >
                  <div className="font-medium">{s.title}</div>
                  <div className="text-xs text-muted-foreground">{s.blurb}</div>
                </button>
              ))}
            </div>
          </div>
          <div className="space-y-1">
            <Label>Agent name</Label>
            <Input value={newName} placeholder="e.g. Sepsis Watch" onChange={(e) => setNewName(e.target.value)} autoFocus />
            {starter !== "blank" && STARTERS.find((s) => s.key === starter)?.suggestedName === newName.trim() && (
              <p className="text-xs text-muted-foreground">Keep this name and the first run replays a real pre-built AI result, no key needed.</p>
            )}
          </div>
        </div>
      </Dialog>
    </div>
  );
}
