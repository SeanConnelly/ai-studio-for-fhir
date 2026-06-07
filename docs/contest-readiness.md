# Contest readiness — requirements, deployment, bonus points

Workstream tracker for getting **FHIR Agent Studio** submitted, judge-runnable, and
scoring every available bonus. Companion to `docs/submission-guide.md` (the manual
runbook Sean executes).

**Deadline: 2026-06-07 23:59 EST (tomorrow). Voting 06-08 → 06-14** — apps *can* be
improved during voting, so anything not done by the deadline can still land early in
voting week, but the repo + Open Exchange entry + contest application must exist by
the deadline.

Sources verified 2026-06-06:
- [Contest announcement](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-fhir)
- [Technology bonuses post](https://community.intersystems.com/post/technology-bonuses-intersystems-programming-contest-ai-agents-fhir) (note: "The list of bonuses is subject to change")

---

## 1. Core requirements matrix

| # | Requirement | Status | Notes / remaining action |
|---|---|---|---|
| 1 | Fully functional, not a wrapper for an existing library | ✅ | Compiler + real Ens.Production runtime + 2 SPAs, all original. |
| 2 | Works on IRIS / IRIS for Health **Community Edition** | ✅ | `intersystemsdc/irishealth-community:latest`; two clean `up --build` gates passed 2026-06-06. |
| 3 | Open source, published on GitHub/GitLab | ⏳ **Sean** | Repo not yet pushed. LICENSE (MIT) present. `.gitignore` verified: `.env`, `*.env`, `grok-api-key.env` all ignored. |
| 4 | README in English with installation steps | ✅ | `README.md` quick start = clone + `docker compose up --build`. Placeholder `<your-org>` URLs to fill at push time. |
| 5 | README has video demo and/or detailed description | 🟡 | Detailed description ✅; video link to add once recorded (script: `docs/video-script.md`). |
| 6 | ≤ 3 submissions per developer | ✅ | One submission. |
| 7 | Open Exchange app published + applied to contest 46 | ⏳ **Sean** | `docs/submission-guide.md` §5–6. |
| 8 | Judging = complexity & usefulness | ✅ | The two-app showcase + 12 agents + demo guide are the answer. |

## 2. Technology bonus matrix (verified point values)

**Secured by existing work: 16 pts.** Realistic total with the actions below: **29–35 pts** (+3 more if Embedded Python is reversed, +4 if a Community Opportunity idea fits).

| Bonus | Pts | Status | Action / owner |
|---|---|---|---|
| Implement suggested task | 5 | ✅ secured | We implement **all 12**; bonus counts **once**. README + OEX description must name the claim explicitly (we lead with Imaging/Results Follow-Up; the other 11 strengthen complexity). |
| InterSystems FHIR Server usage | 2 | ✅ secured | Real IRIS for Health FHIR R4 repo (`HSFHIR_X0001_R`) — say it explicitly in README/OEX. |
| Vector Search | 4 | ✅ secured | Native `VECTOR_DOT_PRODUCT` over real all-minilm embeddings, used by 4+ agents. Make visible in README/video. |
| Embedded Python | 3 | 🟡 built, runtime-blocked | **Done 2026-06-06** (Sean approved): `FAST.Runtime.SqlGuard` + `iris/python/fast_sqlguard.py` — an sqlparse AST-level read-only gate behind the NL→FHIR hero, with a sacrificial-job health probe (`Armed()`) because in-process Embedded Python **SIGSEGVs in the current image** (see the bug row). On healthy runtimes the gate genuinely runs (`readOnlyGuard:"objectscript+sqlparse"`); on broken ones it truthfully reports `"objectscript"`. Claim the bonus honestly: "uses Embedded Python where the runtime is healthy + we found/reported the runtime bug". Smoke green, ask 152/152 verified post-wiring. |
| LLM AI / LangChain | 3 | ✅ secured | Real Grok via OpenAI-compatible HTTP + bundled real completions + BYO-key live path + a **shipped budget-capped community key** for live AI on cache misses (`docs/demo-llm-key.md`). **Sean before push:** mint a dedicated key, set the $25 cap, rotate the blob to it. |
| Docker container | 2 | ✅ secured | One-command `docker compose up --build`. |
| ZPM package deployment | 2 | 🟡 action | `module.xml` exists and the prod build runs `zpm load`. To claim: tick **Publish in Package Manager** on OEX (Sean) after a by-hand `zpm load` re-test; bump `module.xml` `<Version>` 0.1.0 → 1.0.0 to match the release tag. Document that the package targets the FAST namespace on IRIS for Health (the namespace script creates it). |
| Online demo | 2 | 🟡 approved, runbook in progress | Sean approved (2026-06-06): generic small-VPS deploy. Runbook `docs/online-demo.md`; Sean provisions/deploys by hand. Can land during voting week. |
| Community Opportunity idea | 4 | 🟡 research | Ideas portal can't be filtered by URL; needs a 10-min manual browse of [ideas.intersystems.com](https://ideas.intersystems.com/) filtered to status "Community Opportunity". Only claim if an idea matches what we **already built** — implementing something new by tomorrow isn't realistic. (Only confirmed CO idea found so far: "Prettier plugin for ObjectScript" — no fit.) |
| Bug in Vector Search / Embedded Python | 2 (+1 2nd, per tech) | ✅ found + stress-tested | **Found 2026-06-06, hardened same day:** in-process Embedded Python calls crash the process in `irishealth-community` **2026.1 AND 2026.2**, while **2025.3 works on the identical host/kernel with identical Ubuntu 24.04 + Python 3.12.3** → an IRIS-build regression (226U→235U), not environment. seccomp ruled out; PythonRuntimeLibrary ruled out; no prior public report found; other contest entries (CardioIris) use EP on this image. Full matrix + forensics: `docs/embedded-python-bug.md`. **Sean posts it** (DC post for bonus visibility). |
| First DC article | 2 | 🟡 action | I draft, Sean posts. Announcement/walkthrough article. |
| Second DC article | 1 | 🟡 action | I draft, Sean posts. Deep-dive: the record/replay LLM cache pattern or "a real Ens.Production as an AI-agent runtime". (3rd+ articles score nothing.) |
| First-time contribution | 3 | ❌ not eligible | Sean has entered an Open Exchange contest before (confirmed 2026-06-06). |
| YouTube video | 3 ×3 | 🟡 approved: all 3 | Sean approved all three (2026-06-06). Video 1 (main demo, script ready: `docs/video-script.md`) before the deadline; videos 2 ("build the 13th agent yourself") + 3 ("under the hood: prove it's real") scripted for voting week. Sean records/uploads; links in README + OEX. |

## 3. Judge-deployment reliability

Already proven: two clean cold `docker compose up --build` rounds (2026-06-06) — smoke green, 66/66 agent matrix, all triage paths, 152/152 ask, starters, PA queue, fully keyless. The remaining risks are all *first-mile* (between `git clone` and `docker compose up`):

| Risk | Status |
|---|---|
| **CRLF on fresh clone** — Git for Windows defaults `core.autocrlf=true`; without `.gitattributes` every script/seed file checks out CRLF and the Linux Docker build breaks on `iris.script` / `create-fast-namespace.script` / `*.sh`. Our working tree only works because files were written LF and never re-checked-out. | ✅ **fixed 2026-06-06**: `.gitattributes` added (`* text=auto eol=lf` + binary exceptions). At commit time Sean should run `git add --renormalize .` once and verify `git ls-files --eol` shows `i/lf` throughout. |
| **Fresh-clone build never tested** — every gate ran from the working copy. | ⏳ After push: clone to a temp dir on a machine (or fresh dir) with default git settings → `docker compose up --build` → smoke + spot-check the demo guide. This is the single most valuable pre-submission test. |
| README placeholders (`<your-org>`) | ⏳ Sean fills at push time. |
| `module.xml` `<Version>` = 0.1.0 but runbook tags v1.0.0 | 🟡 Bump to 1.0.0 in the same commit as the tag (coordinate with the code agent — one-line change). |
| Prerequisites not stated (Docker Desktop RAM, disk, build time) | 🟡 Add to README: ~8 GB free RAM for Docker, ~10 GB disk, first build pulls the IRIS image (~3–4 GB) and takes several minutes — set expectations so judges don't abort mid-pull. |
| Port collision | ✅ Already mitigated (42773/41972 off IRIS ranges) and documented. |
| Judge needs no key | ✅ Proven keyless on cold build. |
| Troubleshooting doc | ✅ `docs/troubleshooting.md` + README section. |

## 4. Open decisions (Sean)

### 4.1 Embedded Python (3 pts) — RESOLVED 2026-06-06
Sean approved option B (one genuine EP feature). Built: the sqlparse AST gate
(`FAST.Runtime.SqlGuard`) with sacrificial-job arming. See the bonus-matrix row and
`docs/embedded-python-bug.md` for the runtime bug discovered in the process.

### 4.2 Online demo (2 pts) — RESOLVED 2026-06-06
Approved: generic small-VPS deploy, runbook at `docs/online-demo.md`, Sean
provisions/deploys by hand.

### 4.3 First-time contribution (3 pts) — RESOLVED 2026-06-06
Not eligible (Sean has entered before).

### 4.4 Videos (3–9 pts) — RESOLVED 2026-06-06
All three approved: main demo before the deadline, "build the 13th agent yourself" +
"under the hood: prove it's real" during voting week. Scripts in `docs/`.

## 5. Priority order (deadline: tomorrow 23:59 EST)

**Must happen before the deadline (gates submission):**
1. ~~`.gitattributes`~~ ✅ done
2. Code/data agent finishes current work → final clean `up --build` + ALL `--verify` suites (summaries / agents / triage / ask / **starters — now 4 incl. Metformin Renal Safety**) + smoke. (Studio v3 landed 06-07: step-rail builder w/ per-step testing + prompt preview, gallery/workspace flow-first fix, fake Prompt/Action managers removed, 13th-agent starter cached — decision log has the full entry.)
3. `module.xml` → 1.0.0; README placeholders + prerequisites block + explicit bonus-visibility lines
4. **Sean:** push to public GitHub, tag v1.0.0, **fresh-clone test**, OEX entry, apply to contest 46, claim suggested-task bonus in the description
5. **Sean:** record + upload video 1, link in README/OEX

**High value, can trail into early voting week:**
6. DC article 1 (draft: me → post: Sean) — also gives the OEX "Community Article URL" field a value
7. Online demo (if §4.2 = yes) — runbook me, deploy Sean
8. ZPM publish checkbox after by-hand `zpm load` re-test
9. DC article 2; videos 2–3
10. 10-min Ideas-portal browse for a Community Opportunity match

---
*Maintained by the contest-readiness workstream. Update statuses in place.*
