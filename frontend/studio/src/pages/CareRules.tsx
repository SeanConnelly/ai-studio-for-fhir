// Care Rules authoring — the AI step of the preventative-care workflow. An admin
// describes a cohort in plain English; the NL->FHIR agent writes the read-only
// SQL over the real FHIR projections. Saved rules are then run from the clinical
// Preventative Care worklist.
import { useEffect, useState } from "react";
import { Sparkles, Loader2, Trash2, ShieldCheck, Play } from "lucide-react";
import { api } from "@shared/api/client";
import type { CareRule, CareRuleCreateResult } from "@shared/api/types";
import { Input } from "@shared/components/ui/input";
import { Button } from "@shared/components/ui/button";
import { Label } from "@shared/components/ui/label";
import { CodeBlock } from "@shared/components/ui/code-block";

const EXAMPLES = [
  "Patients with hypertension whose most recent systolic blood pressure is 140 or higher",
  "Patients with chronic kidney disease and an eGFR below 45",
  "Patients with type 2 diabetes whose most recent HbA1c is 7.5% or higher",
];

export function CareRules() {
  const [rules, setRules] = useState<CareRule[]>([]);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [generating, setGenerating] = useState(false);
  const [result, setResult] = useState<CareRuleCreateResult | null>(null);

  const load = () => api.careRules().then((r) => setRules(r.rules || []));
  useEffect(() => { load(); }, []);

  async function generate() {
    if (!description.trim()) return;
    setGenerating(true);
    setResult(null);
    try {
      const r = await api.createCareRule(name || description.slice(0, 60), description);
      setResult(r);
      if (r.ok) { setName(""); setDescription(""); await load(); }
    } finally {
      setGenerating(false);
    }
  }

  async function remove(slug: string) {
    await api.deleteCareRule(slug);
    await load();
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="flex items-center gap-2 text-xl font-semibold"><ShieldCheck className="h-5 w-5 text-primary" /> Care rules</h1>
        <p className="text-sm text-muted-foreground">
          Describe a preventative-care cohort in plain English. The AI writes a read-only SQL query over the FHIR repository.
          Saved rules appear on the clinical <span className="font-medium">Preventative care</span> worklist, where they are run on demand.
        </p>
      </div>

      {/* Authoring */}
      <div className="space-y-3 rounded-lg border bg-card p-4">
        <div className="space-y-1">
          <Label>Rule name</Label>
          <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Uncontrolled hypertension" className="max-w-md" />
        </div>
        <div className="space-y-1">
          <Label>Describe the cohort</Label>
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="e.g. Patients with hypertension whose most recent systolic blood pressure is 140 or higher"
            rows={2}
            className="w-full rounded-md border border-input bg-card px-3 py-2 text-sm"
          />
          <div className="flex flex-wrap gap-1.5 pt-1">
            {EXAMPLES.map((ex) => (
              <button key={ex} onClick={() => setDescription(ex)} className="rounded-full border px-2 py-0.5 text-[11px] text-muted-foreground hover:border-primary hover:text-foreground">
                {ex.length > 52 ? ex.slice(0, 52) + "…" : ex}
              </button>
            ))}
          </div>
        </div>
        <Button onClick={generate} disabled={generating || !description.trim()}>
          {generating ? <Loader2 className="mr-1 h-4 w-4 animate-spin" /> : <Sparkles className="mr-1 h-4 w-4" />}
          {generating ? "Generating SQL…" : "Generate with AI"}
        </Button>

        {result && (
          result.ok ? (
            <div className="space-y-2 rounded-md border border-emerald-200 bg-emerald-50/40 p-3">
              <div className="flex items-center gap-2 text-sm font-medium">
                <Sparkles className="h-4 w-4 text-primary" /> AI generated this query
                <span className="rounded-full bg-secondary px-2 py-0.5 text-[10px] uppercase tracking-wide text-muted-foreground">{result.source}</span>
              </div>
              {result.explanation && <p className="text-sm text-muted-foreground">{result.explanation}</p>}
              <CodeBlock language="sql" content={result.sql || ""} />
              <p className="text-xs text-muted-foreground">
                Validated read-only and saved. Sample matches now: <span className="font-medium text-foreground">{result.sample?.count ?? 0}</span> patients.
              </p>
            </div>
          ) : (
            <p className="text-sm text-rose-600">{result.error}</p>
          )
        )}
      </div>

      {/* Existing rules */}
      <div className="space-y-2">
        <div className="text-sm font-semibold">Saved rules ({rules.length})</div>
        {rules.length === 0 ? (
          <p className="text-sm text-muted-foreground">No rules yet. Create one above.</p>
        ) : (
          <div className="space-y-2">
            {rules.map((r) => (
              <div key={r.slug} className="rounded-lg border bg-card p-3">
                <div className="flex items-center gap-2">
                  <span className="font-medium">{r.name}</span>
                  {r.isSystem && <span className="rounded-full bg-secondary px-2 py-0.5 text-[10px] uppercase tracking-wide text-muted-foreground">example</span>}
                  <span className="ml-auto inline-flex items-center gap-1 text-xs text-muted-foreground"><Play className="h-3 w-3" /> run on the worklist</span>
                  {!r.isSystem && (
                    <button onClick={() => remove(r.slug)} className="text-muted-foreground hover:text-rose-600" title="Delete rule"><Trash2 className="h-4 w-4" /></button>
                  )}
                </div>
                <p className="mt-0.5 text-sm text-muted-foreground">{r.description}</p>
                {r.sql && <CodeBlock language="sql" content={r.sql} />}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
