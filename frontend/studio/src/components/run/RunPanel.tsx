import { useMemo, useState } from "react";
import { PlayCircle, KeyRound } from "lucide-react";
import { Link } from "react-router-dom";
import { Button } from "@shared/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@shared/components/ui/card";
import { api } from "@shared/api/client";
import type { AgentDefinition, AgentResponse } from "@shared/api/types";
import { InputPanel } from "./InputPanel";
import { ResultView } from "./ResultView";
import { UnderTheHood } from "./UnderTheHood";

export function RunPanel({ slug, definition }: { slug: string; definition: AgentDefinition }) {
  const inputs = useMemo(() => definition.inputs ?? [], [definition]);
  const [values, setValues] = useState<Record<string, string>>(() => {
    const v: Record<string, string> = {};
    for (const i of inputs) v[i.key] = i.default ?? "";
    return v;
  });
  const [resp, setResp] = useState<AgentResponse | null>(null);
  const [running, setRunning] = useState(false);
  const [skipCache, setSkipCache] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function run() {
    setRunning(true);
    setError(null);
    setResp(null);
    try {
      setResp(await api.runAgent(slug, values, skipCache));
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setRunning(false);
    }
  }

  return (
    <div className="space-y-5">
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Inputs</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <InputPanel inputs={inputs} values={values} onChange={(k, val) => setValues((p) => ({ ...p, [k]: val }))} />
          <div className="flex flex-wrap items-center gap-4">
            <Button onClick={run} disabled={running} size="lg">
              <PlayCircle className="h-4 w-4" />
              {running ? "Running…" : "Run agent"}
            </Button>
            <label className="flex items-center gap-2 text-sm text-muted-foreground">
              <input type="checkbox" className="h-4 w-4" checked={skipCache} onChange={(e) => setSkipCache(e.target.checked)} />
              <span>
                Skip cached responses
                <span className="block text-xs">
                  forces this run past the bundled corpus — live with an API key, honestly-labelled deterministic without one; never overwrites the cache
                </span>
              </span>
            </label>
          </div>
        </CardContent>
      </Card>

      {error && <div className="rounded-md bg-destructive/10 px-4 py-2 text-sm text-destructive">{error}</div>}

      {/* Demystify the deterministic tier: say exactly why and how to go live */}
      {resp && (resp.aiTrace?.source ?? resp.source) === "deterministic" && (
        <div className="flex items-start gap-2 rounded-md border border-amber-300 bg-amber-50/60 px-4 py-3 text-sm text-amber-900">
          <KeyRound className="mt-0.5 h-4 w-4 shrink-0" />
          <span>
            This run used the <span className="font-medium">deterministic fallback</span> —{" "}
            {skipCache
              ? "you skipped the cached responses and no live API key is configured."
              : "these exact inputs aren't in the bundled response cache and no live API key is configured."}{" "}
            It is real code over real FHIR data, but not AI.{" "}
            <Link to="/admin" className="font-medium underline">Add an OpenAI-compatible key in Admin</Link> and re-run for live AI.
          </span>
        </div>
      )}

      {resp && !resp.error && (
        <div>
          <ResultView resp={resp} />
          <UnderTheHood resp={resp} />
        </div>
      )}
      {resp && (resp as any).error && (
        <div className="rounded-md bg-destructive/10 px-4 py-2 text-sm text-destructive">{(resp as any).error}</div>
      )}
    </div>
  );
}
