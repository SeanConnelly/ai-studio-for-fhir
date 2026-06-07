// PA Queue - the prior-authorisation inbox. Every PA raised from a patient chart
// lands here with its live status (submitted / approved / action needed) for the
// utilisation-management team to work. Click a row to open the patient's chart.
import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { FileCheck2, Loader2, CheckCircle2, Clock, Send, FileEdit } from "lucide-react";
import { api } from "@shared/api/client";
import type { PaQueueRow } from "@shared/api/types";
import { Table, THead, TBody, TR, TH, TD } from "@shared/components/ui/table";

function StatusCell({ status }: { status: string }) {
  const s = (status || "").toLowerCase();
  const cfg =
    s === "approved" ? { cls: "bg-emerald-100 text-emerald-800", icon: <CheckCircle2 className="h-3.5 w-3.5" />, label: "Approved" }
    : s === "pended" ? { cls: "bg-amber-100 text-amber-800", icon: <Clock className="h-3.5 w-3.5" />, label: "Action needed" }
    : s === "submitted" ? { cls: "bg-sky-100 text-sky-800", icon: <Send className="h-3.5 w-3.5" />, label: "Submitted" }
    : { cls: "bg-slate-100 text-slate-700", icon: <FileEdit className="h-3.5 w-3.5" />, label: "Draft" };
  return <span className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-medium ${cfg.cls}`}>{cfg.icon}{cfg.label}</span>;
}

export function PriorAuth() {
  const navigate = useNavigate();
  const [rows, setRows] = useState<PaQueueRow[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.paQueue().then((r) => setRows(r.queue || [])).finally(() => setLoading(false));
  }, []);

  const order = { pended: 0, submitted: 1, draft: 2, approved: 3 } as Record<string, number>;
  const sorted = [...rows].sort((a, b) => (order[a.status] ?? 9) - (order[b.status] ?? 9));

  return (
    <div className="space-y-5">
      <div>
        <h1 className="flex items-center gap-2 text-xl font-semibold"><FileCheck2 className="h-5 w-5 text-nhs-600" /> Prior authorisation queue</h1>
        <p className="text-sm text-muted-foreground">Prior authorisations raised from patient charts, with their current status. Raise new ones from a patient's Orders section.</p>
      </div>

      {loading ? (
        <p className="flex items-center gap-2 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" /> Loading queue…</p>
      ) : sorted.length === 0 ? (
        <p className="text-sm text-muted-foreground">The queue is empty. Open a patient chart, go to Orders, and raise a prior-authorisation order.</p>
      ) : (
        <Table>
          <THead><TR><TH>Patient</TH><TH>Requested item</TH><TH>Status</TH><TH>Decision</TH></TR></THead>
          <TBody>
            {sorted.map((r) => (
              <TR key={r.claimId} className="cursor-pointer" onClick={() => navigate(`/patient/${r.patientId}`)}>
                <TD className="font-medium">{r.patientName}</TD>
                <TD className="text-muted-foreground">{r.item}</TD>
                <TD><StatusCell status={r.status} /></TD>
                <TD className="text-xs text-muted-foreground">{r.disposition || "-"}</TD>
              </TR>
            ))}
          </TBody>
        </Table>
      )}
    </div>
  );
}
