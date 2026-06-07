// CC-01..CC-12 reusable clinical component library, shared by the Studio (run
// preview) and Clinical (chart / worklists) SPAs.
export { PatientBanner } from "@shared/components/clinical/PatientBanner";
export { ContextSummaryCard } from "@shared/components/clinical/ContextSummaryCard";
export { EvidencePanel } from "@shared/components/clinical/EvidencePanel";
export { Timeline } from "@shared/components/clinical/Timeline";
export type { TimelineEvent } from "@shared/components/clinical/Timeline";
export { StatusRiskBadgeBar, toneForStatus } from "@shared/components/clinical/StatusRiskBadgeBar";
export type { StatusBadge } from "@shared/components/clinical/StatusRiskBadgeBar";
export { ActionBar } from "@shared/components/clinical/ActionBar";
export { AIGeneratedTextPanel } from "@shared/components/clinical/AIGeneratedTextPanel";
export type { ReviewState } from "@shared/components/clinical/AIGeneratedTextPanel";
export { AISafetyChecklist } from "@shared/components/clinical/AISafetyChecklist";
export { SourceDataCompletenessPanel } from "@shared/components/clinical/SourceDataCompletenessPanel";
export type { CompletenessItem } from "@shared/components/clinical/SourceDataCompletenessPanel";
export { ReviewAuditPanel } from "@shared/components/clinical/ReviewAuditPanel";
export { Worklist } from "@shared/components/clinical/Worklist";
export type { WorklistRow } from "@shared/components/clinical/Worklist";
export { PatientCommunicationComposer } from "@shared/components/clinical/PatientCommunicationComposer";
export { AdvisoryCard } from "@shared/components/clinical/AdvisoryCard";
export type { AdvisoryCardProps } from "@shared/components/clinical/AdvisoryCard";
export { DraftActionCard } from "@shared/components/clinical/DraftActionCard";
// AgentResultView is the developer Studio's technical renderer (source badges,
// evidence, raw JSON, trace). The clinician app uses its own plain-language
// renderer (clinical/src/components/ClinicalResult.tsx) instead.
export { AgentResultView } from "@shared/components/clinical/AgentResultView";
