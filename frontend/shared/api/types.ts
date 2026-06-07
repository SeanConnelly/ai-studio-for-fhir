export interface StatusResponse {
  status: string;
  product: string;
  version: string;
  iris: string;
  namespace: string;
  counts: Record<string, number>;
}

export interface TemplateSummary {
  slug: string;
  name: string;
  category: string;
  description: string;
  version: string;
  /** "template" (seeded) | "flow" (authored in the Studio / edited override) */
  source?: string;
}

/** A declared run-time input on an agent (drives the Run panel's controls). */
export interface InputField {
  key: string;
  type: "patient" | "fhir-reference" | "text" | "enum";
  label: string;
  required?: boolean;
  default?: string;
  placeholder?: string;
  resourceType?: string; // for fhir-reference
  dependsOn?: string; // for fhir-reference (usually "patient")
  options?: string[]; // for enum
}

export interface AgentDefinition {
  id: string;
  name: string;
  category: string;
  description: string;
  trigger: { type: string; resourceType: string | null; condition: string };
  inputs?: InputField[];
  evidence: {
    fhir: string[];
    sql: string[];
    vector: string[];
    /** reusable EvidenceSource component slugs (executed via the EvidenceEngine) */
    sources?: string[];
    /** how the vector query text is built: "" (description) | social-screening | patient-profile | abnormal-results */
    vectorQueryFrom?: string;
    vectorTopK?: number;
  };
  agent: { role: string; instruction: string; outputSchema: string };
  action: { type: string; resourceType: string | null; approvalRequired: boolean };
  testCase?: { patientId: string | null; context: Record<string, unknown> };
}

export interface AgentDetail {
  slug: string;
  name: string;
  category: string;
  description: string;
  version?: string;
  definition: AgentDefinition;
  /** 1 when this is one of the seeded built-in agents */
  isSystemTemplate?: number | boolean;
  /** true when a seeded agent has been edited (a flow override shadows it) */
  hasOverride?: boolean;
}

/** Result of testing a single builder step against a test patient. */
export interface StepTestResult {
  ok: number;
  kind: string;
  ms: number;
  summary?: string;
  error?: string;
  result?: any;
}

/** The exact prompt the AI step would send, assembled by the runtime's own code path. */
export interface PromptPreviewResult {
  ok: number;
  system?: string;
  user?: string;
  evidence?: Record<string, unknown>;
  ms: number;
  error?: string;
}

export interface PatientOption {
  ref: string;
  label: string;
  sex: string;
  birthDate: string;
}

export interface ResourceOption {
  ref: string;
  label: string;
}

export interface FlowSummary {
  slug: string;
  name: string;
  description: string;
  version: string;
  status: string;
  sourceTemplateSlug: string;
}

export interface MappingRow {
  portalConcept: string;
  portalDetail: string;
  healthConnectType: string;
  healthConnectComponent: string;
}

export interface MappingResponse {
  flow: string;
  orchestrator: string;
  mappings: MappingRow[];
}

export interface ArtifactMeta {
  name: string;
  type: string;
  contentType: string;
  createdAt: string;
}

export interface TraceStep {
  step: number;
  componentType: string;
  componentName: string;
  status: string;
  detail: string;
  durationMs: number;
  payload?: unknown;
}

export interface EvidenceItem {
  evidenceType: string;
  source: string;
  display: string;
  relevance: string;
}

export interface AgentResponse {
  requestId?: string;
  recipeId?: string;
  traceId?: string;
  /** the real Ens session id — deep-links to the Management Portal Visual Trace */
  sessionId?: number;
  error?: string;
  status: string;
  summary: string;
  findings?: string[];
  evidence?: EvidenceItem[];
  recommendations?: { priority: string; owner: string; text: string }[];
  missingData?: string[];
  proposedAction?: {
    actionType: string;
    resourceType: string;
    resource: Record<string, unknown>;
  };
  trace?: TraceStep[];
  // per-agent contract extras
  policyCriteriaMatched?: string[];
  missingEvidenceChecklist?: string[];
  draftJustification?: string;
  interpretedIntent?: string;
  resources?: string[]; // nl-to-fhir-query: FHIR resource types touched
  filters?: string[]; // nl-to-fhir-query: extracted human-readable constraints
  confidence?: number; // nl-to-fhir-query: 0-100 translation confidence
  clarification?: string; // nl-to-fhir-query: clarifying question for ambiguous asks
  generatedQuery?: string;
  generatedQueryType?: string;
  validationStatus?: string;
  resultPreview?: Record<string, unknown>[];
  queryExplanation?: string;
  limitations?: string[];
  // transparency: where the agent reasoning came from
  source?: string;
  // prior-auth justification / requested service
  requestedService?: string;
  // the exact completion transcript (diagnostics): base prompt, combined
  // request sent to the LLM, and the raw response that became this result
  aiTrace?: AITrace;
  matchCount?: number;
  // ---- per-agent structured result extras (LLM-authored, all 12 agents) ----
  sections?: { heading: string; items: string[] }[]; // smart-patient-summary
  interactions?: { severity: string; drugs: string[]; issue: string; recommendation: string }[]; // medication-safety
  gaps?: { measure: string; status: string; detail: string; recommendedAction?: string }[]; // gaps-in-care
  goals?: { goal: string; status: string; onTrack?: boolean; nextStep?: string; detail?: string }[]; // care-plan-navigator
  nextSteps?: { action: string; detail?: string }[]; // care-plan-navigator
  overdueTasks?: { task: string; detail?: string }[]; // care-plan-navigator
  suggestedTasks?: { task: string; rationale?: string; owner?: string }[]; // care-plan-navigator
  needs?: { domain: string; detail: string; evidence?: string; source?: string }[]; // sdoh-referral
  referrals?: {
    // social-prescribing shape (matched from the community resource directory)
    name?: string;
    bestMatch?: boolean;
    offers?: string;
    eligibility?: string;
    contact?: string;
    reason: string;
    // legacy shape (pre social-prescribing rebuild)
    resource?: string;
  }[]; // sdoh-referral
  matches?: {
    trial: string;
    nctId?: string;
    matchLevel?: string; // likely | maybe | unlikely
    confidence?: number; // 0-100
    criteriaMet?: string[];
    criteriaUnmet?: string[];
    flags?: string[]; // cautions, e.g. washout requirements
    rationale?: string;
    eligibility?: string; // legacy shape
  }[]; // trial-matcher
  followUpQuestions?: { question: string; why?: string }[]; // trial-matcher
  riskBand?: string; // readmission-risk
  riskScore?: number; // readmission-risk: 0-100
  thirtyDayEstimate?: string; // readmission-risk: e.g. "~30%"
  riskFactors?: { factor: string; level: string; detail: string }[]; // readmission-risk
  insights?: string; // readmission-risk narrative
  riskDrivers?: string[]; // readmission-risk
  acuity?: string; // conversational-triage
  redFlags?: string[]; // conversational-triage
  recommendedNextStep?: string; // conversational-triage
  // conversational-triage phase 1 (question design)
  greeting?: string;
  questions?: { id: string; text: string; options: string[] }[];
  safetyNote?: string;
  // conversational-triage phase 2 (handoff)
  urgency?: string; // red | yellow | green
  urgencyLabel?: string;
  keyFindings?: { finding: string; source?: string }[];
  mappedObservations?: string[];
  patientMessage?: string; // triage + lab-explainer (patient-facing)
  results?: { test: string; value: string; meaning: string }[]; // lab-explainer (legacy)
  whenToWorry?: string[]; // lab-explainer
  // lab-explainer (current shape)
  explained?: {
    test: string;
    value?: number | string;
    unit?: string;
    flag?: string; // high | low | normal
    normalRange?: string;
    rangeLow?: number;
    rangeHigh?: number;
    meaning: string;
    trend?: { direction: string; detail?: string } | null;
    series?: { date: string; value: number }[];
    whatYouCanDo?: string[];
  }[];
  overallSummary?: string;
  questionsToAsk?: string[];
  // results-followup tracker
  closedLoopSummary?: string;
  trackedResults?: { result: string; date?: string; finding: string; followUpStatus: string; followUp?: string; action?: string }[];
  patientOutreach?: string | null;
  clinicianNote?: string | null;
}

// ---- FHIR tools ----
export interface PatientSearchResult {
  ref: string;
  label: string;
  given?: string;
  family?: string;
  gender?: string;
  birthDate?: string;
  nhs?: string;
  mrn?: string;
}

// ---- Orders + Prior Authorisation ----
export interface OrderCatalogueItem {
  id: string;
  kind: string;
  display: string;
  requestedService: string;
  requiresPA: number;
}

export interface PaPacket {
  available?: number;
  source?: string;
  summary?: string;
  requestedService?: string;
  draftJustification?: string;
  policyCriteriaMatched?: string[];
  missingEvidenceChecklist?: string[];
}

export interface OrderRow {
  id: string;
  kind: string;
  display: string;
  status: string;
  date?: string;
  pa?: { claimId: string; status: string; disposition?: string };
}

export interface PlaceOrderResult {
  ok: number;
  orderId?: string;
  claimId?: string;
  display?: string;
  kind?: string;
  requestedService?: string;
  pa?: PaPacket;
  error?: string;
}

export interface SubmitPaResult {
  ok: number;
  claimId?: string;
  decision?: string;
  outcome?: string;
  disposition?: string;
  payer?: string;
  missingCount?: number;
  missing?: string[];
  error?: string;
}

export interface PaQueueRow {
  claimId: string;
  patientRef: string;
  patientId: string;
  patientName: string;
  item: string;
  status: string;
  disposition?: string;
}

// ---- Preventative-care rules (AI-authored cohort SQL) ----
export interface CareRule {
  slug: string;
  name: string;
  description: string;
  explanation?: string;
  source?: string;
  isSystem?: boolean;
  sql?: string;
}

export interface CareRulePatient {
  ref: string;
  id: string;
  name: string;
  detail?: string;
}

export interface CareRuleCreateResult {
  ok: number;
  slug?: string;
  name?: string;
  description?: string;
  sql?: string;
  explanation?: string;
  source?: string;
  sample?: { ok: number; count: number; patients: CareRulePatient[]; error?: string };
  error?: string;
}

export interface CareRuleRunResult {
  ok: number;
  slug?: string;
  name?: string;
  description?: string;
  count: number;
  patients: CareRulePatient[];
  error?: string;
}

export interface WorklistEntriesResult {
  ok: number;
  slug: string;
  name: string;
  description?: string;
  count: number;
  entries: CareRulePatient[];
  added?: number;
}

// ---- in-chart preventative care ----
export interface PreventativeItem {
  area: string;
  title: string;
  detail: string;
  severity: string;
}

export interface PreventativeResult {
  patientRef: string;
  count: number;
  overdue: PreventativeItem[];
}

export interface LetterResult {
  ok: number;
  area: string;
  letter: string;
  source?: string;
}

export interface EverythingBundle {
  patientRef: string;
  patient?: string;
  gender?: string;
  birthDate?: string;
  mrn?: string;
  nhsNo?: string;
  hospitalNo?: string;
  address?: string;
  gp?: string;
  alerts?: string[];
  sections: Record<string, string[]>;
}

export interface TerminologyConcept {
  system: string;
  code: string;
  display: string;
}

export interface WorklistResponse {
  worklist: string;
  code?: string;
  patients: { ref: string; label?: string; gender?: string; birthDate?: string }[];
  count: number;
}

// ---- approval / audit ----
export interface ProposedActionView {
  id?: string;
  actionType: string;
  resourceType: string;
  status: string;
  requiresApproval: boolean | number;
  resource: Record<string, unknown>;
}

export interface AuditEntry {
  actionId: string;
  decision: string;
  reviewer: string;
  committedResourceRef: string;
  note: string;
  timestamp: string;
}

// ---- reusable authoring components (Studio managers) ----
export interface PromptComponent {
  slug: string;
  name?: string;
  role?: string;
  systemTemplate?: string;
  userTemplate?: string;
  outputContractRef?: string;
  description?: string;
  version?: string;
  isSystem?: boolean;
  createdAt?: string;
  updatedAt?: string;
}

export interface EvidenceSourceComponent {
  slug: string;
  name?: string;
  kind?: string;
  spec?: string;
  description?: string;
  isSystem?: boolean;
}

export interface ActionTemplateComponent {
  slug: string;
  name?: string;
  resourceType?: string;
  templateJson?: string;
  approvalRequired?: boolean;
  description?: string;
  isSystem?: boolean;
}

export interface OutputSchemaComponent {
  slug: string;
  name?: string;
  schemaJson?: string;
  rendererKey?: string;
  description?: string;
  isSystem?: boolean;
}

/** The agent's LLM completion transcript — surfaced under the hood. */
export interface AITrace {
  basePrompt?: string;
  completionRequest?: string;
  rawResponse?: string;
  source?: string;
  model?: string;
}
