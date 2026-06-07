// Pre-generates a smart-patient-summary for EVERY patient in the cohort
// (syn-pat-0001..1000 + the 7 hand-crafted heroes) so any chart a judge opens
// has a real keyless AI summary. ~1007 live Grok calls, run with modest
// concurrency.
//
// Usage:   node scripts/build-summary-cache.mjs [--verify] [--from=N] [--to=N]
//   build mode needs the key armed (^FAST("llm","key")) and useCache=0.
//   --verify: keyless check that every patient's summary replays source=cached.

const BASE = process.env.FAST_BASE || "http://localhost:42773/fhir-agent-studio/api";
const AUTH = "Basic " + Buffer.from("_SYSTEM:SYS").toString("base64");
const VERIFY = process.argv.includes("--verify");
const arg = (k, d) => { const a = process.argv.find((x) => x.startsWith(`--${k}=`)); return a ? Number(a.split("=")[1]) : d; };
const FROM = arg("from", 1), TO = arg("to", 1000);
const CONCURRENCY = VERIFY ? 8 : 4;

const HEROES = ["pat-abnormal-001", "pat-prior-auth-001", "pat-cohort-001", "pat-cohort-002", "pat-cohort-003", "pat-cohort-004", "pat-cohort-005"];
const ids = [
  ...Array.from({ length: TO - FROM + 1 }, (_, i) => `syn-pat-${String(FROM + i).padStart(4, "0")}`),
  ...(FROM === 1 ? HEROES : []),
];

let done = 0, problems = 0;
const failedIds = [];

async function runOne(id) {
  try {
    const r = await fetch(`${BASE}/flows/smart-patient-summary/run`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: AUTH },
      body: JSON.stringify({ inputs: { patient: `Patient/${id}` } }),
    });
    const j = await r.json();
    const src = (j.aiTrace?.source || j.source || "").split(" ")[0];
    const ok = VERIFY ? src === "cached" : src === "live";
    if (!ok) { problems++; failedIds.push(id); console.log(`[${VERIFY ? "MISS" : "NOT LIVE"}] ${id} -> ${src}`); }
  } catch (e) {
    problems++; failedIds.push(id);
    console.log(`[ERROR] ${id}: ${e.message}`);
  }
  done++;
  if (done % 50 === 0) console.log(`${done}/${ids.length}…`);
}

// simple worker pool
const queue = [...ids];
await Promise.all(Array.from({ length: CONCURRENCY }, async () => {
  while (queue.length) await runOne(queue.shift());
}));

console.log(`\nDone. ${VERIFY ? "misses" : "problems"}=${problems} over ${ids.length} patients`);
if (failedIds.length) console.log("failed:", failedIds.join(","));
process.exit(problems ? 1 : 0);
