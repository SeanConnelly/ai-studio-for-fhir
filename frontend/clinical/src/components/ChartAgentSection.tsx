// A generic in-chart decision-support section: runs one agent for the patient
// and renders the clinician view (with a signable draft when the agent proposes
// one). Only ever shows genuinely AI-generated output — used for the chart
// sections that don't need bespoke chrome (medication safety, lab explainer).
import { useEffect, useState } from "react";
import { Loader2 } from "lucide-react";
import { api } from "@shared/api/client";
import type { AgentResponse } from "@shared/api/types";
import { advisorySeverity, isRealAi } from "@shared/lib/clinical";
import { scenarioInputs } from "@/agents";
import { ClinicalResult } from "@/components/ClinicalResult";

export function ChartAgentSection({ patientId, agent, title }: { patientId: string; agent: string; title: string }) {
  const [resp, setResp] = useState<AgentResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [actionId, setActionId] = useState<string | null>(null);
  const [decided, setDecided] = useState<{ decision: string; reviewer?: string; committedRef?: string } | null>(null);

  useEffect(() => {
    setResp(null); setDecided(null); setActionId(null); setLoading(true);
    api.runAgent(agent, { patient: `Patient/${patientId}`, ...scenarioInputs(`Patient/${patientId}`, agent) })
      .then(async (r) => {
        setResp(r);
        if (r?.requestId && r?.proposedAction) {
          try {
            const inv = await api.invocation(r.requestId);
            setActionId(inv.proposedActions?.[0]?.id || null);
          } catch { /* draft stays read-only */ }
        }
      })
      .catch(() => setResp(null))
      .finally(() => setLoading(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [patientId, agent]);

  async function sign() {
    if (!resp?.requestId || !actionId) return;
    setBusy(true);
    try {
      const r = await api.approveAction(resp.requestId, actionId, { reviewer: "Demo Clinician" });
      setDecided({ decision: "approved", reviewer: "Demo Clinician", committedRef: r.committedResourceRef });
    } finally { setBusy(false); }
  }
  async function decline() {
    if (!resp?.requestId || !actionId) return;
    setBusy(true);
    try {
      await api.rejectAction(resp.requestId, actionId, { reviewer: "Demo Clinician" });
      setDecided({ decision: "rejected", reviewer: "Demo Clinician" });
    } finally { setBusy(false); }
  }

  if (loading) {
    return (
      <div className="flex items-center gap-2 rounded-lg border bg-card px-4 py-3 text-sm text-muted-foreground shadow-sm">
        <Loader2 className="h-4 w-4 animate-spin" /> Running {title.toLowerCase()}…
      </div>
    );
  }
  if (!resp || !isRealAi(resp)) {
    return (
      <div className="rounded-lg border bg-card px-4 py-3 text-sm text-muted-foreground shadow-sm">
        {title} isn't available for this patient.
      </div>
    );
  }

  return (
    <ClinicalResult
      resp={resp}
      title={title}
      severity={advisorySeverity(agent, resp)}
      actionBusy={busy}
      decided={decided}
      onSign={actionId ? sign : undefined}
      onDecline={actionId ? decline : undefined}
    />
  );
}
