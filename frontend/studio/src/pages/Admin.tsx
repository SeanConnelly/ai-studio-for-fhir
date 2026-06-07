import { useEffect, useState } from "react";
import { Database, RefreshCw, Server, KeyRound, Sparkles, CheckCircle2, XCircle, Loader2 } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@shared/components/ui/card";
import { Button } from "@shared/components/ui/button";
import { Badge } from "@shared/components/ui/badge";
import { Input } from "@shared/components/ui/input";
import { Label } from "@shared/components/ui/label";
import { api } from "@shared/api/client";
import type { StatusResponse } from "@shared/api/types";

/** The AI connection panel: the three-tier story (bundled cache → live BYO key
 *  → deterministic fallback) made visible and configurable. The key lives only
 *  in the instance's temporary store (IRISTEMP): never journaled, never in the
 *  durable database, wiped on every restart — and never echoed back. */
function AiConnectionCard() {
  const [llm, setLlm] = useState<Awaited<ReturnType<typeof api.adminLlmGet>> | null>(null);
  const [key, setKey] = useState("");
  const [model, setModel] = useState("");
  const [endpoint, setEndpoint] = useState("");
  const [saving, setSaving] = useState(false);
  const [testing, setTesting] = useState(false);
  const [test, setTest] = useState<{ ok: number; reply?: string; error?: string } | null>(null);

  function load() {
    api.adminLlmGet().then((r) => { setLlm(r); setModel(r.model); setEndpoint(r.endpoint); }).catch(() => {});
  }
  useEffect(load, []);

  async function save() {
    setSaving(true);
    setTest(null);
    try {
      const r = await api.adminLlmSet({
        ...(key.trim() ? { key: key.trim() } : {}),
        ...(model.trim() && model !== llm?.model ? { model: model.trim() } : {}),
        ...(endpoint.trim() && endpoint !== llm?.endpoint ? { endpoint: endpoint.trim() } : {}),
      });
      setLlm(r);
      setKey("");
    } finally { setSaving(false); }
  }

  async function clearKey() {
    setLlm(await api.adminLlmSet({ clearKey: 1 }));
    setTest(null);
  }

  async function toggleCache() {
    if (!llm) return;
    setLlm(await api.adminLlmSet({ useCache: llm.useCache ? 0 : 1 }));
  }

  async function testConnection() {
    setTesting(true);
    setTest(null);
    try { setTest(await api.adminLlmTest()); } finally { setTesting(false); }
  }

  return (
    <Card className="mb-4">
      <CardHeader><CardTitle className="flex items-center gap-2 text-base"><Sparkles className="h-4 w-4" />AI connection</CardTitle></CardHeader>
      <CardContent className="space-y-4 text-sm">
        <p className="text-muted-foreground">
          Three tiers: prepared demo runs replay <span className="font-medium text-foreground">bundled real LLM output</span> with no
          key; uncached prompts use a <span className="font-medium text-foreground">shared, budget-capped community key</span> for live AI
          (add <span className="font-medium text-foreground">your own OpenAI-compatible key</span> below for unlimited use); when the shared
          budget is spent — or with no key at all — runs fall to a deterministic scaffold that is never presented as AI.
        </p>

        <div className="flex flex-wrap items-center gap-2">
          {llm?.keySet ? (
            <>
              <Badge variant="success" className="gap-1"><KeyRound className="h-3 w-3" />key set · {llm.keyMasked}</Badge>
              <Button variant="outline" size="sm" onClick={clearKey}>Remove key</Button>
            </>
          ) : (
            <Badge variant="secondary" className="gap-1"><KeyRound className="h-3 w-3" />no key — cached + deterministic tiers only</Badge>
          )}
          <Badge variant={llm?.useCache ? "success" : "warning"} className="cursor-pointer" onClick={toggleCache} title="Toggle whether prepared runs replay from the bundled cache">
            cache replay: {llm?.useCache ? "on" : "off (all runs live)"}
          </Badge>
        </div>

        <div className="grid gap-3 md:grid-cols-3">
          <div className="space-y-1">
            <Label>API key (never stored — wiped on restart)</Label>
            <Input type="password" value={key} placeholder={llm?.keySet ? "•••• (set)" : "sk-… / xai-…"} onChange={(e) => setKey(e.target.value)} />
          </div>
          <div className="space-y-1">
            <Label>Model</Label>
            <Input value={model} onChange={(e) => setModel(e.target.value)} />
          </div>
          <div className="space-y-1">
            <Label>Endpoint (OpenAI-compatible)</Label>
            <Input value={endpoint} onChange={(e) => setEndpoint(e.target.value)} />
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <Button size="sm" onClick={save} disabled={saving}>{saving ? "Saving…" : "Save connection"}</Button>
          <Button size="sm" variant="outline" onClick={testConnection} disabled={testing || !llm?.keySet}>
            {testing ? <Loader2 className="mr-1 h-4 w-4 animate-spin" /> : null}Test connection
          </Button>
          {test && (test.ok
            ? <span className="inline-flex items-center gap-1 text-emerald-600"><CheckCircle2 className="h-4 w-4" />Live reply: "{test.reply}"</span>
            : <span className="inline-flex items-center gap-1 text-destructive"><XCircle className="h-4 w-4" />{test.error}</span>)}
        </div>
        <p className="text-xs text-muted-foreground">The key is held only in the instance's temporary store (IRISTEMP): never journaled, never written to the durable database, never logged, never returned by the API — and wiped on every restart.</p>
      </CardContent>
    </Card>
  );
}

export function Admin() {
  const [status, setStatus] = useState<StatusResponse | null>(null);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  function load() {
    api.status().then(setStatus).catch(() => {});
  }
  useEffect(load, []);

  async function reseed() {
    setBusy(true);
    setMsg(null);
    try {
      await api.adminSeed();
      setMsg("Seed data reloaded.");
      load();
    } catch (e) {
      setMsg((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mx-auto max-w-3xl">
      <div className="mb-5">
        <h1 className="text-2xl font-semibold tracking-tight">Admin</h1>
        <p className="text-muted-foreground">AI connection, runtime status, and demo-data management.</p>
      </div>

      <AiConnectionCard />

      <Card className="mb-4">
        <CardHeader><CardTitle className="flex items-center gap-2 text-base"><Server className="h-4 w-4" />Runtime</CardTitle></CardHeader>
        <CardContent className="space-y-1 text-sm">
          <div className="flex justify-between"><span className="text-muted-foreground">Product version</span><span className="font-mono">{status?.version}</span></div>
          <div className="flex justify-between"><span className="text-muted-foreground">Namespace</span><span className="font-mono">{status?.namespace}</span></div>
          <div className="flex justify-between gap-4"><span className="text-muted-foreground">IRIS</span><span className="truncate text-right font-mono text-xs">{status?.iris}</span></div>
        </CardContent>
      </Card>

      <Card className="mb-4">
        <CardHeader><CardTitle className="flex items-center gap-2 text-base"><Database className="h-4 w-4" />Persistent records</CardTitle></CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
            {status && Object.entries(status.counts).map(([k, v]) => (
              <div key={k} className="rounded-md border bg-secondary/40 px-3 py-2">
                <div className="text-lg font-semibold">{v}</div>
                <div className="text-xs text-muted-foreground">{k}</div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      <div className="flex items-center gap-3">
        <Button onClick={reseed} disabled={busy}>
          <RefreshCw className={busy ? "h-4 w-4 animate-spin" : "h-4 w-4"} /> {busy ? "Reseeding…" : "Reload seed data"}
        </Button>
        {msg && <Badge variant="secondary">{msg}</Badge>}
      </div>
    </div>
  );
}
