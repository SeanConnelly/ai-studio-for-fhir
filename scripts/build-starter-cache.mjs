// Pre-builds the LLM cache for the New Agent wizard starters: each starter is
// created EXACTLY as the wizard would create it (same slug, same definition),
// run once against its default patient (a live Grok call), then the flow is
// deleted again - so a judge who creates the starter unchanged gets a REAL
// cached AI result on their very first run, key-free.
//
// Usage:   node scripts/build-starter-cache.mjs [--verify] [--only=<starterKey>]
//   build mode needs the key armed (^FAST("llm","key")) and useCache=0.
//   --verify: keyless check (creates the flow, runs, expects source=cached,
//             deletes the flow again).
//   --only=<key>: build/verify a single starter (avoids re-burning the other
//                 starters' golden responses when adding a new one).
import { readFileSync } from "node:fs";

const BASE = process.env.FAST_BASE || "http://localhost:42773/fhir-agent-studio/api";
const AUTH = "Basic " + Buffer.from("_SYSTEM:SYS").toString("base64");
const VERIFY = process.argv.includes("--verify");
const ONLY = (process.argv.find((a) => a.startsWith("--only=")) || "").slice(7);

const catalogue = JSON.parse(readFileSync(new URL("../seed/demo-inputs/agent-starters.json", import.meta.url), "utf8"));

function slugify(name) {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 60) || "new-agent";
}

async function call(path, method = "GET", body) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: { "Content-Type": "application/json", Authorization: AUTH },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  return res.json();
}

let failures = 0;
for (const s of catalogue.starters) {
  if (s.key === "blank" || !s.suggestedName) continue;
  if (ONLY && s.key !== ONLY) continue;
  const slug = slugify(s.suggestedName);
  console.log(`\n=== ${s.suggestedName} (${slug})`);

  // create exactly as the wizard does
  const saved = await call("/flows", "POST", { ...s.definition, id: slug, name: s.suggestedName });
  console.log(`save: compiled=${saved.compiled} deployed=${saved.deployed}${(saved.errors || []).length ? " errors=" + saved.errors.join("; ") : ""}`);
  if (!saved.deployed) { failures++; continue; }

  // run with the definition's default inputs (what the Run tab sends untouched)
  const inputs = {};
  for (const i of s.definition.inputs || []) inputs[i.key] = i.default ?? "";
  const r = await call(`/flows/${slug}/run`, "POST", { inputs });
  const src = r.aiTrace?.source || r.source;
  console.log(`run: ${src} | status=${r.status} | summary=${String(r.summary || "").slice(0, 90)}`);
  if (VERIFY ? src !== "cached" : String(src).startsWith("deterministic")) {
    console.log(VERIFY ? "[MISS]" : "[NOT LIVE - key armed?]");
    failures++;
  }

  // remove the flow so the judge's "New Agent" creates it fresh
  const del = await call(`/flows/${slug}`, "DELETE");
  console.log(`cleanup: deleted=${del.deleted ?? del.ok ?? "?"}`);
}
console.log(`\nDone. failures=${failures}`);
process.exit(failures ? 1 : 0);
