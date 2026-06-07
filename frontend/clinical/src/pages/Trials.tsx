// Trials — the research coordinator's view of the Clinical Trial Matcher.
// Pick a patient and the agent grades them against the trial registry
// (retrieved semantically from their clinical profile): likely / maybe /
// unlikely with cited criteria, washout flags, follow-up questions you can
// answer to re-grade, and a one-click draft referral to the coordinator.
import { useEffect, useState } from "react";
import { Microscope } from "lucide-react";
import { api } from "@shared/api/client";
import { TRIAL_PATIENTS } from "@/agents";
import { TrialsSection } from "@/components/TrialsSection";

export function Trials() {
  const ids = TRIAL_PATIENTS.map((s) => s.patient.split("/")[1]);
  const [names, setNames] = useState<Record<string, string>>({});
  const [active, setActive] = useState(ids[0]);

  useEffect(() => {
    ids.forEach((id) => {
      api.everything(`Patient/${id}`).then((b) => setNames((n) => ({ ...n, [id]: b.patient || id }))).catch(() => {});
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="space-y-5">
      <div>
        <h1 className="flex items-center gap-2 text-xl font-semibold"><Microscope className="h-5 w-5 text-nhs-600" /> Clinical trials</h1>
        <p className="text-sm text-muted-foreground">
          Match a patient against the recruiting trial registry. The agent grades every candidate trial with its
          reasoning, asks for anything missing, and drafts the referral for your sign-off.
        </p>
      </div>

      <div className="flex items-center gap-2">
        <label className="text-sm text-muted-foreground">Patient:</label>
        <select
          value={active}
          onChange={(e) => setActive(e.target.value)}
          className="h-9 rounded-md border bg-background px-3 text-sm"
        >
          {ids.map((id) => <option key={id} value={id}>{names[id] || id}</option>)}
        </select>
      </div>

      <TrialsSection patientId={active} />
    </div>
  );
}
