// AI Hub — the transparency page. Explains the three-tier LLM seam, shows live
// tier counters and the record/replay corpus, and lets anyone open ANY cache
// entry to read the exact prompt preview and the exact stored completion.
// "Nothing up our sleeves": every cached reply is a real model output,
// generated once and replayed verbatim.
import { useEffect, useState } from "react";
import { Sparkles, Database, KeyRound, Cog, Search, Loader2 } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@shared/components/ui/card";
import { Badge } from "@shared/components/ui/badge";
import { Input } from "@shared/components/ui/input";
import { Dialog } from "@shared/components/ui/dialog";
import { api } from "@shared/api/client";

type Llm = Awaited<ReturnType<typeof api.adminLlmGet>>;
type Entry = Awaited<ReturnType<typeof api.adminLlmCache>>["entries"][number];
type Detail = Awaited<ReturnType<typeof api.adminLlmCacheEntry>>;

function TierCard({ n, title, body, badge }: { n: number; title: string; body: string; badge?: React.ReactNode }) {
  return (
    <div className="rounded-lg border bg-card p-4">
      <div className="mb-1 flex items-center gap-2">
        <span className="flex h-5 w-5 items-center justify-center rounded-full bg-primary/10 text-[11px] font-bold text-primary">{n}</span>
        <span className="text-sm font-semibold">{title}</span>
        {badge}
      </div>
      <p className="text-xs leading-relaxed text-muted-foreground">{body}</p>
    </div>
  );
}

export function AiHub() {
  const [llm, setLlm] = useState<Llm | null>(null);
  const [entries, setEntries] = useState<Entry[] | null>(null);
  const [total, setTotal] = useState(0);
  const [kind, setKind] = useState("");
  const [q, setQ] = useState("");
  const [detail, setDetail] = useState<Detail | null>(null);
  const [loadingDetail, setLoadingDetail] = useState(false);

  useEffect(() => { api.adminLlmGet().then(setLlm).catch(() => {}); }, []);
  useEffect(() => {
    setEntries(null);
    const t = setTimeout(() => {
      api.adminLlmCache({ kind: kind || undefined, q: q || undefined, limit: 50 })
        .then((r) => { setEntries(r.entries); setTotal(r.total); })
        .catch(() => setEntries([]));
    }, q ? 350 : 0);
    return () => clearTimeout(t);
  }, [kind, q]);

  async function open(id: string) {
    setLoadingDetail(true);
    try { setDetail(await api.adminLlmCacheEntry(id)); } finally { setLoadingDetail(false); }
  }

  const tiers = llm?.tiers;
  const counts = llm?.cacheCounts || {};

  return (
    <div className="mx-auto max-w-5xl">
      <div className="mb-5">
        <h1 className="flex items-center gap-2 text-2xl font-semibold tracking-tight"><Sparkles className="h-6 w-6 text-primary" />AI Hub</h1>
        <p className="max-w-3xl text-muted-foreground">
          How every agent gets its intelligence — and how to check it for yourself. Each run assembles a prompt from the
          agent's instructions plus the real evidence gathered for the patient, then resolves it through three tiers.
          The cache key is a hash of the <span className="font-medium text-foreground">entire prompt including the evidence</span>:
          change anything about the patient and the system cannot serve a stale answer.
        </p>
      </div>

      <div className="mb-5 grid gap-3 md:grid-cols-3">
        <TierCard n={1} title="Bundled real completions" body="Prepared demo runs replay genuine Grok output, generated once at build time and stored verbatim — browsable in full below. No key needed."
          badge={tiers ? <Badge variant="success">{tiers.cached} this session</Badge> : undefined} />
        <TierCard n={2} title="Live, with your key" body="Anything not in the corpus calls a real OpenAI-compatible endpoint live (configure in Admin). The response is cached so the run is reproducible."
          badge={tiers ? <Badge variant="default">{tiers.live} this session</Badge> : undefined} />
        <TierCard n={3} title="Deterministic fallback" body="No key and no cache entry: plain code over real FHIR data, clearly badged and never presented as AI."
          badge={tiers ? <Badge variant="secondary">{tiers.deterministic} this session</Badge> : undefined} />
      </div>

      <Card className="mb-5">
        <CardHeader className="pb-2"><CardTitle className="flex items-center gap-2 text-base"><Cog className="h-4 w-4" />Connection</CardTitle></CardHeader>
        <CardContent className="flex flex-wrap items-center gap-2 text-sm">
          <Badge variant="outline" className="font-mono">{llm?.model || "…"}</Badge>
          <Badge variant="outline" className="font-mono">{llm?.endpoint || "…"}</Badge>
          <Badge variant="outline">prompt v{llm?.promptVersion ?? "…"}</Badge>
          {llm?.keySet ? <Badge variant="success" className="gap-1"><KeyRound className="h-3 w-3" />key set</Badge> : <Badge variant="secondary" className="gap-1"><KeyRound className="h-3 w-3" />no key — cached + deterministic only</Badge>}
          <span className="text-xs text-muted-foreground">Manage in Admin.</span>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="pb-3">
          <CardTitle className="flex flex-wrap items-center gap-2 text-base">
            <Database className="h-4 w-4" />
            The record/replay corpus
            {Object.entries(counts).map(([k, v]) => <Badge key={k} variant="secondary">{v} {k}s</Badge>)}
          </CardTitle>
          <div className="flex flex-wrap items-center gap-2 pt-1">
            <div className="relative">
              <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
              <Input className="w-72 pl-8" placeholder="Search prompts and completions…" value={q} onChange={(e) => setQ(e.target.value)} />
            </div>
            <select className="h-9 rounded-md border bg-background px-3 text-sm" value={kind} onChange={(e) => setKind(e.target.value)}>
              <option value="">all kinds</option>
              <option value="completion">completions</option>
              <option value="embedding">embeddings</option>
            </select>
            {entries && <span className="text-xs text-muted-foreground">{total} match{total === 1 ? "" : "es"} · showing {entries.length}</span>}
          </div>
        </CardHeader>
        <CardContent className="p-0">
          {!entries ? (
            <p className="flex items-center gap-2 px-5 pb-5 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" /> Loading corpus…</p>
          ) : entries.length === 0 ? (
            <p className="px-5 pb-5 text-sm text-muted-foreground">No entries match.</p>
          ) : (
            <div className="divide-y border-t">
              {entries.map((e) => (
                <button key={e.id} onClick={() => open(e.id)} className="flex w-full items-center gap-3 px-5 py-2.5 text-left text-sm hover:bg-secondary/40">
                  <Badge variant={e.kind === "completion" ? "default" : "secondary"} className="w-24 shrink-0 justify-center">{e.kind}</Badge>
                  <span className="min-w-0 flex-1 truncate text-muted-foreground">{e.preview || e.cacheKey}</span>
                  <span className="shrink-0 font-mono text-[11px] text-muted-foreground/70">{(e.createdAt || "").slice(0, 10)}</span>
                  <span className="w-16 shrink-0 text-right font-mono text-[11px] text-muted-foreground/70">{(e.size / 1024).toFixed(1)} kB</span>
                </button>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      <Dialog
        open={!!detail || loadingDetail}
        onClose={() => setDetail(null)}
        title={detail ? `${detail.kind} · ${detail.model}` : "Loading…"}
        description={detail ? `Generated ${detail.createdAt} · prompt v${detail.promptVersion} · key ${detail.cacheKey.slice(0, 18)}…` : undefined}
      >
        {loadingDetail && <p className="flex items-center gap-2 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" /> Loading…</p>}
        {detail && (
          <div className="max-h-[60vh] space-y-3 overflow-auto">
            <div>
              <div className="mb-1 text-xs font-medium text-muted-foreground">Prompt (stored preview)</div>
              <pre className="max-h-48 overflow-auto rounded-md border bg-muted/40 p-3 text-xs leading-relaxed whitespace-pre-wrap break-words">{detail.inputPreview || "(not stored — matching uses the hash key)"}</pre>
            </div>
            <div>
              <div className="mb-1 text-xs font-medium text-muted-foreground">Stored {detail.kind === "embedding" ? "vector" : "completion"} (replayed verbatim on a cache hit)</div>
              <pre className="max-h-72 overflow-auto rounded-md border bg-muted/40 p-3 text-xs leading-relaxed whitespace-pre-wrap break-words">{detail.kind === "embedding" ? detail.output.slice(0, 2000) + (detail.output.length > 2000 ? ` … (${detail.output.length} chars)` : "") : detail.output}</pre>
            </div>
          </div>
        )}
      </Dialog>
    </div>
  );
}
