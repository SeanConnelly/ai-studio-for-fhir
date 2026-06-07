// CC-03 EvidencePanel — the real evidence that grounded an AI result, so a
// clinician can trace every statement back to a FHIR resource / query / retrieved
// knowledge chunk. Never fabricated: this is exactly what RAG retrieved.
import { Database, FileText, Search } from "lucide-react";
import type { EvidenceItem } from "@shared/api/types";

function icon(type: string) {
  if (type === "KNOWLEDGE_CHUNK") return <Search className="h-3.5 w-3.5 text-violet-500" />;
  if (type === "FHIR_QUERY") return <Database className="h-3.5 w-3.5 text-sky-500" />;
  return <FileText className="h-3.5 w-3.5 text-emerald-600" />;
}

export function EvidencePanel({ evidence }: { evidence?: EvidenceItem[] }) {
  if (!evidence || evidence.length === 0) {
    return <p className="text-sm text-muted-foreground">No evidence recorded for this run.</p>;
  }
  return (
    <ul className="space-y-2">
      {evidence.map((e, i) => (
        <li key={i} className="flex items-start gap-2 rounded-md border bg-card px-3 py-2 text-sm">
          <span className="mt-0.5">{icon(e.evidenceType)}</span>
          <div className="min-w-0">
            <div className="font-medium text-foreground">{e.display}</div>
            <div className="text-xs text-muted-foreground">
              {e.source}
              {e.relevance ? ` — ${e.relevance}` : ""}
            </div>
          </div>
        </li>
      ))}
    </ul>
  );
}
