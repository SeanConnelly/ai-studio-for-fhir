// "Results, explained" — clinician preview of the patient-friendly lab
// explanation. The doctor reviews exactly what the patient would see (colour
// bars, trends, questions) and approves it for the patient portal.
import { useEffect, useState } from "react";
import { Loader2, Sparkles, Send, CheckCircle2, FlaskConical } from "lucide-react";
import { api } from "@shared/api/client";
import type { AgentResponse } from "@shared/api/types";
import { isRealAi } from "@shared/lib/clinical";
import { scenarioInputs } from "@/agents";
import { LabResultsExplained } from "@/components/LabResultsExplained";

export function LabExplainerSection({ patientId }: { patientId: string }) {
  const [resp, setResp] = useState<AgentResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [sentRef, setSentRef] = useState<string | null>(null);
  const [sending, setSending] = useState(false);

  async function approve() {
    setSending(true);
    try {
      const r = await api.sendCommunication(patientId, {
        category: "portal-share",
        text: "Patient-friendly results explanation approved by clinician and shared to the patient portal.",
      });
      setSentRef(r.ref);
    } finally { setSending(false); }
  }

  useEffect(() => {
    setResp(null); setSentRef(null); setLoading(true);
    api.runAgent("lab-explainer", { patient: `Patient/${patientId}`, ...scenarioInputs(`Patient/${patientId}`, "lab-explainer") })
      .then(setResp).catch(() => setResp(null)).finally(() => setLoading(false));
  }, [patientId]);

  if (loading) {
    return (
      <div className="flex items-center gap-2 rounded-lg border bg-card px-4 py-3 text-sm text-muted-foreground shadow-sm">
        <Loader2 className="h-4 w-4 animate-spin" /> Writing the patient-friendly explanation…
      </div>
    );
  }
  if (!resp || !isRealAi(resp)) {
    return (
      <div className="rounded-lg border bg-card px-4 py-3 text-sm text-muted-foreground shadow-sm">
        A patient-friendly explanation isn't available for this patient.
      </div>
    );
  }

  return (
    <div className="rounded-lg border bg-card shadow-sm">
      <div className="flex flex-wrap items-center gap-2 border-b px-4 py-2.5 text-sm font-semibold">
        <FlaskConical className="h-4 w-4 text-nhs-600" /> Results, explained
        <span className="ml-auto inline-flex items-center gap-1 rounded-full bg-nhs-600 px-2.5 py-0.5 text-[11px] font-bold uppercase tracking-wide text-white"><Sparkles className="h-3 w-3" /> AI generated</span>
        <span className="ml-auto text-xs font-normal text-muted-foreground">Preview of what the patient will see</span>
      </div>
      <div className="space-y-4 px-4 py-4">
        <LabResultsExplained resp={resp} />
        <div className="flex flex-wrap items-center gap-3 border-t pt-3">
          {sentRef ? (
            <span className="inline-flex items-center gap-1.5 text-sm font-medium text-emerald-700"><CheckCircle2 className="h-4 w-4" /> Approved — a record of the share was saved to the chart ({sentRef})</span>
          ) : (
            <button onClick={approve} disabled={sending} className="inline-flex items-center gap-1.5 rounded-md bg-nhs-600 px-3 py-2 text-sm font-medium text-white hover:bg-nhs-700 disabled:opacity-60">
              {sending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />} Approve &amp; share to patient portal
            </button>
          )}
          <p className="text-[11px] text-muted-foreground">Grounded in trusted patient-education content — review before approving; the share is recorded as a real FHIR Communication.</p>
        </div>
      </div>
    </div>
  );
}
