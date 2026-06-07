// Pre-builds the LLM cache for EVERY variant of the "Surprise me" question
// catalogue, so random questions replay real Grok translations key-free.
//
// Usage:   node scripts/build-ask-cache.mjs [--verify]
//   (default) build mode: requires the Grok key armed in ^FAST("llm","key")
//             and useCache=0; runs each variant live, retrying failures twice.
//   --verify: keyless check that every variant replays source=cached.
//
// Broken variants (SQL that never prepares/executes after retries) are
// reported at the end - add them to the catalogue's "exclusions" so the UI
// never offers them.
import { readFileSync } from "node:fs";
import { allQuestions } from "../frontend/shared/lib/ask-questions.mjs";

const BASE = process.env.FAST_BASE || "http://localhost:42773/fhir-agent-studio/api";
const AUTH = "Basic " + Buffer.from("_SYSTEM:SYS").toString("base64");
const VERIFY = process.argv.includes("--verify");

const catalogue = JSON.parse(readFileSync(new URL("../seed/demo-inputs/ask-questions.json", import.meta.url), "utf8"));
const questions = allQuestions(catalogue);
console.log(`${questions.length} question variants${VERIFY ? " (verify mode)" : ""}`);

async function run(question) {
  const res = await fetch(`${BASE}/flows/nl-to-fhir-query/run`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: AUTH },
    body: JSON.stringify({ inputs: { question } }),
  });
  return res.json();
}

function isBroken(j) {
  if (j.validationStatus === "rejected") return "rejected";
  const lim = (j.limitations || []).find((l) => l.includes("could not be prepared") || l.includes("SQLCODE"));
  return lim ? lim.slice(0, 110) : null;
}

const failures = [];
let ok = 0, notCached = 0;

for (let i = 0; i < questions.length; i++) {
  const q = questions[i];
  let j, problem;
  try {
    if (VERIFY) {
      j = await run(q);
      const src = j.aiTrace?.source || j.source;
      if (src !== "cached") { notCached++; console.log(`[MISS] ${q}`); }
      else ok++;
      continue;
    }
    // build mode: up to 3 attempts (a fresh live call overwrites the cache entry)
    for (let attempt = 1; attempt <= 3; attempt++) {
      j = await run(q);
      problem = isBroken(j);
      if (!problem) break;
    }
    if (problem) {
      failures.push(q);
      console.log(`[FAIL ${i + 1}/${questions.length}] ${q}\n       ${problem}`);
    } else {
      ok++;
      if (ok % 10 === 0) console.log(`[ok ${i + 1}/${questions.length}] ${q} (matches=${j.matchCount ?? "-"})`);
    }
  } catch (e) {
    failures.push(q);
    console.log(`[ERR ${i + 1}/${questions.length}] ${q}: ${e.message}`);
  }
}

console.log(`\nDone. ok=${ok}${VERIFY ? ` notCached=${notCached}` : ` failed=${failures.length}`}`);
if (!VERIFY && failures.length) {
  console.log("\nAdd these to seed/demo-inputs/ask-questions.json exclusions:");
  console.log(JSON.stringify(failures, null, 2));
}
process.exit(failures.length || notCached ? 1 : 0);
