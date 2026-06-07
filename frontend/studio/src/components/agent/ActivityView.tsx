// Activity — this agent's run history, straight from the persisted
// AgentInvocation records. Click a run to see the full result it produced.
import { useEffect, useState } from "react";
import { History, Loader2, ChevronRight, ArrowLeft } from "lucide-react";
import { Card, CardContent } from "@shared/components/ui/card";
import { Badge } from "@shared/components/ui/badge";
import { Button } from "@shared/components/ui/button";
import { api } from "@shared/api/client";
import type { AgentResponse } from "@shared/api/types";
import { AgentResultView } from "@shared/components/clinical/AgentResultView";
import { UnderTheHood } from "@/components/run/UnderTheHood";

interface Row { requestId: string; recipeId: string; status: string; summary: string }

export function ActivityView({ slug }: { slug: string }) {
  const [rows, setRows] = useState<Row[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [open, setOpen] = useState<string | null>(null);
  const [detail, setDetail] = useState<AgentResponse | null>(null);
  const [loadingDetail, setLoadingDetail] = useState(false);

  useEffect(() => {
    api.invocations()
      .then((r) => setRows((r.invocations || []).filter((i) => i.recipeId === slug).reverse()))
      .catch((e) => setError((e as Error).message));
  }, [slug]);

  async function openRun(requestId: string) {
    setOpen(requestId);
    setDetail(null);
    setLoadingDetail(true);
    try {
      const r = await api.invocation(requestId);
      setDetail(r.response);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoadingDetail(false);
    }
  }

  if (error) return <div className="rounded-md bg-destructive/10 px-4 py-2 text-sm text-destructive">{error}</div>;
  if (!rows) return <p className="flex items-center gap-2 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" /> Loading run history…</p>;

  if (open) {
    return (
      <div className="space-y-4">
        <Button variant="outline" size="sm" onClick={() => { setOpen(null); setDetail(null); }}>
          <ArrowLeft className="mr-1 h-4 w-4" />All runs
        </Button>
        {loadingDetail && <p className="flex items-center gap-2 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" /> Loading {open}…</p>}
        {detail && (
          <div>
            <p className="mb-3 text-xs text-muted-foreground">Run {open} — the persisted result exactly as it was produced.</p>
            <AgentResultView resp={detail} />
            <UnderTheHood resp={detail} />
          </div>
        )}
      </div>
    );
  }

  return (
    <Card>
      <CardContent className="p-0">
        {rows.length === 0 ? (
          <p className="flex items-center gap-2 px-4 py-6 text-sm text-muted-foreground"><History className="h-4 w-4" /> No runs yet — use the Run tab and they'll appear here.</p>
        ) : (
          <div className="divide-y">
            {rows.map((r) => (
              <button key={r.requestId} onClick={() => openRun(r.requestId)} className="flex w-full items-center gap-3 px-4 py-2.5 text-left text-sm hover:bg-secondary/40">
                <span className="w-24 shrink-0 font-mono text-xs text-muted-foreground">{r.requestId}</span>
                <Badge variant={r.status === "completed" ? "success" : "warning"}>{r.status?.replace(/_/g, " ")}</Badge>
                <span className="min-w-0 flex-1 truncate text-muted-foreground">{r.summary}</span>
                <ChevronRight className="h-4 w-4 shrink-0 text-muted-foreground" />
              </button>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
