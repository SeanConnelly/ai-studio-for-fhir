// Social care — the social-needs screening (real chart data, the patient's own
// words) plus the AI Social Prescribing matcher: identified needs grounded in
// evidence, local services matched by meaning from the community resource
// directory, a signable draft referral, and a warm draft message to the patient.
// Data and AI live in separate cards (the AI card is clearly labelled).
import { useEffect, useState } from "react";
import { HeartHandshake, Loader2 } from "lucide-react";
import { api } from "@shared/api/client";
import type { AgentResponse } from "@shared/api/types";
import { advisorySeverity, isRealAi } from "@shared/lib/clinical";
import { hasScenario, scenarioInputs } from "@/agents";
import { ClinicalResult } from "@/components/ClinicalResult";

interface QA {
  question: string;
  answer: string;
  /** long-form patient-voice answers indicate a reported need */
  reported: boolean;
}

/** Parse the screening display string: "Social needs screening (date) | Q -> A | Q -> A…" */
function parseScreening(display: string): { date: string; items: QA[] } {
  const parts = display.split(" | ");
  const m = parts[0]?.match(/\(([\d-]+)\)/);
  const items: QA[] = [];
  for (const p of parts.slice(1)) {
    const [q, a] = p.split(" -> ");
    if (!q || !a) continue;
    items.push({ question: q.trim(), answer: a.trim(), reported: a.trim().length >= 30 });
  }
  return { date: m?.[1] || "", items };
}

export function SocialCareSection({ patientId, screening }: { patientId: string; screening: string[] }) {
  const [resp, setResp] = useState<AgentResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [actionId, setActionId] = useState<string | null>(null);
  const [decided, setDecided] = useState<{ decision: string; reviewer?: string; committedRef?: string } | null>(null);

  const cacheBacked = hasScenario(patientId, "sdoh-referral");

  useEffect(() => {
    setResp(null); setDecided(null); setActionId(null);
    if (!cacheBacked) return;
    setLoading(true);
    api.runAgent("sdoh-referral", { patient: `Patient/${patientId}`, ...scenarioInputs(`Patient/${patientId}`, "sdoh-referral") })
      .then(async (r) => {
        setResp(r);
        // the draft referral's action id (needed to sign/decline)
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
  }, [patientId]);

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

  const screen = screening.length ? parseScreening(screening[0]) : null;

  return (
    <div className="space-y-4">
      {/* Real chart data: the screening, in the patient's own words */}
      <div className="rounded-lg border bg-card shadow-sm">
        <div className="flex items-center gap-2 border-b px-4 py-2.5 text-sm font-semibold text-foreground">
          <HeartHandshake className="h-4 w-4 text-nhs-600" />
          Social needs screening
          {screen?.date && <span className="ml-auto text-xs font-normal text-muted-foreground">completed {screen.date}</span>}
        </div>
        <div className="px-4 py-3">
          {screen && screen.items.length ? (
            <div className="space-y-2">
              {screen.items.map((qa, i) => (
                <div key={i} className={"rounded-md px-3 py-2 text-sm " + (qa.reported ? "border border-amber-200 bg-amber-50/50" : "")}>
                  <div className="text-muted-foreground">{qa.question}</div>
                  <div className={qa.reported ? "mt-0.5 font-medium" : "mt-0.5"}>&ldquo;{qa.answer}&rdquo;</div>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-sm text-muted-foreground">No social-needs screening recorded for this patient.</p>
          )}
        </div>
      </div>

      {/* AI: the social prescribing matcher (only ever shown when genuinely AI-generated) */}
      {loading && (
        <div className="flex items-center gap-2 rounded-lg border bg-card px-4 py-3 text-sm text-muted-foreground shadow-sm">
          <Loader2 className="h-4 w-4 animate-spin" /> Matching local support services…
        </div>
      )}
      {resp && isRealAi(resp) && (
        <ClinicalResult
          resp={resp}
          title="Social prescribing"
          severity={advisorySeverity("sdoh-referral", resp)}
          actionBusy={busy}
          decided={decided}
          onSign={actionId ? sign : undefined}
          onDecline={actionId ? decline : undefined}
        />
      )}
    </div>
  );
}
