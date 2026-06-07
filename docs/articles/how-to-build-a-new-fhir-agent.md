<!--
Developer Community article 2 of 2: a step by step build tutorial.
Purpose: show how easy and real it is to build a new agent in the studio, using
the 13th agent (Metformin Renal Safety Monitor) as the worked example.
Voice: simple, instructional, junior-developer-friendly. No jargon left unexplained.
House style: no em-dashes, no author bio. Add the screenshots described inline
(📷 markers). Replace [PLACEHOLDER ...]. Suggested tags: AI, FHIR, Machine Learning,
InterSystems IRIS for Health, Tutorial. ~2,200 words.
-->

# How to build a new FHIR Agent using FHIR Agent Studio

In my [first article][a1] I introduced **FHIR Agent Studio**, twelve AI agents for
FHIR running on a single InterSystems IRIS for Health container. It ships with twelve,
but the point of a studio is that you can build your own. This article shows you how,
step by step.

We'll build a real, useful agent together: a **Metformin Renal Safety Monitor**. You
don't need to write any code, and you don't need an API key. The studio comes with a
prebuilt starting point for this exact agent, so you can follow along click for click.

> **You'll need the studio running.** Either open the [live demo][demo], or clone the
> [repo][repo] and run `docker compose up --build`, then open
> `http://localhost:42773/fhir-agent-studio/`.

## The problem we're solving

Metformin is one of the most common diabetes medicines. It's cleared by the kidneys,
so if a patient's kidney function drops too low, metformin can build up and cause a
dangerous complication. The accepted guidance is simple: don't use metformin when the
patient's eGFR (a kidney-function score) falls below 30.

In a busy hospital, that's an easy thing to miss. The prescription was fine when it was
written, and nobody rechecks it every time a new blood test comes back. So we'll build
an agent that does the checking: it looks at a patient's active medicines, looks at
their latest kidney function, compares them against the guidance, and if there is a
problem, drafts a note for the prescriber to review.

## A quick mental model

In FHIR Agent Studio, an agent is a **pipeline**, a short list of steps that run in
order:

1. **Capture inputs**: which patient are we looking at?
2. **Gather evidence**: read the patient's record, run queries, search clinical
   guidance. (An agent can have several evidence steps.)
3. **Reason with AI**: send all that evidence to a language model with clear
   instructions, and get back a structured result.
4. **Propose an action**: optionally, draft a FHIR resource (such as a task for a
   clinician) for a human to approve.

The studio's **Build** screen shows exactly these steps, in order, and lets you **test
each one on its own** before you run the whole thing. That's the part that makes this
feel less like magic and more like engineering.

---

## Step 1: Create the agent from a starter

Open the studio and go to the **Agents** page. Click **New Agent** (top right).

A dialog appears with a few starting points. Pick **Metformin renal safety**. The name
field fills in with *Metformin Renal Safety Monitor*. Keep it, and click **Create &
deploy**.

That one click does a lot: the studio validates the agent, compiles it into runtime
artifacts, and deploys it to the live system. A few seconds later you land on the
agent's **Build** tab, ready to edit.

> 📷 *[Screenshot: the "New Agent" dialog. The list of starters is visible with
> "Metformin renal safety" selected, and the name field shows "Metformin Renal Safety
> Monitor". The "Create & deploy" button is highlighted.]*

> **What's a "starter"?** Just a prebuilt agent definition you can use as a starting
> point, so you don't begin from a blank page. You can also start from **Blank canvas**
> and build everything yourself.

## Step 2: Get your bearings on the Build tab

The **Build** tab shows your agent as a numbered list of steps, the pipeline from the
mental model above. For this agent you'll see:

1. **Capture inputs**: the patient to run on.
2. **Read the FHIR record**: pulls the patient's data from the FHIR repository.
3. **Semantic search**: searches a library of clinical guidance.
4. **Kidney function (eGFR) results**: a small query for this patient's eGFR readings.
5. **Reason with AI**: sends the evidence to the model.
6. **Propose draft action**: drafts a task if needed.

At the top you'll also see a **Test patient** selector. It's already set to our example
patient, **Alexander Gresham**. Every "Test step" button on this screen runs against
this patient, so you can see real data as you build.

> 📷 *[Screenshot: the Build tab, showing the numbered step rail (steps 1 to 6) and the
> "Test patient" selector at the top set to Alexander Gresham.]*

## Step 3: Test the first evidence step (read the record)

Click **Read the FHIR record** to expand it, then click **Test step**.

The studio runs just this one step and shows you what came back: about ten real
resources from the patient's chart, grouped by type. Notice two things in particular.
The patient's **conditions** include type 2 diabetes and chronic kidney disease, and
the **medications** include **metformin**, marked active.

This is real data, read live from the FHIR repository, not a fixed example. If you
switched the test patient at the top, you'd get that patient's record instead.

> 📷 *[Screenshot: the "Read the FHIR record" step expanded, with the test result
> showing resource types and counts: Conditions, MedicationRequests (metformin
> visible), and so on.]*

## Step 4: Test the guidance search

Click **Semantic search** to expand it, then **Test step**.

This step uses **vector search**, a way of finding text by *meaning* rather than exact
keywords. It searches a library of clinical guidance for whatever is most relevant to
*this* patient, and returns the top few matches with a relevance score.

Among the results you'll see the rule we care about: **"Metformin and renal function:
contraindicated when the estimated GFR is below 30."** You may also notice guidance
about ACE-inhibitor medicines appear, because the search is built from the patient's
whole profile and he's also on one of those. That's the point of semantic search: it
surfaces what's relevant to the individual.

> 📷 *[Screenshot: the "Semantic search" step expanded, showing the ranked guidance
> chunks with scores, including the "Metformin and renal function… below 30" entry.]*

## Step 5: Test the kidney function query

Click **Kidney function (eGFR) results** to expand it, then **Test step**.

This step is a small, read-only database query. Inside it you can see the SQL, with a
placeholder, `{{patientRef}}`, that the studio fills in with the current patient when
it runs. (Read-only means it can only *read* data, never change it, and the studio
checks this for you.)

The result is a single row: **eGFR 22**.

Stop and look at what you now know, before the AI has done anything: the guidance says
metformin shouldn't be used below 30, and this patient's number is 22. The agent has
the collision in front of it.

> 📷 *[Screenshot: the "Kidney function (eGFR) results" step expanded, showing the
> read-only SQL with the `{{patientRef}}` placeholder and a one-row result: eGFR 22.]*

## Step 6: Look at the reasoning step, and preview the prompt

Click **Reason with AI** to expand it. This is where the language model comes in. You
can see three things you'd normally never get to see:

- the **role** the model is given ("clinical pharmacist"),
- the **instruction** telling it what to do, and
- the **output contract**, the exact shape of the answer the model must return.

Now click **Preview prompt**. The studio gathers the evidence from the steps above and
shows you the **exact text** that will be sent to the model (the instructions and the
patient's evidence) without actually calling the model yet.

This is worth pausing on. The model isn't free to wander off and invent things: it's
given a specific job, a specific set of evidence, and a specific shape to answer in. If
the evidence doesn't support a conclusion, it can't manufacture one.

> 📷 *[Screenshot: the "Reason with AI" step expanded, with the "Preview prompt" output
> showing the system message (role, instruction, and contract) and the user message
> (the gathered evidence).]*

## Step 7: The draft action

Click **Propose draft action** to expand it. Here the agent is set up to draft a FHIR
**Task** (a note for the prescriber) when it finds a problem.

The important word is **draft**. The agent never changes the patient's record on its
own. Anything it proposes goes to a human to approve or decline. That's a hard rule
across the whole studio.

## Step 8: Save, deploy, and run it

You've tested every step. Now run the whole thing.

Click **Save & deploy** (this compiles your agent and deploys it to the live system),
then go to the **Run** tab and click **Run agent**.

A few seconds later you get a result:

- a status of **needs review**,
- a clear finding that **metformin is contraindicated at an eGFR of 22**, and that the
  patient's other medicine should be reviewed too,
- a drafted **urgent Task** for the prescriber, with **Sign** and **Decline** buttons.

It ran instantly, with no setup and no API key, because the studio ships a real,
pre-generated model response for this starter. If you change the agent and run it
again, it will use a live model instead (you can add your own key under **Admin**). If
there is no key, it tells you plainly that the result is not from AI.

> 📷 *[Screenshot: the "Run" tab result, showing the "needs review" status, the
> metformin finding, and the drafted urgent Task card with Sign / Decline buttons.]*

## Step 9: See exactly how it worked

Two places let you check the agent's working.

On the Run result, expand **Under the hood**. You'll see the exact prompt that was
sent, the **raw response** the model returned (which is what became your result), the
evidence that was gathered, and a trace of the run. There's also a link to IRIS's own
**Visual Trace**, which shows the same run as a flow of messages inside the
interoperability engine.

On the **Inspect** tab, you'll see the seven artifacts the studio compiled from your
agent (the recipe, the prompt, the output contract, the FHIR action template, and so
on), and a table mapping each part of your agent to the real IRIS component that runs
it.

> 📷 *[Screenshot: the "Under the hood" panel showing the prompt, the raw model
> response, and the trace steps.]*

## Step 10: Make it your own

Everything here is editable. Back on the **Build** tab, try:

- rewriting the **instruction** on the Reason step,
- adding another evidence step, including your **own** read-only SQL query, which you
  can test as you type it,
- swapping the **output contract** for a different shape.

Each time, click **Save & deploy** and run it again. Because your edits change the
prompt, the studio will call a live model (add your key under **Admin**). If there
isn't one, it tells you honestly that the result is not from AI.

## That's it

In a few minutes, with no code, you built a real clinical AI agent: it reads a live
FHIR record, searches clinical guidance with vector search, runs a read-only query,
reasons over all of it with a language model against a strict contract, and drafts an
action for a human to approve. And you watched and tested every step along the way.

The same pipeline powers all twelve built-in agents. Nothing about the one you just
built is special-cased: it went through the same compiler, the same interoperability
runtime, and the same safety rules.

Try it yourself: [live demo][demo], [repo][repo], or find it on [Open Exchange][oex].

[a1]: # "PLACEHOLDER: link to article 1"
[demo]: # "PLACEHOLDER: live demo URL"
[repo]: # "PLACEHOLDER: GitHub repo URL"
[oex]: # "PLACEHOLDER: Open Exchange listing URL"
