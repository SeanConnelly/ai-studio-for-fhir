# Submission Runbook (manual steps — Sean executes)

> **These steps are performed by Sean, by hand.** The build assistant does not run
> `git push`, `gh`, Open Exchange registration/publishing, IPM publish, or the
> contest application. This is the checklist to follow when you're ready to submit.
>
> Background/reference: `docs/intersystems_project_submission_guide.md` (the full
> research notes, including the Open Exchange field table).

Contest: **InterSystems "AI Agents for FHIR"** — Open Exchange contest **46**.
Submission deadline: **2026-06-07 23:59 EST**. Voting: 2026-06-08 → 06-14.

---

## 0. Pre-flight (verify the judge experience locally)

From a clean checkout, confirm the one-command flow works:

```bash
docker compose up --build          # builds SPA + bakes everything via IPM
```
Then open and sanity-check:
- Portal: http://localhost:42773/fhir-agent-studio/
- Status: http://localhost:42773/fhir-agent-studio/api/status  → `"status":"ok"`, 12 templates

Run the smoke test (see `test/smoke-test.sh`):
```bash
./test/smoke-test.sh
```
Expected: status ok, 12 templates, a hero compiles, a hero runs, trace has 8 steps.

Also verify the demo dress rehearsal in `docs/demo-script.md` end to end.

> Note on ports: the app uses host port **42773** (off IRIS's default ranges) so it
> won't collide with any IRIS a judge already runs. The README documents this.

---

## 1. License file

Add an OSI license (MIT recommended) at the repo root as `LICENSE` if not present.
Make sure the year/author are correct.

---

## 2. GitHub repository (public)

The repo must be public and on GitHub (or GitLab). From the project root:

```bash
git init                      # if not already a repo
git add .
git commit -m "FHIR Agent Studio — IRIS-native AI-agent workflow studio"
# create the repo on github.com first (public), then:
git remote add origin https://github.com/<your-org>/fhir-agent-studio.git
git branch -M main
git push -u origin main
```

Confirm `.gitignore` is doing its job — these must NOT be committed:
`node_modules/`, `frontend/dist/`, `dist/`, `irisdata/`, `.env`, `work/`.
(`.env.example` IS committed; `.env` is not.)

---

## 3. Tag a release

Keep the version consistent across `module.xml` (`<Version>`), the git tag, and the
Open Exchange release form.

```bash
git tag v1.0.0
git push origin v1.0.0
```

---

## 4. Verify the IPM (package-first) path

The package-first path is the production build itself — `docker compose up --build`
creates the `FAST` namespace + FHIR R4 endpoint (`create-fast-namespace.script`),
then runs `zpm "load" → FAST.Setup.PostInstall` at build time. A clean
Reload / Compile / Configure / Activate plus a passing smoke test is the pass
condition:

```bash
docker compose up --build -d
bash test/smoke-test.sh                      # expect 10/10
```

To exercise `zpm load` by hand, do it **in the `FAST` namespace** (it must exist
first — IPM does not create it; the build script does):
```objectscript
zn "FAST"
zpm "load /path/to/repo -v"
```

---

## 5. Publish on Open Exchange

Open Exchange hosts the *listing*, not the code. Create the app entry, point it at
the GitHub repo, fill the fields (see the table in
`docs/intersystems_project_submission_guide.md` §3.1), then **Send for Approval**.

Key fields:
- **Name:** FHIR Agent Studio
- **Short description:** IRIS-native developer portal that compiles FHIR AI-agent workflows into HealthConnect-style runtime recipes.
- **InterSystems tech:** IRIS for Health, FHIR, Interoperability, IPM, Docker, Vector Search
- **Category:** Framework / Technology Example
- **YouTube URL:** the demo video (Section 7 below)
- **License URL / About URL:** the repo `LICENSE` / `README`
- **Publish in Package Manager:** tick **only** after the `zpm load` test in step 4 passes.

---

## 6. Apply to the contest

After the app is published/approved on Open Exchange, apply it to **contest 46**
("AI Agents for FHIR") from the contest page or the app's Contest tab.

Claim the **suggested-task bonus** (counts once): the entry implements **all twelve**
suggested tasks; claim **Imaging & Results Follow-Up Tracker** as the featured one
and say so explicitly in the description.

Also surface every bonus the app demonstrably earns (full matrix + statuses:
`docs/contest-readiness.md`): InterSystems FHIR Server, Vector Search, LLM AI,
Embedded Python (the sqlparse SQL gate — be ready to point at
`FAST.Runtime.SqlGuard`), Docker, ZPM/IPM, Online Demo (`docs/online-demo.md`,
once live), Video. Separately: post the **Embedded Python bug report**
(`docs/embedded-python-bug.md`) on the Developer Community for the find-a-bug
bonus, and the two articles (`docs/articles/`) for the article bonuses.

---

## 7. Video

Record the demo per `docs/video-script.md` (4–7 min), upload to YouTube, and put the
link on the Open Exchange page and in the README.

---

## Final checklist before "Send for Approval"

- [ ] Fresh clone + `docker compose up --build` works
- [ ] Portal loads at the documented URL; status endpoint returns ok
- [ ] `./test/smoke-test.sh` passes
- [ ] README renders correctly on GitHub (screenshots/GIF visible)
- [ ] `LICENSE` present; `module.xml` `<Version>` matches the git tag
- [ ] No secrets committed (`.env`, keys)
- [ ] Video uploaded and linked
- [ ] Suggested-task bonus identified in the description
