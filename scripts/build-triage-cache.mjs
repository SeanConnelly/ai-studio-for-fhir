// Pre-builds the LLM cache for the triage conversations: for each pinned
// scenario it builds the phase-1 question set, then EVERY combination of
// answers' phase-2 handoff - so any path a judge clicks through the chat
// replays real Grok output key-free.
//
// Usage:   node scripts/build-triage-cache.mjs [--verify] [--only=0101,0102]
//   build mode needs the key armed (^FAST("llm","key")) and useCache=0.
//   --verify: keyless check that every path replays source=cached.
//   --only:   restrict to scenarios whose patient id contains one of the tokens.
import { readFileSync } from "node:fs";
import { serializeAnswers } from "../frontend/shared/lib/triage-serialize.mjs";

const BASE = process.env.FAST_BASE || "http://localhost:42773/fhir-agent-studio/api";
const AUTH = "Basic " + Buffer.from("_SYSTEM:SYS").toString("base64");
const VERIFY = process.argv.includes("--verify");
const onlyArg = process.argv.find((a) => a.startsWith("--only="));
const only = onlyArg ? onlyArg.slice(7).split(",") : null;

// Single source of truth, shared with the UI (the strings are cache keys).
const catalogue = JSON.parse(readFileSync(new URL("../seed/demo-inputs/triage-scenarios.json", import.meta.url), "utf8"));
const SCENARIOS = catalogue.scenarios.filter((s) => !only || only.some((t) => s.patient.includes(t)));

async function run(inputs) {
  const res = await fetch(`${BASE}/flows/conversational-triage/run`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: AUTH },
    body: JSON.stringify({ inputs }),
  });
  return res.json();
}

function combos(questions) {
  let acc = [[]];
  for (const q of questions) {
    const next = [];
    for (const path of acc) for (const o of q.options) next.push([...path, { question: q.text, answer: o }]);
    acc = next;
  }
  return acc;
}

let failures = 0;
for (const s of SCENARIOS) {
  console.log(`\n=== ${s.patient} | "${s.complaint}"`);
  const p1 = await run({ patient: s.patient, chiefComplaint: s.complaint, answers: "" });
  const src1 = p1.aiTrace?.source || p1.source;
  const qs = p1.questions || [];
  console.log(`phase 1: ${src1} | ${qs.length} questions | options: ${qs.map((q) => q.options.length).join("x")}`);
  if (qs.length !== 4) { console.log("UNEXPECTED question count - aborting scenario"); failures++; continue; }
  if (VERIFY && src1 !== "cached") { console.log("[MISS] phase 1"); failures++; }

  const paths = combos(qs);
  console.log(`${paths.length} answer combinations`);
  let n = 0;
  for (const path of paths) {
    n++;
    const j = await run({ patient: s.patient, chiefComplaint: s.complaint, answers: serializeAnswers(path) });
    const src = j.aiTrace?.source || j.source;
    if (VERIFY) {
      if (src !== "cached") { console.log(`[MISS ${n}/${paths.length}] ${path.map((p) => p.answer).join(" / ")}`); failures++; }
    } else {
      const ok = j.urgency && (j.keyFindings || []).length > 0;
      if (!ok) { console.log(`[WEAK ${n}/${paths.length}] urgency=${j.urgency} findings=${(j.keyFindings || []).length}`); failures++; }
      else if (n % 6 === 0) console.log(`[ok ${n}/${paths.length}] ${path.map((p) => p.answer).join(" / ")} -> ${j.urgency}`);
    }
  }
}
console.log(`\nDone. ${VERIFY ? "misses" : "problems"}=${failures}`);
process.exit(failures ? 1 : 0);
