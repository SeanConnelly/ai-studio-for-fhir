// Rebuilds (or verifies) the LLM cache for EVERY pinned agent demo combo in
// one command - the canonical post-data-change rebuild. Combos mirror
// frontend/clinical/src/agents.ts and the demo-guide flows exactly.
//
// Usage:   node scripts/build-agents-cache.mjs [--verify]
//   build mode needs the key armed (^FAST("llm","key")) and useCache=0.
//   --verify: keyless check that every combo replays source=cached.
//
// Also handles the hero's post-sign "loop closed" state for results-followup
// (sign the draft -> re-run -> delete the committed Task) in build mode.

const BASE = process.env.FAST_BASE || "http://localhost:42773/fhir-agent-studio/api";
const FHIR = BASE.replace(/\/api$/, "/fhir/r4");
const AUTH = "Basic " + Buffer.from("_SYSTEM:SYS").toString("base64");
const VERIFY = process.argv.includes("--verify");

const P = (n) => `Patient/syn-pat-${String(n).padStart(4, "0")}`;
const range = (a, b) => Array.from({ length: b - a + 1 }, (_, i) => a + i);

const COMBOS = [
  // smart summaries (flagship + worklist heroes)
  ...[1, 61, 85, 25].map((n) => ({ slug: "smart-patient-summary", inputs: { patient: P(n) } })),
  { slug: "smart-patient-summary", inputs: { patient: "Patient/pat-abnormal-001" } },
  // flagship in-chart decision support
  { slug: "medication-safety", inputs: { patient: P(1) } },
  { slug: "gaps-in-care", inputs: { patient: P(1), gapType: "diabetes-a1c" } },
  // care-plan navigator (portal cohort)
  ...range(1, 12).map((n) => ({ slug: "care-plan-navigator", inputs: { patient: P(n) } })),
  // social prescribing (portal cohort + worklist hero)
  ...range(1, 12).map((n) => ({ slug: "sdoh-referral", inputs: { patient: P(n) } })),
  { slug: "sdoh-referral", inputs: { patient: P(61) } },
  // lab explainer (portal cohort)
  ...range(1, 12).map((n) => ({ slug: "lab-explainer", inputs: { patient: P(n) } })),
  // readmission risk (discharge band)
  ...range(85, 96).map((n) => ({ slug: "readmission-risk", inputs: { patient: P(n) } })),
  // results follow-up tracker cohort
  { slug: "results-followup", inputs: { patient: "Patient/pat-abnormal-001", diagnosticReportId: "DiagnosticReport/dr-abnormal-001" }, heroLoop: true },
  ...[2, 3, 4].map((n) => ({ slug: "results-followup", inputs: { patient: P(n), diagnosticReportId: "" } })),
  // trial matcher (incl. the answered-follow-ups variant - text must match agents.ts)
  ...[1, 73, 75, 102].map((n) => ({ slug: "clinical-trial-matcher", inputs: { patient: P(n), followUpAnswers: "" } })),
  { slug: "clinical-trial-matcher", inputs: { patient: P(1), followUpAnswers: "He completed a 6-month dietitian-led weight management programme last year without sustained weight loss. Latest triglycerides 180 mg/dL with normal liver function tests." } },
];

async function call(path, method = "GET", body) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: { "Content-Type": "application/json", Authorization: AUTH },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  return res.json();
}

let failures = 0, n = 0;
for (const c of COMBOS) {
  n++;
  const j = await call(`/flows/${c.slug}/run`, "POST", { inputs: c.inputs });
  const src = (j.aiTrace?.source || j.source || "").split(" ")[0];
  const who = c.inputs.patient || "-";
  if (VERIFY ? src !== "cached" : src !== "live") {
    failures++;
    console.log(`[${VERIFY ? "MISS" : "NOT LIVE"} ${n}/${COMBOS.length}] ${c.slug} ${who} -> ${src}`);
  } else if (n % 10 === 0) {
    console.log(`[ok ${n}/${COMBOS.length}] ${c.slug} ${who}`);
  }

  // hero closed-loop state: sign -> re-run (caches the "all closed" answer) -> restore
  if (c.heroLoop && !VERIFY) {
    try {
      const aid = (await call(`/invocations/${j.requestId}`)).proposedActions?.[0]?.id;
      if (aid) {
        const ap = await call(`/invocations/${j.requestId}/actions/${aid}/approve`, "POST", { reviewer: "cache-builder" });
        await call(`/flows/${c.slug}/run`, "POST", { inputs: c.inputs }); // closed-state entry
        if (ap.committedResourceRef) {
          await fetch(`${FHIR}/${ap.committedResourceRef}`, { method: "DELETE", headers: { Authorization: AUTH } });
          console.log(`  hero loop: cached closed state, restored open loop (${ap.committedResourceRef} removed)`);
        }
      }
    } catch (e) {
      console.log(`  hero loop step failed: ${e.message}`);
      failures++;
    }
  }
}

// the preventative letter (flagship diabetes recall)
const letter = await call(`/patients/syn-pat-0001/preventative/letter`, "POST", { area: "diabetes" });
const lsrc = (letter.source || "").split(" ")[0];
if (VERIFY ? lsrc !== "cached" : lsrc !== "live") { failures++; console.log(`[${VERIFY ? "MISS" : "NOT LIVE"}] preventative letter -> ${lsrc}`); }

console.log(`\nDone. ${VERIFY ? "misses" : "problems"}=${failures} over ${COMBOS.length + 1} combos`);
process.exit(failures ? 1 : 0);
