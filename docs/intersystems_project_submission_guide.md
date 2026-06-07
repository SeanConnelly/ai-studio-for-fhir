# InterSystems Contest Project Construction and Submission Guide

**Purpose:** A practical build-and-submission guide for an InterSystems contest project that judges can run with minimal friction.  
**Prepared for:** FHIR Agent Studio / AI Agents for FHIR contest planning.  
**Date:** 2026-05-25.

This guide combines official InterSystems/Open Exchange requirements with pragmatic packaging recommendations for a judge-friendly submission. Where a recommendation goes beyond the formal rules, it is labelled as a recommended practice rather than a formal requirement.

---

## 1. Executive summary

The safest contest submission pattern is:

```text
Public GitHub/GitLab repo
  + English README with exact install/run steps
  + Docker Compose one-command startup
  + module.xml for IPM/package-first installation
  + demo data loaded automatically
  + video demo or detailed app description
  + Open Exchange app page
  + contest application submitted from Open Exchange
```

For the FHIR Agent Studio project, the preferred construction is:

```text
IRIS / IRIS for Health container
  - ObjectScript backend
  - IRIS REST application
  - IRIS persistent storage
  - React/Vite/shadcn SPA built and served by IRIS
  - module.xml at repository root
  - Docker Compose as the primary judge-run path
  - deterministic seeded demo mode
```

The core principle is simple:

> A judge should be able to clone the repository, run one command, open one URL, and see the demo working without manual IRIS setup, missing data, secret keys, or unclear instructions.

---

## 2. Official contest requirements to satisfy

For the InterSystems Programming Contest: AI Agents for FHIR, the application must align with the topic: **develop an AI agent to be called in an interoperability FHIR solution**.

The official requirements include:

1. The app should work on **InterSystems IRIS Community Edition** or **InterSystems IRIS for Health Community Edition**.
2. It may use host installs or containers, including community container images such as `intersystemsdc/iris-community:latest` or `intersystemsdc/irishealth-community:latest`.
3. The app must be open source and published on **GitHub or GitLab**.
4. The README must be in English.
5. The README must contain installation steps.
6. The README must include either a video demo and/or a detailed description of how the application works.
7. Only three submissions per developer are allowed.
8. For this contest, submissions are judged on **Complexity, Clarity of Instructions, Developer Experience, Applicability, and Usability**.

## 2.1 What this means in practice

For this project, treat these as non-negotiable deliverables:

- public GitHub repository;
- English README;
- one-command Docker run path;
- clear demo URL;
- seeded demo data;
- no required external LLM/API key for the core demo;
- short video demo, strongly recommended even if not strictly mandatory when a written description exists;
- Open Exchange page submitted and approved before applying to the contest.

---

## 3. Submission flow on Open Exchange

Open Exchange does not host the source code itself. It publishes applications hosted externally, especially on GitHub or GitLab.

Recommended flow:

```text
1. Create public GitHub/GitLab repo
2. Add README, LICENSE, module.xml, Docker Compose, demo assets
3. Tag a release, e.g. v1.0.0
4. Publish the app on Open Exchange
5. Send the app for approval
6. Once public, apply the app to the contest
7. Keep improving during the registration/voting period if allowed by the contest rules
```

Open Exchange supports importing many fields automatically from a GitHub/GitLab repository. This makes the README especially important because the Open Exchange full description can be populated from repository metadata.

## 3.1 Open Exchange application form fields to prepare

Prepare these before submission:

| Field | Recommended value for FHIR Agent Studio |
|---|---|
| Application Name | `FHIR Agent Studio` |
| Short Description | `IRIS-native developer portal for compiling FHIR AI-agent workflows into HealthConnect-style runtime recipes.` |
| Category | `Framework`, `Interoperability`, or `Technology Example` depending on available choices |
| InterSystems Technology | `InterSystems IRIS for Health`, `InterSystems IRIS`, `FHIR`, `Interoperability`, `IPM`, `Docker` |
| Industries | `Healthcare` |
| Tags | `FHIR`, `AI`, `Agents`, `Interoperability`, `HealthConnect`, `ObjectScript`, `Docker`, `IPM`, `Vector Search` if applicable |
| Call to Action | `View on GitHub` or `Download` |
| About URL | GitHub repo or docs page |
| License URL | Link to repo `LICENSE` |
| Demo URL | Optional hosted demo or release asset |
| Documentation URL | README or `/docs` directory link |
| YouTube URL | Video demo link |
| Community Article URL | Optional article announcing the project |
| Publish in Package Manager | Check this only after `module.xml` and IPM packaging are tested |

## 3.2 Applying to the contest

The app must already be published on Open Exchange before contest application. You can apply via:

- the contest page;
- the app’s public page using the Contest tab;
- the developer portal’s application dropdown.

---

## 4. Repository construction pattern

The repository should be understandable to someone who has never seen the project before.

Recommended structure for the IRIS-first FHIR Agent Studio project:

```text
/fhir-agent-studio
  README.md
  LICENSE
  module.xml
  docker-compose.yml
  docker-compose.dev.yml
  Dockerfile
  .env.example
  .gitignore

  /iris
    /src
      /cls
        FHIRAgentStudio/API/Rest.cls
        FHIRAgentStudio/Data/*.cls
        FHIRAgentStudio/Compiler/*.cls
        FHIRAgentStudio/Runtime/*.cls
        FHIRAgentStudio/Seed/*.cls
        FHIRAgentStudio/ImportExport/*.cls
      /mac
      /inc
    /csp
      /fhir-agent-studio
        index.html
        assets/...
    iris.script

  /frontend
    package.json
    package-lock.json
    vite.config.ts
    tsconfig.json
    tailwind.config.js
    components.json
    /src
      App.tsx
      main.tsx
      /components
      /pages
      /api
      /types

  /seed
    /templates
    /demo-data

  /docs
    architecture.md
    diagrams.md
    demo-script.md
    troubleshooting.md

  /test
    smoke-test.sh
    api-smoke.http
```

## 4.1 Root-level files judges expect to find quickly

| File | Purpose |
|---|---|
| `README.md` | Primary judge instructions and project explanation |
| `docker-compose.yml` | One-command startup path |
| `module.xml` | IPM/package-first install manifest |
| `LICENSE` | Open-source license |
| `.env.example` | All environment variables with safe defaults |
| `docs/demo-script.md` | Step-by-step demo for judges |
| `docs/troubleshooting.md` | Known issues and fixes |

---

## 5. Docker-first run contract

Docker Compose should be the primary judge path.

## 5.1 Required commands

The README should include this exact style of quick start:

```bash
git clone https://github.com/<org>/fhir-agent-studio.git
cd fhir-agent-studio
cp .env.example .env
docker compose up --build
```

Then:

```text
Open: http://localhost:52773/fhir-agent-studio/
API:  http://localhost:52773/fhir-agent-studio/api/status
```

## 5.2 What `docker compose up --build` should do

The command should automatically:

1. build the React frontend;
2. copy the built SPA into the IRIS-served web app directory;
3. start IRIS or IRIS for Health;
4. create the application namespace, e.g. `IRISAPP`;
5. import and compile ObjectScript classes;
6. install/load the IPM module if using package-first flow;
7. create REST and SPA web applications;
8. load seed templates and demo FHIR/knowledge data;
9. expose one UI URL;
10. expose a health/status endpoint.

## 5.3 No-friction defaults

The default demo must not require:

- an OpenAI key;
- a remote FHIR server;
- a paid InterSystems license;
- manual Management Portal clicks;
- manual namespace creation;
- manual class import;
- manual seed-data load;
- custom local ports unless documented;
- more than Docker and Git.

External services can be optional, but the core demo must work offline or with deterministic mock behaviour.

---

## 6. IPM / module.xml packaging

InterSystems Package Manager, formerly ZPM, is a major part of the InterSystems packaging ecosystem. Open Exchange can publish IPM applications to the public package registry when the application is prepared correctly.

## 6.1 Recommended IPM posture

Even if Docker Compose is the primary judge path, include a working `module.xml` so the project follows InterSystems package-first expectations.

The `module.xml` should:

- live at the repository root;
- include the project name;
- include a semantic version;
- declare `SourcesRoot`;
- include ObjectScript package resources;
- declare REST and CSP/static web applications;
- invoke setup/seed methods if appropriate;
- be testable with `zpm load`.

## 6.2 Suggested module.xml shape

Adapt this pattern to the project:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Export generator="Cache" version="25">
  <Document name="fhir-agent-studio.MODULE">
    <Module>
      <Name>fhir-agent-studio</Name>
      <Version>1.0.0</Version>
      <Packaging>module</Packaging>
      <SourcesRoot>iris/src</SourcesRoot>

      <Resource Name="FHIRAgentStudio.PKG" />

      <CSPApplication
        Url="/fhir-agent-studio"
        SourcePath="/iris/csp/fhir-agent-studio"
        DeployPath="${cspdir}fhir-agent-studio"
        ServeFiles="1"
        Recurse="1"
        CookiePath="/fhir-agent-studio"
        UseCookies="2"
        PasswordAuthEnabled="0"
        UnauthenticatedEnabled="1" />

      <CSPApplication
        Url="/fhir-agent-studio/api"
        DispatchClass="FHIRAgentStudio.API.Rest"
        ServeFiles="0"
        Recurse="1"
        CookiePath="/fhir-agent-studio"
        UseCookies="2"
        PasswordAuthEnabled="0"
        UnauthenticatedEnabled="1" />

      <Invoke Class="FHIRAgentStudio.Seed.SeedLoader" Method="Run" />
    </Module>
  </Document>
</Export>
```

Notes:

- Use appropriate authentication for production, but for a contest demo a frictionless local unauthenticated demo may be acceptable if clearly labelled.
- If a single CSP application serves both SPA and API, document the routing clearly.
- If setup requires a namespace, create it in `iris.script` or installer code.

## 6.3 IPM test commands

Add commands like these to the README:

```bash
docker compose exec iris iris session iris -U IRISAPP
```

Then in the IRIS session:

```objectscript
zpm
load /irisdev/app -v
fhir-agent-studio package -v
```

A clean `load` and `package -v` result should be part of the release checklist.

---

## 7. README structure for maximum judge clarity

The README should be treated as the primary user interface for the judges before the app runs.

Recommended structure:

```markdown
# FHIR Agent Studio

One-sentence tagline.

## Why this project exists
## Contest alignment
## Screenshots or GIF
## Quick start
## Demo credentials / URLs
## Run the three hero demos
## Architecture
## How it maps to HealthConnect concepts
## Repository layout
## Development workflow
## IPM / module.xml packaging
## REST API summary
## Demo data
## Optional LLM configuration
## Troubleshooting
## Submission notes / bonus tags
## License
```

## 7.1 README quick-start block

Put this near the top:

```bash
git clone https://github.com/<org>/fhir-agent-studio.git
cd fhir-agent-studio
cp .env.example .env
docker compose up --build
```

Then:

```text
Portal: http://localhost:52773/fhir-agent-studio/
Status: http://localhost:52773/fhir-agent-studio/api/status
```

## 7.2 README demo block

Include explicit click paths:

```text
Demo 1: Abnormal Results Follow-Up
1. Open the portal.
2. Click Templates.
3. Open Abnormal Results Follow-Up Agent.
4. Click Use Template.
5. Click Compile.
6. Click Deploy.
7. Click Run Test.
8. Review Evidence → Recommendation → Draft FHIR Task → Trace.
```

Do the same for:

- Prior Authorization Evidence Agent;
- Natural Language to FHIR Query Agent.

## 7.3 README troubleshooting block

Include fixes for common issues:

| Problem | Fix |
|---|---|
| Port 52773 already in use | Change the host port in `docker-compose.yml` |
| Frontend shows blank page | Run `docker compose logs iris` and confirm SPA build copied into CSP directory |
| Templates missing | Call `/api/admin/seed` or run seed loader from terminal |
| API returns 404 | Confirm `/fhir-agent-studio/api` CSP app dispatch class is installed |
| External LLM fails | Use default `LLM_MODE=mock` |

---

## 8. Development workflow

Recommended developer workflow:

```bash
# Start IRIS backend
docker compose -f docker-compose.dev.yml up iris

# Start Vite frontend for hot reload
cd frontend
npm install
npm run dev
```

The Vite dev server should proxy `/api` calls to IRIS.

Production/judge workflow should remain:

```bash
docker compose up --build
```

The project should not require judges to run the frontend dev server.

---

## 9. Seed data and deterministic demo mode

Seed data must be automatic.

Recommended seed assets:

```text
/seed/templates/*.json
/seed/demo-data/fhir-resources.json
/seed/demo-data/knowledge-documents.json
```

The IRIS seed loader should import these into persistent classes.

## 9.1 Required seed outcomes

After startup, the following should already exist:

- 12 workflow templates;
- demo patient for abnormal results follow-up;
- demo patient for prior authorization;
- cohort data for NL-to-FHIR query;
- payer policy knowledge snippets;
- clinical follow-up guidance snippets;
- at least one compiled/deployable flow or a one-click compile path.

## 9.2 Deterministic AI mode

Default:

```text
LLM_MODE=mock
```

Optional:

```text
LLM_MODE=external
LLM_ENDPOINT=
LLM_API_KEY=
LLM_MODEL=
```

Judges should not need to configure an external model to see the demo.

---

## 10. Testing and smoke checks

Include a smoke test that a judge or maintainer can run.

Recommended:

```bash
./test/smoke-test.sh
```

The smoke test should verify:

1. IRIS container is running;
2. status endpoint returns `ok`;
3. templates endpoint returns 12 templates;
4. compile endpoint works for `results-followup`;
5. test-run endpoint returns an `AgentResponse`;
6. trace endpoint returns steps.

Example smoke-test output:

```text
[ok] API status
[ok] templates loaded: 12
[ok] compiled results-followup
[ok] ran results-followup test
[ok] trace has 8 steps
```

---

## 11. CI / quality checks

Recommended, not mandatory:

- GitHub Actions workflow that runs the smoke test;
- frontend lint/build;
- ObjectScript compile during Docker build;
- IPM `load` / package validation;
- objectscriptQuality configuration if practical.

Open Exchange documents automated checks using objectscriptQuality for VSCode and manual moderation. Passing quality checks is not a substitute for a working demo, but it improves credibility.

Recommended `.github/workflows/ci.yml` jobs:

```text
frontend-build
iris-docker-build
smoke-test
```

---

## 12. Release and versioning

Use semantic versioning.

Recommended before submission:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Make sure the same version appears in:

- `module.xml` `<Version>`;
- GitHub release/tag;
- README badge or release notes;
- Open Exchange release form.

Open Exchange release forms ask for a release number and release notes. Keep release notes concise and demo-focused.

---

## 13. Video demo guidance

A video is not just marketing; it reduces judging friction.

Recommended length: 4–7 minutes.

Suggested structure:

```text
0:00 What this is
0:30 Docker startup and URL
1:00 Template gallery
1:45 Compile a workflow
2:30 Run Results Follow-Up demo
3:30 Show HealthConnect mapping and trace
4:15 Run Prior Auth demo
5:00 Run NL-to-FHIR Query demo
5:45 Show import/export and generated artefacts
6:30 Closing: contest alignment and why it is reusable
```

Show the one-command startup either live or briefly at the beginning.

---

## 14. Open Exchange public page checklist

Before clicking **Send for Approval**, verify:

- repository is public;
- README renders correctly on GitHub/GitLab;
- quick-start commands work from a fresh clone;
- screenshots or GIFs are visible;
- demo video URL works;
- license link works;
- tags reflect the technologies used;
- category is appropriate;
- InterSystems products are selected correctly;
- IPM publish checkbox is only selected if IPM packaging was tested;
- release version matches `module.xml`.

---

## 15. Contest-specific bonus positioning

For the AI Agents for FHIR contest, the Open Exchange contest page lists bonus areas including FHIR, Digital Health Interoperability, Vector Search, LLM AI/LangChain, Embedded Python, Docker, IPM, Demo, Community Idea Implementation, FHIR bug, Interoperability bug, First Article, Second Article, Video, and First Time.

For this project, aim to clearly demonstrate:

| Bonus area | How to make it visible |
|---|---|
| FHIR | Use FHIR resource names, demo resources, FHIR-style write-backs |
| Digital Health Interoperability | Map flows to HealthConnect-style Business Service/Process/Operation concepts |
| Vector Search | Use `VectorSearchOperation` and knowledge snippets; use true IRIS Vector Search if feasible |
| LLM AI | Include `AIHubOperation`; default mock mode plus optional external model mode |
| Docker | One-command Docker Compose startup |
| IPM | Working `module.xml`, documented `zpm load`, optional publish checkbox |
| Demo | Video demo and seeded test flows |
| Video | YouTube link on Open Exchange |

Do not claim a bonus unless the app visibly demonstrates it.

---

## 16. Recommended final repository checklist

Use this before submission.

### Build and run

- [ ] Fresh clone works.
- [ ] `docker compose up --build` works.
- [ ] Portal opens at documented URL.
- [ ] API status endpoint works.
- [ ] Seed data loads automatically.
- [ ] No external key required for demo.

### App functionality

- [ ] 12 templates visible.
- [ ] Three hero flows run end-to-end.
- [ ] Compile artefacts are visible.
- [ ] HealthConnect mapping visible.
- [ ] Trace timeline visible.
- [ ] Import/export works.

### Packaging

- [ ] `module.xml` exists at repo root.
- [ ] `module.xml` version uses semver.
- [ ] `zpm load` tested.
- [ ] REST CSP application configured.
- [ ] SPA/static CSP application configured.
- [ ] `LICENSE` exists.

### Documentation

- [ ] README in English.
- [ ] Installation steps included.
- [ ] Demo steps included.
- [ ] Architecture documented.
- [ ] Troubleshooting documented.
- [ ] Video demo linked.

### Open Exchange

- [ ] Public GitHub/GitLab repo linked.
- [ ] Open Exchange app created.
- [ ] App sent for approval.
- [ ] Contest application submitted after app is published.
- [ ] Release/version details are consistent.

---

## 17. Recommended README snippet

You can copy this into the project README and edit the repository URL.

```markdown
## Quick start

Prerequisites: Git and Docker Desktop.

```bash
git clone https://github.com/<org>/fhir-agent-studio.git
cd fhir-agent-studio
cp .env.example .env
docker compose up --build
```

Open the portal:

```text
http://localhost:52773/fhir-agent-studio/
```

Check the backend:

```text
http://localhost:52773/fhir-agent-studio/api/status
```

The demo uses deterministic mock AI by default, so no API key is required.
```

---

## 18. Source references

- InterSystems Programming Contest: AI Agents for FHIR — official contest announcement: https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-fhir
- Open Exchange contest page for AI Agents for FHIR: https://openexchange.intersystems.com/contest/46
- Open Exchange contest overview: https://openexchange.intersystems.com/about-contests
- Open Exchange documentation — submit an application: https://docs.openexchange.intersystems.com/apps/submit/
- Open Exchange documentation — applying for a contest: https://docs.openexchange.intersystems.com/contest/apply/
- Open Exchange documentation — publishing IPM applications: https://docs.openexchange.intersystems.com/apps/ipm/
- Open Exchange documentation — app quality checks: https://docs.openexchange.intersystems.com/quality/
- InterSystems objectscript-docker-template: https://github.com/intersystems-community/objectscript-docker-template
- InterSystems objectscript-package-template: https://github.com/intersystems-community/objectscript-package-template
- InterSystems Package Manager: https://github.com/intersystems/ipm
- Developer Community article — describing `module.xml`: https://community.intersystems.com/post/describing-module-xml-objectscript-package-manager
```
