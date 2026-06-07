// CC-12 PatientCommunicationComposer — for patient-facing AI output (lab
// explainer, triage next-step). Shows the AI-drafted message in an editable box
// with a review-before-send control; the message is never sent automatically.
import * as React from "react";
import { Send } from "lucide-react";
import { Button } from "@shared/components/ui/button";

export interface PatientCommunicationComposerProps {
  draft: string;
  safetyNet?: string;
  onSend?: (text: string) => void;
  busy?: boolean;
}

export function PatientCommunicationComposer({ draft, safetyNet, onSend, busy }: PatientCommunicationComposerProps) {
  const [text, setText] = React.useState(draft);
  React.useEffect(() => setText(draft), [draft]);
  return (
    <div className="space-y-2">
      <textarea
        className="min-h-[120px] w-full resize-y rounded-md border bg-card p-3 text-sm text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        value={text}
        onChange={(e) => setText(e.target.value)}
      />
      {safetyNet && <p className="text-xs text-amber-600">Safety-net guidance: {safetyNet}</p>}
      <div className="flex items-center gap-2">
        <span className="mr-auto text-xs text-muted-foreground">Review and edit before sending — nothing is sent automatically.</span>
        {onSend && (
          <Button size="sm" disabled={busy} onClick={() => onSend(text)}>
            <Send className="mr-1 h-3.5 w-3.5" /> {busy ? "Sending…" : "Send to patient"}
          </Button>
        )}
      </div>
    </div>
  );
}
