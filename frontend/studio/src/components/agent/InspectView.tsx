import { useEffect, useState } from "react";
import { ArrowRight, Cpu, FileCode2 } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@shared/components/ui/card";
import { Badge } from "@shared/components/ui/badge";
import { CodeBlock } from "@shared/components/ui/code-block";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@shared/components/ui/tabs";
import { api } from "@shared/api/client";
import type { MappingResponse } from "@shared/api/types";

const DOT: Record<string, string> = {
  "Business Service": "bg-sky-500",
  "Business Process": "bg-violet-500",
  "Business Operation": "bg-teal-500",
};

function langFor(name: string) {
  if (name.endsWith(".json")) return "json";
  if (name.endsWith(".md")) return "markdown";
  if (name.endsWith(".xml")) return "xml";
  return undefined;
}

/** Under-the-hood architecture: how the agent maps to a real IRIS
 *  interoperability production, plus the generated build output (artefacts). */
export function InspectView({ slug }: { slug: string }) {
  const [mapping, setMapping] = useState<MappingResponse | null>(null);
  const [artifacts, setArtifacts] = useState<string[]>([]);
  const [active, setActive] = useState<string>("");
  const [content, setContent] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.mapping(slug).then(setMapping).catch((e) => setError((e as Error).message));
    // Lazily compile so we can show the generated build output.
    (async () => {
      try {
        await api.createFlow(slug);
        const c = await api.compile(slug);
        setArtifacts(c.artifacts);
        setActive(c.artifacts[0] ?? "");
      } catch {
        /* build output is optional */
      }
    })();
  }, [slug]);

  useEffect(() => {
    if (active && !content[active]) {
      api.artifact(slug, active).then((t) => setContent((p) => ({ ...p, [active]: t }))).catch(() => {});
    }
  }, [active, slug, content]);

  return (
    <div className="space-y-5">
      {error && <div className="rounded-md bg-destructive/10 px-4 py-2 text-sm text-destructive">{error}</div>}

      {mapping && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-base"><Cpu className="h-4 w-4" />Runs on IRIS Interoperability</CardTitle>
            <p className="text-sm text-muted-foreground">
              Each part of this agent maps to a real HealthConnect-style component in a live <code className="rounded bg-secondary px-1">Ens.Production</code>.
              Every run is an actual message flow you can open in the IRIS Management Portal's Visual Trace.
            </p>
          </CardHeader>
          <CardContent className="space-y-2">
            {mapping.mappings.map((m, i) => (
              <div key={i} className="flex items-center gap-3 rounded-md border p-2.5">
                <div className="min-w-0 flex-1">
                  <div className="text-sm font-medium">{m.portalConcept}</div>
                  <div className="truncate text-xs text-muted-foreground">{m.portalDetail}</div>
                </div>
                <ArrowRight className="h-4 w-4 shrink-0 text-muted-foreground" />
                <div className="flex min-w-0 flex-1 items-center gap-2">
                  <span className={`h-2 w-2 shrink-0 rounded-full ${DOT[m.healthConnectType] ?? "bg-muted-foreground"}`} />
                  <div className="min-w-0">
                    <Badge variant="outline" className="mb-0.5">{m.healthConnectType}</Badge>
                    <div className="truncate font-mono text-xs text-muted-foreground">{m.healthConnectComponent}</div>
                  </div>
                </div>
              </div>
            ))}
            <div className="mt-1 flex items-center gap-2 rounded-md bg-secondary/60 px-3 py-2 text-xs text-muted-foreground">
              <Cpu className="h-3.5 w-3.5" />
              Orchestrated by {mapping.orchestrator}
            </div>
          </CardContent>
        </Card>
      )}

      {artifacts.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-base"><FileCode2 className="h-4 w-4" />Generated build output</CardTitle>
            <p className="text-sm text-muted-foreground">
              The studio compiles this agent into {artifacts.length} runtime artefacts, stored in IRIS — the executable recipe, prompt,
              output schema, FHIR action template, production settings, mapping, and an IPM module manifest.
            </p>
          </CardHeader>
          <CardContent>
            <Tabs value={active} onValueChange={setActive}>
              <TabsList>
                {artifacts.map((a) => <TabsTrigger key={a} value={a}>{a}</TabsTrigger>)}
              </TabsList>
              {artifacts.map((a) => (
                <TabsContent key={a} value={a}>
                  <CodeBlock language={langFor(a)} content={content[a] ?? "Loading…"} />
                </TabsContent>
              ))}
            </Tabs>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
