import type {
  AgentDetail,
  AgentResponse,
  ArtifactMeta,
  AuditEntry,
  CareRule,
  CareRuleCreateResult,
  CareRuleRunResult,
  EverythingBundle,
  LetterResult,
  PreventativeResult,
  WorklistEntriesResult,
  FlowSummary,
  MappingResponse,
  OrderCatalogueItem,
  OrderRow,
  PatientOption,
  PatientSearchResult,
  PaQueueRow,
  PlaceOrderResult,
  SubmitPaResult,
  ProposedActionView,
  ResourceOption,
  StatusResponse,
  TemplateSummary,
  TerminologyConcept,
  TraceStep,
  WorklistResponse,
} from "./types";

/** The reusable-component entity types managed by the Studio. */
export type ComponentEntity = "prompts" | "evidence-sources" | "actions" | "output-schemas";

const BASE = "/fhir-agent-studio/api";

async function req<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    headers: { Accept: "application/json", ...(init?.body ? { "Content-Type": "application/json" } : {}) },
    ...init,
  });
  if (!res.ok) {
    let msg = `HTTP ${res.status}`;
    try {
      const j = await res.json();
      if (j?.error) msg = j.error;
    } catch {
      /* ignore */
    }
    throw new Error(msg);
  }
  return res.json() as Promise<T>;
}

async function text(path: string): Promise<string> {
  const res = await fetch(`${BASE}${path}`);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.text();
}

export const api = {
  status: () => req<StatusResponse>("/status"),
  // Agents (the unified user concept). Built-in agents are seeded "templates".
  agents: () => req<{ templates: TemplateSummary[]; count: number }>("/templates"),
  agent: (slug: string) => req<AgentDetail>(`/templates/${slug}`),
  // Run an agent with the studio's input values (real production run).
  // skipCache forces the run past the bundled response corpus: live with a key,
  // honestly-labelled deterministic without one. Never writes to the cache.
  runAgent: (slug: string, inputs: Record<string, unknown>, skipCache = false) =>
    req<AgentResponse>(`/flows/${slug}/run`, {
      method: "POST",
      body: JSON.stringify(skipCache ? { inputs, skipCache: 1 } : { inputs }),
    }),
  // Trigger-driven input pickers, backed by the real FHIR repository.
  optionsPatients: () => req<{ patients: PatientOption[]; count: number }>("/options/patients"),
  optionsResources: (type: string, patient: string) =>
    req<{ resources: ResourceOption[]; count: number }>(
      `/options/resources?type=${encodeURIComponent(type)}&patient=${encodeURIComponent(patient)}`
    ),
  templates: () => req<{ templates: TemplateSummary[]; count: number }>("/templates"),
  template: (slug: string) => req<{ slug: string; name: string; category: string; description: string; definition: any }>(`/templates/${slug}`),
  importTemplate: (def: unknown) => req<{ slug: string; created: number }>("/templates/import", { method: "POST", body: JSON.stringify(def) }),
  adminSeed: () => req<{ status: string }>("/admin/seed", { method: "POST" }),
  flows: () => req<{ flows: FlowSummary[]; count: number }>("/flows"),
  createFlow: (templateSlug: string) => req<{ slug: string; created: number }>(`/flows/from-template/${templateSlug}`, { method: "POST" }),
  compile: (slug: string) => req<{ slug: string; status: string; artifacts: string[] }>(`/flows/${slug}/compile`, { method: "POST" }),
  artifacts: (slug: string) => req<{ artifacts: ArtifactMeta[]; count: number }>(`/flows/${slug}/artifacts`),
  artifact: (slug: string, name: string) => text(`/flows/${slug}/artifacts/${name}`),
  mapping: (slug: string) => req<MappingResponse>(`/flows/${slug}/healthconnect-mapping`),
  deploy: (slug: string) => req<{ slug: string; status: string }>(`/flows/${slug}/deploy`, { method: "POST" }),
  test: (slug: string) => req<AgentResponse>(`/flows/${slug}/test`, { method: "POST" }),
  invocations: () => req<{ invocations: { requestId: string; recipeId: string; status: string; summary: string }[] }>("/invocations"),
  invocation: (requestId: string) =>
    req<{ requestId: string; recipeId: string; status: string; summary: string; traceId: string; response: AgentResponse; proposedActions: ProposedActionView[] }>(
      `/invocations/${requestId}`
    ),
  trace: (traceId: string) => req<{ traceId: string; steps: TraceStep[] }>(`/traces/${traceId}`),

  // ---- reusable component CRUD (Prompt / EvidenceSource / ActionTemplate / OutputSchema) ----
  components: <T = any>(entity: ComponentEntity) => req<{ items: T[]; count: number }>(`/components/${entity}`),
  component: <T = any>(entity: ComponentEntity, slug: string) => req<T>(`/components/${entity}/${slug}`),
  createComponent: <T = any>(entity: ComponentEntity, body: unknown) =>
    req<T>(`/components/${entity}`, { method: "POST", body: JSON.stringify(body) }),
  updateComponent: <T = any>(entity: ComponentEntity, slug: string, body: unknown) =>
    req<T>(`/components/${entity}/${slug}`, { method: "PUT", body: JSON.stringify(body) }),
  deleteComponent: (entity: ComponentEntity, slug: string) =>
    req<{ slug: string; deleted: number }>(`/components/${entity}/${slug}`, { method: "DELETE" }),

  // ---- agent authoring (create / update / clone / delete a flow -> compile -> deploy) ----
  saveFlow: (def: unknown) =>
    req<{ slug: string; created: boolean; status: string; compiled: boolean; deployed: boolean; errors: string[] }>(
      "/flows",
      { method: "POST", body: JSON.stringify(def) }
    ),
  updateFlow: (slug: string, def: unknown) =>
    req<{ slug: string; created: boolean; status: string; compiled: boolean; deployed: boolean; errors: string[] }>(
      `/flows/${slug}`,
      { method: "PUT", body: JSON.stringify(def) }
    ),
  deleteFlow: (slug: string) => req<{ slug: string; deleted: number }>(`/flows/${slug}`, { method: "DELETE" }),
  cloneFlow: (slug: string, newSlug: string, newName: string) =>
    req<{ slug: string; created: boolean; status: string }>(`/flows/${slug}/clone`, {
      method: "POST",
      body: JSON.stringify({ newSlug, newName }),
    }),

  // ---- step-by-step builder: test ONE step / preview the assembled prompt ----
  // Both execute the same engine code the runtime's Business Operations call.
  stepTest: (body: Record<string, unknown>) =>
    req<import("./types").StepTestResult>("/authoring/step-test", { method: "POST", body: JSON.stringify(body) }),
  promptPreview: (definition: unknown, patientRef: string, context: Record<string, unknown> = {}) =>
    req<import("./types").PromptPreviewResult>("/authoring/prompt-preview", {
      method: "POST",
      body: JSON.stringify({ definition, patientRef, context }),
    }),

  // ---- orders + prior authorisation ----
  ordersCatalogue: () => req<{ catalogue: OrderCatalogueItem[] }>("/orders/catalogue"),
  patientOrders: (id: string) => req<{ patientRef: string; orders: OrderRow[] }>(`/patients/${id}/orders`),
  placeOrder: (id: string, itemId: string) =>
    req<PlaceOrderResult>(`/patients/${id}/orders`, { method: "POST", body: JSON.stringify({ itemId }) }),
  submitPa: (claimId: string) =>
    req<SubmitPaResult>(`/pa/${claimId}/submit`, { method: "POST", body: JSON.stringify({}) }),
  paQueue: () => req<{ queue: PaQueueRow[]; count: number }>("/pa-queue"),

  // ---- preventative-care rules (AI-authored cohort SQL) ----
  careRules: () => req<{ rules: CareRule[] }>("/care-rules"),
  createCareRule: (name: string, description: string) =>
    req<CareRuleCreateResult>("/care-rules", { method: "POST", body: JSON.stringify({ name, description }) }),
  runCareRule: (slug: string) =>
    req<CareRuleRunResult>(`/care-rules/${slug}/run`, { method: "POST", body: JSON.stringify({}) }),
  ruleWorklist: (slug: string) => req<WorklistEntriesResult>(`/care-rules/${slug}/worklist`),
  updateRuleWorklist: (slug: string) =>
    req<WorklistEntriesResult>(`/care-rules/${slug}/worklist/update`, { method: "POST", body: JSON.stringify({}) }),
  deleteCareRule: (slug: string) => req<{ ok: number }>(`/care-rules/${slug}`, { method: "DELETE" }),

  // ---- care plan navigator ----
  carePlanDemoPatients: () => req<{ patients: { id: string; name: string }[]; count: number }>("/care-plan/demo-patients"),
  createCarePlanTasks: (id: string, tasks: { task: string; owner?: string }[]) =>
    req<{ ok: number; created: number; refs: string[] }>(`/patients/${id}/care-plan/tasks`, { method: "POST", body: JSON.stringify({ tasks }) }),

  // ---- builder discovery + AI connection admin ----
  optionsEvidence: () =>
    req<{
      fhirTypes: string[];
      sqlQueries: string[];
      vectorCollections: string[];
      evidenceSources: { slug: string; name: string }[];
      outputSchemas: { slug: string; name: string }[];
      prompts: { slug: string; name: string }[];
      actionTemplates: { slug: string; name: string }[];
    }>("/options/evidence"),
  adminLlmGet: () =>
    req<{
      keySet: number; keyMasked: string; model: string; endpoint: string; useCache: number; mode: string;
      cacheCounts?: Record<string, number>;
      tiers?: { cached: number; live: number; deterministic: number };
      promptVersion?: string;
    }>("/admin/llm"),
  adminLlmSet: (body: { key?: string; clearKey?: number; model?: string; endpoint?: string; useCache?: number }) =>
    req<{ keySet: number; keyMasked: string; model: string; endpoint: string; useCache: number; mode: string }>("/admin/llm", { method: "POST", body: JSON.stringify(body) }),
  adminLlmTest: () => req<{ ok: number; model?: string; reply?: string; error?: string }>("/admin/llm/test", { method: "POST", body: "{}" }),
  adminLlmCache: (p: { kind?: string; q?: string; offset?: number; limit?: number } = {}) => {
    const qs = new URLSearchParams();
    if (p.kind) qs.set("kind", p.kind);
    if (p.q) qs.set("q", p.q);
    if (p.offset) qs.set("offset", String(p.offset));
    if (p.limit) qs.set("limit", String(p.limit));
    return req<{ total: number; entries: { id: string; kind: string; model: string; promptVersion: string; createdAt: string; size: number; preview: string; cacheKey: string }[] }>(`/admin/llm/cache?${qs}`);
  },
  adminLlmCacheEntry: (id: string) =>
    req<{ id: string; cacheKey: string; kind: string; model: string; promptVersion: string; createdAt: string; inputPreview: string; output: string }>(`/admin/llm/cache/${id}`),

  // ---- real Communication records (sent messages / shares / notes) ----
  sendCommunication: (id: string, body: { category: string; text: string }) =>
    req<{ ok: number; ref: string }>(`/patients/${id}/communication`, { method: "POST", body: JSON.stringify(body) }),

  // ---- triage conversation persistence ----
  saveTriageSession: (id: string, body: { complaint: string; items: { question: string; answer: string }[] }) =>
    req<{ ok: number; ref: string }>(`/patients/${id}/triage-session`, { method: "POST", body: JSON.stringify(body) }),

  // ---- in-chart preventative care ----
  patientPreventative: (id: string) => req<PreventativeResult>(`/patients/${id}/preventative`),
  preventativeLetter: (id: string, area: string) =>
    req<LetterResult>(`/patients/${id}/preventative/letter`, { method: "POST", body: JSON.stringify({ area }) }),

  // ---- explicit FHIR tools (over the real FHIR repository) ----
  patientSearch: (q: { name?: string; gender?: string; birthDate?: string; nhs?: string; mrn?: string; identifier?: string }) => {
    const p = new URLSearchParams();
    if (q.name) p.set("name", q.name);
    if (q.gender) p.set("gender", q.gender);
    if (q.birthDate) p.set("birthDate", q.birthDate);
    if (q.nhs) p.set("nhs", q.nhs);
    if (q.mrn) p.set("mrn", q.mrn);
    if (q.identifier) p.set("identifier", q.identifier);
    return req<{ patients: PatientSearchResult[]; count: number }>(`/fhir/tools/patient-search?${p.toString()}`);
  },
  everything: (patient: string) => req<EverythingBundle>(`/fhir/tools/everything?patient=${encodeURIComponent(patient)}`),
  terminology: (text: string, system?: string) =>
    req<{ query: string; concepts: TerminologyConcept[]; count: number }>(
      `/fhir/tools/terminology?text=${encodeURIComponent(text)}${system ? `&system=${system}` : ""}`
    ),
  cohort: (code: string, resourceType = "Condition") =>
    req<{ code: string; resourceType: string; patients: { ref: string }[]; count: number }>(
      `/fhir/tools/cohort?code=${encodeURIComponent(code)}&resourceType=${resourceType}`
    ),

  // ---- approval workflow + worklists ----
  approveAction: (requestId: string, actionId: string, body: { reviewer?: string; note?: string; resource?: unknown }) =>
    req<{ committedResourceRef: string; decision: string; status: string }>(
      `/invocations/${requestId}/actions/${actionId}/approve`,
      { method: "POST", body: JSON.stringify(body) }
    ),
  rejectAction: (requestId: string, actionId: string, body: { reviewer?: string; note?: string }) =>
    req<{ decision: string; status: string }>(`/invocations/${requestId}/actions/${actionId}/reject`, {
      method: "POST",
      body: JSON.stringify(body),
    }),
  audit: (requestId: string) => req<{ invocationId: string; audit: AuditEntry[]; count: number }>(`/invocations/${requestId}/audit`),
  worklist: (key: string) => req<WorklistResponse>(`/worklists/${key}`),
};
