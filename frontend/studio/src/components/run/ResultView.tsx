// The developer Studio's result view — a technical preview for agent authors:
// source/model badges, the raw evidence list, the draft FHIR resource as JSON,
// and the run trace. The clinician app deliberately does NOT reuse this; it has
// its own plain-language renderer (clinical/src/components/ClinicalResult.tsx)
// that hides backend vocabulary. (Reverses the earlier "render identically"
// decision — a developer and a clinician need different views of the same run.)
export { AgentResultView as ResultView } from "@shared/components/clinical/AgentResultView";
