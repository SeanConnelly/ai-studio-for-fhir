<!--
Developer Community article 1 of 2: the announcement / front page of the submission.
Purpose: introduce and SELL the project, show why IRIS is the right platform, and
drive readers to the demo. Voice: first person, confident, plain.
House style: no em-dashes, no competitor comparisons, no author bio or vote-begging.
No mention of the bundled API key. Screenshots are embedded from ../screenshots/
(spaces URL-encoded as %20). Replace [PLACEHOLDER ...] links. Suggested tags: AI,
FHIR, Machine Learning, InterSystems IRIS for Health, Contest. ~1,700 words.
-->

# Introducing FHIR Agent Studio: AI agents for FHIR on InterSystems IRIS

AI is going to change healthcare, but only if clinicians can trust it and developers
can build it without reinventing the plumbing every time. FHIR Agent Studio is my
attempt at both: a place to build AI agents for FHIR workflows from reusable building
blocks, run them on a real InterSystems IRIS for Health backend, and inspect exactly
what each one did at every step.

It is my entry in the InterSystems **AI Agents for FHIR** contest, and it ships with
**twelve working agents** over a synthetic FHIR repository of around 1,000 patients and
20,000 resources. The goal was a studio rather than a single demo: somewhere you can
design, run, and inspect many agents, and then build your own. Everything runs on one
container, with one command, and no API key.

> Clone the [repo](https://github.com/SeanConnelly/ai-studio-for-fhir/) and run
> `docker compose up --build`. Then open the guided demo and run any of the twelve.
> Every step is yours to inspect.

## Start with the guided demo

If you only do one thing, open the **guided demo**. It is a tour of all twelve agents,
each with a plain-language description, a "Try it" link straight to the right screen,
and a note on what to watch for. You do not need to know anything about the project to
explore the whole thing in a few minutes.

![The guided demo: all twelve agents, each with a description and a Try it link](../screenshots/The%20Demo%20Page.png)

## What an agent is

Every agent is a small clinical workflow described as data, a pipeline you can read
from left to right:

```
Trigger → Evidence (FHIR · SQL · Vector Search) → Agent (LLM) → Action (draft FHIR) → Trace
```

The studio compiles that definition into deployable runtime artifacts and runs it on a
real IRIS interoperability production. The same twelve agents then show up in three
places, all on the same backend. Here is what each one looks like.

## Build agents in the Studio

The Studio is the developer portal. Every agent lives in one gallery: open one to run
it, inspect how it was compiled, or edit it. Creating a new agent starts from a blank
canvas or a ready-made starter, and deploys in a single click.

![The Studio gallery, where every agent can be opened, run, inspected, or edited](../screenshots/FHIR%20Agent%20Studio%20Agents%20Page.png)

Building an agent is the part I am most proud of. Instead of a wall of configuration,
you get the agent as a **pipeline of steps**, in the exact order the runtime executes
them, and you can **test each step on its own** against a real patient before you ever
run the whole thing. Read the FHIR record and see what comes back. Run the vector
search and see what it retrieves. Best of all, you can **preview the exact prompt** the
agent will send to the model, assembled from the evidence above it, before any AI call
is made. When you save, the studio compiles seven runtime artifacts and deploys them.

![The Build view: an agent as a pipeline of steps you can test one at a time, with a preview of the exact prompt](../screenshots/FHIR%20Agent%20Studio%20Build%20View%20-%20Smart%20Patient%20Summary%20Generator.png)

## Decision support where clinicians work

The same agents appear inside **Cedar Valley Health**, a clinician-facing EHR. They are
not a separate "AI tab" bolted on the side; they surface as decision support in the
places a clinician already looks: a patient's chart, the problem list, the medication
list, and the worklists that flag who needs attention. Anything an agent proposes
arrives as a clear card the clinician can sign or decline. Nothing is written to the
record without a human saying yes.

![Cedar Valley Health: a patient chart with AI decision support woven into the clinician's workflow](../screenshots/Ceder%20Vally%20Health%20Patient%20Records.png)

## The same intelligence, written for patients

The third surface is a patient phone app. It runs the same agents, but speaks plain
language: lab results explained in everyday terms, a personal care plan, local support
services, and a simple symptom check. It is a reminder that an agent's output is just
structured data, so the same result can be shown to a specialist one way and to a
patient another.

![The patient portal: results, care plan, and support in plain language on a phone](../screenshots/Patient%20Portal%20Mobile%20Application.png)

## A few of the twelve agents

The twelve cover a wide spread of real clinical and administrative work. A few
examples:

- An **Imaging & Results Follow-Up Tracker** finds an abnormal result that nobody
  booked a follow-up for, works out what it means, and drafts the order to close the
  loop. (A missed follow-up is one of the most common ways patients quietly fall
  through the cracks.)
- A **Medication Safety** agent spots a patient on metformin whose kidney function has
  fallen to a level where the drug is no longer safe, and drafts a review for the
  prescriber.
- A **Natural Language to FHIR Query** agent turns *"show me diabetics with an HbA1c
  over 9"* into a real, read-only SQL query you can read and run.
- A **Prior Authorization** copilot matches a patient against payer policy using vector
  search and lists the evidence that is still missing.

The other agents cover smart patient summaries, gaps in care, care planning, social
care referrals, clinical trial matching, readmission risk, and conversational triage.

## Every agent shows its work

Transparency is built in, not bolted on, because a clinical agent that can explain
itself is one a clinician can actually use. For every run you can open:

- **The transcript**: the exact prompt the agent assembled and the raw model response.
  The JSON the model returned *is* the result you see on screen.
- **The Visual Trace**: IRIS's own Management Portal replays the run as a flow of
  messages, including the FHIR read, the SQL query, the vector search, the LLM call
  (request and response), and the drafted FHIR action.
- **The response history**: every model response is recorded with its prompt,
  timestamp, and a hash, and you can browse the lot.

And when an agent does not have the evidence to answer, it says so and falls back to a
clearly labelled path that is never presented as AI. Every agent is **grounded** in
retrieved evidence ("use only what you were given, never invent a value"), every output
obeys a **strict contract**, and every action it proposes is a **draft a human
approves**. I go deeper on the engineering behind that in the next article.

## Why InterSystems IRIS is the right platform for AI Agents

Building reliable AI agents usually means stitching together a pile of separate
services: a database, a vector store, a workflow engine, an integration layer, a FHIR
server. IRIS for Health gives you all of that in **one platform**, and this project
leans on every part of it:

- **An orchestration layer.** The runtime is a real IRIS **Interoperability
  Production**. Each agent run is an actual Business Service → Business Process →
  Business Operations message flow, the same engine hospitals already use to move data
  between systems, here pointed at orchestrating and auditing AI agents. That is where
  the Visual Trace comes from, for free.
- **One database, with native vector search.** The same database holds the application
  data and the embeddings. Retrieval is real native `VECTOR_DOT_PRODUCT` over a vector
  column, with no separate vector store to run and no data to keep in sync, so each
  patient pulls back the guidance, policies, and trials that fit them.
- **A real FHIR server.** Clinical data lives in the IRIS for Health FHIR R4
  repository, queried through the FHIR SQL projections and written back as draft FHIR
  resources, not a JSON file dressed up as FHIR.
- **Packaging and deployment.** It installs as a package (IPM and `module.xml`) and
  runs from one Docker command.

Because it is a single platform, one agent run can read FHIR, run a SQL query, do a
vector search, call an LLM, and draft a FHIR resource, all as one traceable flow with
nothing glued together behind the scenes. That coherence is the whole reason the
project stays small and inspectable.

## Run it in five minutes

```bash
git clone https://github.com/SeanConnelly/ai-studio-for-fhir
cd fhir-agent-studio
docker compose up --build
```

One command builds the React apps, creates the IRIS namespace and a FHIR endpoint,
loads and compiles the backend, generates the synthetic patient population and the
vector embeddings, and starts the interoperability production. When it settles, open
the **guided demo** at `http://localhost:42773/clinical/#/demo`.

## A prototype, not a product

I want to be straight about what this is. FHIR Agent Studio is demoware. I built it the
way you build a prototype: quickly, to try out a set of ideas and see whether they hold
together. This first version is far from production ready, in both code quality and
design, and the patient data is synthetic for a reason. It is a demo, not a product.

What it does do well is make a case: that InterSystems IRIS is an excellent platform
for building an agent studio. Having the FHIR repository, the vector search, the
interoperability runtime, and the audit trail all in one place is what let an ambitious
idea become something I could actually stand up and show in the time a contest allows.

So I see this as a starting point rather than a finished thing. The concept is worth
taking further, and with more time it could grow into a comprehensive, production-grade
design and implementation. For now, it is the most convincing way I could show the idea
working from end to end.

## What's next

The next artical to be posted will take a deep dive into how the solution works end to end.


