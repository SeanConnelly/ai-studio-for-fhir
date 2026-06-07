/// HealthConnect-style Business Operation: the agent reasoning step.
///
/// For the three hero recipes this is a TRUE agent: the gathered evidence (real
/// FHIR / SQL / vector RAG) is combined with the recipe's base prompt into a
/// single completion request, sent to a real LLM, and the LLM's JSON response
/// *is* the result - including the draft FHIR action it proposes and (for
/// NL->FHIR) the query it writes, which we then validate read-only and execute
/// for real. Nothing user-facing is fabricated in code.
///
/// Resolution is three-tier (so the demo needs no key and stays reproducible):
///  1. cache hit  -> the bundled real LLM completion (source "cached")
///  2. live key   -> a real LLM call, then cached (source "live (model)")
///  3. neither    -> a deterministic, evidence-grounded scaffold (source
///                  "deterministic") - a safety net, never presented as AI.
///
/// Every run records the exact base prompt, the combined completion request,
/// and the raw LLM response into r.aiTrace, surfaced in "Under the hood".
///
/// ctx carries: recipeId, patientRef, context (request context), def (parsed
/// flow definition), and any of fhir / sql / vector evidence objects.
Class FAST.Runtime.AIHubOperation [ Abstract ]
{

Parameter PROMPTVERSION = "2";

/// Dataset reference date - the synthetic population is a frozen point-in-time
/// snapshot, so relative windows ("last 6 months") are evaluated as-of this date
/// (not the wall clock) to keep cohorts and the NL->FHIR cache key reproducible.
ClassMethod AnchorDate() As %String
{
    return $parameter("FAST.Seed.SyntheticData", "ANCHORDATE")
}

ClassMethod Generate(ctx As %DynamicObject) As %DynamicObject
{
    // All twelve agents are LLM-authored: real evidence (FHIR / SQL / vector) is
    // combined with the agent's prompt into one completion request and the LLM's
    // JSON response IS the result. The deterministic scaffold (Build) survives only
    // as the no-key / no-cache fallback inside RunAgent.
    return ..RunAgent(ctx)
}

ClassMethod IsHero(recipeId As %String) As %Boolean
{
    return ((recipeId = "results-followup") || (recipeId = "prior-auth") || (recipeId = "nl-to-fhir-query"))
}

ClassMethod Mode() As %String
{
    return $select($get(^FAST("llm", "mode")) = "external": "external", 1: "mock")
}

/// ---- The real agent: prompt -> LLM -> result ----
/// Build the completion request from the base prompt + gathered evidence,
/// resolve it (cache -> live -> deterministic), finalize the structured result,
/// and attach the full transcript as diagnostics.
ClassMethod RunAgent(ctx As %DynamicObject) As %DynamicObject
{
    set prompt = ..Prompt(ctx)
    set raw = "", source = ""
    set out = ..Resolve(ctx, prompt, .raw, .source, .transport)
    if $isobject(out) {
        set r = out
    } else {
        // No cache and no key: fall back to the deterministic scaffold.
        set r = ..Build(ctx)
        set source = "deterministic"
    }
    do ..Finalize(.r, ctx, source)

    set at = {}
    set at.basePrompt = prompt.system
    set at.completionRequest = prompt.user
    set at.rawResponse = raw
    set at.source = source
    set at.model = $get(^FAST("llm", "model"), "")
    // the egress leg (LLMService message): url, http status, transport note
    if $isobject($get(transport)) do at.%Set("transport", transport)
    set r.aiTrace = at
    return r
}

/// Compose the base (system) prompt and the combined completion request (user)
/// for a recipe: the agent's role + instruction + output contract, plus the
/// real gathered evidence rendered in clinician-facing language (no internal
/// labels like "SQL" or "vector" leak into the prompt).
ClassMethod Prompt(ctx As %DynamicObject) As %DynamicObject
{
    set def = ctx.%Get("def")
    set role = $select($isobject(def) && $isobject(def.agent): def.agent.role, 1: "clinical assistant")
    set instruction = $select($isobject(def) && $isobject(def.agent): def.agent.instruction, 1: "")
    set recipeId = ctx.recipeId
    set nl = $char(10)

    set sys = "You are a " _ role _ " working inside a clinical system. " _ instruction _ nl
            _ "You are given verified evidence retrieved from a real FHIR repository and clinical knowledge base. "
            _ "Use ONLY this evidence - never invent patients, values, codes, medications, or resources that are not present. " _ nl
            _ ..OutputContract(recipeId, ctx) _ nl
            _ "Respond with ONLY a single JSON object - no markdown fences, no commentary. "
            _ $select(recipeId = "nl-to-fhir-query": "", 1: "Write all text for the end user; do not mention SQL, databases, vectors, embeddings, or any internal system mechanics. ")
            _ "Be concise and clinically careful."

    set user = ..CompletionRequest(ctx)
    set p = {}
    set p.system = sys
    set p.user = user
    return p
}

/// The per-recipe JSON output contract the LLM must satisfy.
ClassMethod OutputContract(recipeId As %String, ctx As %DynamicObject) As %String
{
    set nl = $char(10)
    set pr = ctx.patientRef
    if recipeId = "results-followup" {
        return "Return JSON with keys: " _ nl
            _ "  status (""needs_review"" if ANY abnormal result lacks follow-up, else ""completed"")," _ nl
            _ "  summary (1-2 sentence summary for the responsible clinician)," _ nl
            _ "  closedLoopSummary (one sentence: ""X of Y abnormal results have a documented follow-up plan"" plus what remains open)," _ nl
            _ "  trackedResults (array, one entry per ABNORMAL result - imaging reports with concerning conclusions AND flagged lab values - each "
            _ "{result (the test/report name), date, finding (the abnormal finding in one phrase), "
            _ "followUpStatus: ""overdue""|""pending""|""closed"", followUp (the documented Task/ServiceRequest/Appointment that addresses it, or ""None documented""), action (what should happen next, with a timeframe)}. "
            _ "Judge status against today's date and any recommended window in the report: closed = follow-up completed; pending = follow-up documented but not yet done; overdue = no follow-up documented, or the recommended window has passed. "
            _ "Group repeated measurements of the SAME test into ONE entry citing the latest value and the trend. "
            _ "IMAGING REPORTS WITH CONCERNING CONCLUSIONS ARE THE HIGHEST PRIORITY - never omit one, and list it FIRST. "
            _ "ALWAYS include results whose loops are CLOSED as well, citing the completed follow-up - proving closure is the point of this tracker)," _ nl
            _ "  patientOutreach (a warm SMS-style message to the patient about the MOST URGENT open result - honest that it needs checking soon, never alarming, with a simple call to action like replying or phoning the office; null if every loop is closed)," _ nl
            _ "  clinicianNote (a crisp internal note to the responsible clinician: the patient, the open finding with its date, and the specific order you recommend creating today; null if every loop is closed)," _ nl
            _ "  findings (array of short clinical statements)," _ nl
            _ "  recommendations (array of {priority: ""urgent""|""high""|""routine"", owner, text})," _ nl
            _ "  draftAction: a FHIR R4 Task or ServiceRequest that closes the MOST URGENT open loop, OR null if every result has documented follow-up. "
            _ "Task shape: {""resourceType"":""Task"",""status"":""draft"",""intent"":""order"",""priority"":""routine""|""urgent"",""description"":""..."",""for"":{""reference"":""" _ pr _ """}}; "
            _ "ServiceRequest shape: {""resourceType"":""ServiceRequest"",""status"":""draft"",""intent"":""order"",""code"":{""text"":""...""},""subject"":{""reference"":""" _ pr _ """}}."
    }
    if recipeId = "prior-auth" {
        return "Return JSON with keys: " _ nl
            _ "  status (""needs_review"")," _ nl
            _ "  summary (1-2 sentences)," _ nl
            _ "  requestedService (string)," _ nl
            _ "  policyCriteriaMatched (array of strings - payer criteria the record satisfies, each citing the supporting value)," _ nl
            _ "  missingEvidenceChecklist (array of strings - required documentation not found in the record)," _ nl
            _ "  findings (array of short strings)," _ nl
            _ "  recommendations (array of {priority, owner, text})," _ nl
            _ "  draftJustification (string - a clinical justification paragraph; explicitly NOT a coverage decision)," _ nl
            _ "  draftAction: {""resourceType"":""DocumentReference"",""status"":""current"",""type"":{""text"":""Prior Authorization Evidence Packet""},""subject"":{""reference"":""" _ pr _ """},""description"":""...""}."
    }
    if recipeId = "nl-to-fhir-query" {
        return "Return JSON with keys: " _ nl
            _ "  status (""completed"")," _ nl
            _ "  interpretedIntent (one sentence restating the question precisely)," _ nl
            _ "  resources (array of the FHIR resource types the question touches, e.g. [""Patient"",""Condition"",""Observation""])," _ nl
            _ "  filters (array of short human-readable strings - the constraints you extracted from the question, each with its concrete value, "
            _ "e.g. ""HbA1c (LOINC 4548-4) above 9 %"" or ""within the last 6 months (on or after 2025-11-23)"")," _ nl
            _ "  confidence (integer 0-100 - how confident you are that the generated query answers exactly what was asked)," _ nl
            _ "  generatedQueryType (""SQL"")," _ nl
            _ "  generatedQuery (a single read-only SQL SELECT against the schema below - no writes, no multiple statements)," _ nl
            _ "  queryExplanation (one or two sentences a non-technical reader can follow)," _ nl
            _ "  summary (1 sentence describing what the query returns)," _ nl
            _ "  findings (array of short strings)," _ nl
            _ "  limitations (array of strings)," _ nl
            _ "  clarification (null normally. If the question does NOT name at least one specific, measurable concept from the schema "
            _ "(a named condition, medication, test/observation, or visit type) - e.g. ""the sick patients"" or ""who is getting worse"" - then DO NOT guess: "
            _ "set clarification to ONE specific clarifying question offering 2-3 concrete interpretations the user could pick, set generatedQuery to """", set confidence below 40, and leave resources/filters as your best guess)."
    }
    if recipeId = "smart-patient-summary" {
        return "Return JSON with keys: " _ nl
            _ "  status (""completed"")," _ nl
            _ "  summary (a COMPREHENSIVE clinical narrative of 2-3 short paragraphs, written like an experienced clinician's handover note - flowing prose, NOT bullet points. " _ nl
            _ "    Paragraph 1: open with the patient's title, name, age and sex, then their active past medical history (the problem list, most significant first). " _ nl
            _ "    Paragraph 2: describe how the chronic conditions are controlled, citing SPECIFIC recent values with units (e.g. blood pressure, HbA1c, eGFR, LDL, weight/BMI) and the current medications with their doses; note relevant hospitalisations/encounters and any drug allergies. " _ nl
            _ "    Paragraph 3: summarise recent events and any OUTSTANDING items, overdue screening or care gaps, and active alerts; if nothing is outstanding say so. " _ nl
            _ "    Use ONLY the supplied evidence - cite real values and dates, never invent. Distinguish active from resolved, current from discontinued, abnormal from normal. Tailor emphasis to the requesting role)," _ nl
            _ "  sections (array of {heading, items: array of strings} giving concise supporting detail for Problems, Medications, Allergies, Recent results, and Care gaps as supported by the evidence)," _ nl
            _ "  findings (array of the most salient short statements)," _ nl
            _ "  recommendations (array of {priority, owner, text})."
    }
    if recipeId = "medication-safety" {
        return "Return JSON with keys: " _ nl
            _ "  status (""needs_review"" if any issue is found, else ""completed"")," _ nl
            _ "  summary (1-2 sentences)," _ nl
            _ "  interactions (array of {severity: ""major""|""moderate""|""minor"", drugs: array of strings, issue, recommendation})," _ nl
            _ "  findings (array of short strings)," _ nl
            _ "  recommendations (array of {priority, owner, text})," _ nl
            _ "  draftAction: a FHIR R4 DetectedIssue (status ""preliminary"", with a detail describing the issue) referencing the patient, OR null if no issue."
    }
    if recipeId = "gaps-in-care" {
        return "Return JSON with keys: " _ nl
            _ "  status (""needs_review"" if gaps exist, else ""completed"")," _ nl
            _ "  summary (1-2 sentences)," _ nl
            _ "  gaps (array of {measure, status: ""open""|""overdue""|""met"", detail, recommendedAction})," _ nl
            _ "  findings (array of short strings)," _ nl
            _ "  recommendations (array of {priority, owner, text})," _ nl
            _ "  draftAction: a FHIR R4 ServiceRequest to close the most important gap, OR null."
    }
    if recipeId = "care-plan-navigator" {
        return "Return JSON with keys: " _ nl
            _ "  status (""needs_review"")," _ nl
            _ "  summary (2-3 sentences: the patient's current status on their care plan - what is going well and what is falling behind)," _ nl
            _ "  nextSteps (array of {action, detail} - the most important things to do next, each with timing/why, ordered by priority)," _ nl
            _ "  goals (array of {goal, status, onTrack: true|false, detail} - detail cites the latest value/date from the record)," _ nl
            _ "  overdueTasks (array of {task, detail} - tasks or activities in the record that are overdue, each noting how overdue; empty array if none)," _ nl
            _ "  suggestedTasks (array of {task, rationale, owner} - NEW tasks you propose to get the plan back on track, each with a short clinical rationale grounded in recent observations or missed appointments)," _ nl
            _ "  patientMessage (a warm, friendly message written TO the patient, PLAIN-LANGUAGE FIRST at about a grade 6 reading level, in 2-4 short paragraphs. "
            _ "Open with a friendly greeting using their first name. In everyday words, gently say how they are doing and what would help most next, framed positively (e.g. ""good news"", ""here is what can help""). "
            _ "Use plain language first and only add a medical term in brackets where it helps (e.g. ""your blood sugar (HbA1c)""). Be encouraging, never alarming or judgemental. "
            _ "End with a simple, low-pressure call to action - invite them to reply YES or call the practice, and reassure them the team is happy to help)."
    }
    if recipeId = "sdoh-referral" {
        return "Return JSON with keys: " _ nl
            _ "  status (""needs_review"")," _ nl
            _ "  summary (1-2 sentences for the link worker: who the patient is and which social needs were identified)," _ nl
            _ "  needs (array of {domain, detail, evidence, source: ""patient-reported""|""from the record""} - every identified social need. "
            _ "detail explains the need in plain words; evidence QUOTES the screening answer (patient-reported) or cites the record item, e.g. missed appointments (from the record). NEVER list a need without evidence)," _ nl
            _ "  referrals (array of {name, bestMatch: true|false, offers, eligibility, contact, reason} - services matched ONLY from the community resource directory supplied in the evidence; "
            _ "NEVER invent, rename or add a service that is not in the directory. Mark exactly ONE referral bestMatch:true - the single most useful service for this patient. "
            _ "offers, eligibility and contact are taken from the directory entry; reason says in one sentence why THIS service fits THIS patient's own reported need)," _ nl
            _ "  recommendations (array of {priority, owner, text} - next steps for the care team, e.g. obtain consent to share details, warm handover, follow-up call in 2 weeks)," _ nl
            _ "  patientMessage (a warm, friendly message written TO the patient, PLAIN-LANGUAGE FIRST at about a grade 6 reading level, in 2-4 short paragraphs. "
            _ "Open with a friendly greeting using their first name. Acknowledge what they told us in the screening without repeating it back clinically - money, food and transport troubles are common and nothing to be embarrassed about. "
            _ "Then share the good news: name the one or two local services that can help and what each one offers, in everyday words. Never sound judgemental or imply fault. "
            _ "End with a simple, low-pressure call to action - invite them to reply YES if they would like us to connect them, or call the practice, and reassure them the team is happy to help)," _ nl
            _ "  draftAction: a FHIR R4 ServiceRequest for the bestMatch referral. "
            _ "Shape: {""resourceType"":""ServiceRequest"",""status"":""draft"",""intent"":""order"",""code"":{""text"":""Referral to <service name>""},""subject"":{""reference"":""" _ pr _ """},""note"":[{""text"":""<one-line reason>""}]}."
    }
    if recipeId = "clinical-trial-matcher" {
        return "Return JSON with keys: " _ nl
            _ "  status (""needs_review"")," _ nl
            _ "  summary (1-2 sentences: the patient in one breath and the single best trial opportunity)," _ nl
            _ "  matches (array, one entry per candidate trial from the registry, ordered best match first, each " _ nl
            _ "    {trial (the trial name), nctId, matchLevel: ""likely""|""maybe""|""unlikely"", confidence (integer 0-100), " _ nl
            _ "     criteriaMet (array of strings, each citing the patient's actual value, e.g. ""Age 26 meets 18-70""), " _ nl
            _ "     criteriaUnmet (array of strings - criteria NOT satisfied, or not confirmable from the record), " _ nl
            _ "     flags (array of strings - cautions that need attention before referral, e.g. a required washout of a current medication; empty if none), " _ nl
            _ "     rationale (1-2 plain sentences a clinician can read at a glance)} " _ nl
            _ "    - assess ONLY trials present in the registry supplied in the evidence; NEVER invent a trial. "
            _ "Check every numeric criterion ARITHMETICALLY against the patient's actual values (age ranges, BMI, lab thresholds) - a hard inclusion failure such as an age outside the stated range makes the trial unlikely regardless of other criteria)," _ nl
            _ "  followUpQuestions (array of {question, why} - SPECIFIC pieces of missing information that would change a match level if known, "
            _ "e.g. ""What is the latest eGFR?"" when a renal criterion cannot be confirmed; empty array if nothing material is missing. "
            _ "If the evidence contains 'Answers from the clinician', treat those answers as verified and do NOT re-ask them)," _ nl
            _ "  findings (array of short strings)," _ nl
            _ "  recommendations (array of {priority, owner, text})," _ nl
            _ "  draftAction: a FHIR R4 Task referring the patient to the research coordinator for the best likely match, OR null if no trial is likely. "
            _ "Shape: {""resourceType"":""Task"",""status"":""draft"",""intent"":""order"",""priority"":""routine"",""description"":""Refer to research coordinator: <trial> (<nctId>)"",""for"":{""reference"":""" _ pr _ """}}."
    }
    if recipeId = "readmission-risk" {
        return "Return JSON with keys: " _ nl
            _ "  status (""needs_review"")," _ nl
            _ "  summary (1-2 sentences for the care coordinator)," _ nl
            _ "  riskScore (integer 0-100 - your overall judgement of 30-day readmission risk from the evidence; be consistent: high band = 70+, moderate = 40-69, low = under 40)," _ nl
            _ "  riskBand (""low""|""moderate""|""high"" - must agree with riskScore)," _ nl
            _ "  thirtyDayEstimate (a rough percentage string like ""~30%"" - clearly an estimate, never false precision)," _ nl
            _ "  riskFactors (array of {factor, level: ""high""|""medium""|""low"", detail} - the classic readmission domains you can ASSESS FROM THE EVIDENCE: "
            _ "recent admissions, high-risk conditions, abnormal results (e.g. BNP, rising creatinine), polypharmacy, follow-up arrangements. "
            _ "detail must cite the actual values/dates from the record, e.g. ""BNP 850 pg/mL (2026-05-16)"" or ""2 inpatient admissions in the last 60 days"". "
            _ "If a domain looks fine, include it with level ""low"" and say why - reassurance is information)," _ nl
            _ "  insights (a 2-3 sentence plain-language narrative tying the factors together - why THIS patient is or is not at risk, and what would most reduce it)," _ nl
            _ "  suggestedTasks (array of {task, rationale} - concrete preventive actions with timeframes, e.g. ""Cardiology follow-up within 7 days"", ""Phone call within 48 hours of discharge"", ""Daily weight monitoring education""; each rationale grounded in a risk factor)," _ nl
            _ "  riskDrivers (array of short strings - the top 2-3 factors, for compact list views)," _ nl
            _ "  recommendations (array of {priority, owner, text})," _ nl
            _ "  draftAction: null (tasks are created through the suggestedTasks flow)."
    }
    if recipeId = "conversational-triage" {
        // Two-phase conversation. Phase 1 (no answers yet): design the guided
        // questions for THIS patient + complaint. Phase 2 (answers supplied):
        // write the clinician handoff from the actual answers.
        if $isobject(ctx.context) && (ctx.context.answers '= "") {
            return "The patient has now ANSWERED the triage questions (see 'answers' in the evidence). Write the clinician handoff. Return JSON with keys: " _ nl
                _ "  status (""needs_review"")," _ nl
                _ "  urgency (""red""|""yellow""|""green"" - red if ANY red-flag answer is positive, yellow when follow-up is needed within about 48 hours, green for routine)," _ nl
                _ "  urgencyLabel (the plain phrase: red = ""Emergency care now"", yellow = ""Clinician follow-up within 48 hours"", green = ""Routine appointment"")," _ nl
                _ "  summary (a one-sentence chief-complaint line including the patient's relevant conditions)," _ nl
                _ "  keyFindings (array of {finding, source} - every finding's source QUOTES the patient answer it came from, e.g. ""Missed metformin -> 'Yes, for 2 days'"")," _ nl
                _ "  mappedObservations (array of short strings - the answers mapped to clinical observations, e.g. ""Symptom: fatigue - onset 5 days"", ""Medication adherence issue: metformin missed 2 days"")," _ nl
                _ "  suggestedTasks (array of {task, rationale} - e.g. medication reconciliation, education review)," _ nl
                _ "  patientMessage (a calm, warm message to the patient about what happens next, grade 6 reading level; for red urgency tell them CLEARLY and kindly to seek emergency care now)," _ nl
                _ "  acuity (""emergent"" for red, ""urgent"" for yellow, ""routine"" for green)," _ nl
                _ "  redFlags (array of any positive red-flag answers; empty if none)," _ nl
                _ "  recommendedNextStep (one sentence)," _ nl
                _ "  findings (array of short strings)," _ nl
                _ "  recommendations (array of {priority, owner, text})," _ nl
                _ "  draftAction: a FHIR R4 ServiceRequest for the recommended visit (e.g. {""resourceType"":""ServiceRequest"",""status"":""draft"",""intent"":""order"",""code"":{""text"":""Clinician review within 48 hours""},""subject"":{""reference"":""" _ pr _ """}}), OR null when urgency is red (the advice is emergency care, not a booking)."
        }
        return "Design a SHORT guided triage conversation for this patient and their complaint. Return JSON with keys: " _ nl
            _ "  status (""in_progress"")," _ nl
            _ "  greeting (1-2 warm sentences addressed to the patient by first name, acknowledging their complaint in their words, ending by saying you'll ask a few quick questions)," _ nl
            _ "  questions (array of EXACTLY 4 objects {id: ""q1""..""q4"", text, options (array of 2 or 3 SHORT answer choices)}. "
            _ "q1 MUST be a yes/no red-flag safety screen directly relevant to the complaint (e.g. severe pain or breathlessness RIGHT NOW). "
            _ "q2 asks duration (3 options). q3 asks about ONE associated symptom tailored to the patient's actual conditions. "
            _ "q4 asks about adherence to one of the patient's ACTUAL named medications. Plain, friendly, grade-6 wording)," _ nl
            _ "  safetyNote (one sentence telling the patient to call 999 if things suddenly get worse)."
    }
    if recipeId = "lab-explainer" {
        return "Return JSON with keys: " _ nl
            _ "  status (""completed"")," _ nl
            _ "  summary (1 sentence for the clinician)," _ nl
            _ "  explained (array - EVERY flagged/abnormal result plus the one or two most reassuring normal ones, each: " _ nl
            _ "    {test (plain name with the medical name in brackets, e.g. ""Blood sugar average (HbA1c)""), value (number), unit, " _ nl
            _ "     flag: ""high""|""low""|""normal""," _ nl
            _ "     normalRange (plain text, e.g. ""usually under 5.7 %""), rangeLow (number), rangeHigh (number - the typical normal range bounds for the bar chart; use 0 for rangeLow when the range is ""under X"")," _ nl
            _ "     meaning (2-3 warm sentences at a grade 6-8 reading level explaining what this result means for THIS patient, grounded in the trusted patient-education extracts; mention the trend when there is one, with the good news first when improving)," _ nl
            _ "     trend ({direction: ""improving""|""stable""|""worsening""|""first-test"", detail (one phrase citing the prior value(s) and dates)} or null when only one reading exists)," _ nl
            _ "     series (array of {date, value} - ALL readings of this test from the evidence, oldest first; empty array if only one)," _ nl
            _ "     whatYouCanDo (array of 1-3 practical, encouraging suggestions)})," _ nl
            _ "  overallSummary (a warm 2-3 sentence wrap-up for the patient: what is improving, what needs attention, and an honest reassurance like ""important but not an emergency"" where true)," _ nl
            _ "  questionsToAsk (array of 3-5 specific questions this patient could ask their doctor, grounded in their actual results)," _ nl
            _ "  whenToWorry (array of plain-language statements about what would warrant contacting the clinic)." _ nl
            _ "Do not give alarming or definitive diagnoses; encourage discussing results with their care team. Never invent a reading that is not in the evidence."
    }
    // Custom agents (built in the Studio): their OutputSchema component IS the
    // contract - the shape an author defines in the UI is the shape the LLM
    // must return. Falls through to the generic contract when the referenced
    // schema doesn't exist or carries no contract.
    set def = ctx.%Get("def")
    if $isobject(def) && $isobject(def.agent) && (def.agent.outputSchema '= "") {
        set schema = ##class(FAST.Data.OutputSchema).SlugIdxOpen(def.agent.outputSchema)
        if $isobject(schema) && (schema.SchemaJSON '= "") {
            return "Return a JSON object that matches this contract exactly (these field names, these types): " _ nl
                _ schema.SchemaJSON _ nl
                _ "In addition ALWAYS include: status (""needs_review"" if any action/concern was found, else ""completed""), "
                _ "summary (1-2 sentences for the clinician), findings (array of short strings), "
                _ "recommendations (array of {priority: ""urgent""|""high""|""routine"", owner, text})."
        }
    }
    return "Return JSON with keys: status, summary, findings (array), recommendations (array of {priority, owner, text})."
}

/// The combined completion request (user message): the real evidence, rendered
/// for the model. For NL->FHIR this is the question + the real SQL schema.
ClassMethod CompletionRequest(ctx As %DynamicObject) As %String
{
    set recipeId = ctx.recipeId
    if recipeId = "results-followup" return ..EvidenceResultsFollowup(ctx)
    if recipeId = "prior-auth" return ..EvidencePriorAuth(ctx)
    if recipeId = "nl-to-fhir-query" return ..SchemaPrompt(ctx)
    if recipeId = "smart-patient-summary" return ..EvidenceSummary(ctx)
    if recipeId = "care-plan-navigator" return "Today's date is " _ ..AnchorDate() _ ". Assess this patient's care plan against it (use due dates to judge what is overdue)." _ $char(10, 10) _ "Evidence:" _ $char(10) _ ..EvidenceText(ctx)
    if recipeId = "sdoh-referral" return ..EvidenceSdoh(ctx)
    if recipeId = "clinical-trial-matcher" return ..EvidenceTrials(ctx)
    if recipeId = "lab-explainer" return ..EvidenceLabExplainer(ctx)
    return "Evidence:" _ $char(10) _ ..EvidenceText(ctx)
}

/// Lab explainer: the patient's results (all readings, so trends are visible),
/// then the trusted patient-education extracts retrieved for THEIR abnormal
/// results - the grounding for every plain-language explanation.
ClassMethod EvidenceLabExplainer(ctx As %DynamicObject) As %String
{
    set nl = $char(10), t = "Today's date is " _ ..AnchorDate() _ "." _ nl _ nl
    if $isobject(ctx.fhir) && $isobject(ctx.fhir.resources) && (ctx.fhir.resources.%Size() > 0) {
        set grp = {}, it = ctx.fhir.resources.%GetIterator()
        while it.%GetNext(.k, .o) {
            set rt = o.resourceType
            if '$isobject(grp.%Get(rt)) do grp.%Set(rt, [])
            do grp.%Get(rt).%Push(o.display)
        }
        set t = t _ "Patient record:" _ nl
        set git = grp.%GetIterator()
        while git.%GetNext(.rt, .arr) {
            set line = "", j = arr.%GetIterator()
            while j.%GetNext(.kk, .d) { set line = line _ $select(line = "": "", 1: "; ") _ d }
            set t = t _ "- " _ rt _ ": " _ line _ nl
        }
        set t = t _ nl
    }
    if $isobject(ctx.sql) {
        set sit = ctx.sql.%GetIterator()
        while sit.%GetNext(.name, .fact) {
            if '$isobject(fact) continue
            set block = ..RenderFact(fact)
            if block '= "" set t = t _ block _ nl
        }
    }
    set edu = ..GuidanceText(ctx, "patient_education")
    if edu '= "" {
        set t = t _ "Trusted patient-education extracts - retrieved for this patient's abnormal results. "
            _ "Ground every explanation, normal range and suggestion in these:" _ nl _ edu
    }
    return t
}

/// Trial matching: the patient record, then the candidate trials retrieved by
/// semantic search over the patient's profile - clearly framed as the ONLY
/// trials the model may assess. Clinician answers to earlier follow-up
/// questions (when supplied) are appended as verified evidence.
ClassMethod EvidenceTrials(ctx As %DynamicObject) As %String
{
    set nl = $char(10), t = "Today's date is " _ ..AnchorDate() _ "." _ nl _ nl
    // the computed profile carries age/sex plus the headline clinical picture -
    // the same text that drove the registry retrieval
    set prof = ##class(FAST.Runtime.Runtime).ProfileQueryText(ctx.patientRef)
    if prof '= "" set t = t _ "Patient profile: " _ prof _ nl _ nl
    if $isobject(ctx.fhir) && $isobject(ctx.fhir.resources) && (ctx.fhir.resources.%Size() > 0) {
        set grp = {}, it = ctx.fhir.resources.%GetIterator()
        while it.%GetNext(.k, .o) {
            set rt = o.resourceType
            if '$isobject(grp.%Get(rt)) do grp.%Set(rt, [])
            do grp.%Get(rt).%Push(o.display)
        }
        set t = t _ "Patient record:" _ nl
        set git = grp.%GetIterator()
        while git.%GetNext(.rt, .arr) {
            set line = "", j = arr.%GetIterator()
            while j.%GetNext(.kk, .d) { set line = line _ $select(line = "": "", 1: "; ") _ d }
            set t = t _ "- " _ rt _ ": " _ line _ nl
        }
        set t = t _ nl
    }
    // structured facts (recent labs)
    if $isobject(ctx.sql) {
        set sit = ctx.sql.%GetIterator()
        while sit.%GetNext(.name, .fact) {
            if '$isobject(fact) continue
            set block = ..RenderFact(fact)
            if block '= "" set t = t _ block _ nl
        }
    }
    set reg = ..GuidanceText(ctx, "trial_criteria")
    if reg '= "" {
        set t = t _ "Candidate trial registry - retrieved by semantic search over the patient's clinical profile. "
            _ "Assess each of these trials and ONLY these trials; never invent or rename one:" _ nl _ reg
    }
    // clinician answers to follow-up questions (the interactive twist)
    if $isobject(ctx.context) && (ctx.context.followUpAnswers '= "") {
        set t = t _ nl _ "Answers from the clinician to earlier follow-up questions (treat as verified evidence): "
            _ ctx.context.followUpAnswers _ nl
    }
    return t
}

/// Social prescribing: the patient record (including the social-needs screening
/// in the patient's own words and any DNA history), then the community resource
/// directory entries retrieved by semantic vector search over those answers -
/// clearly framed as the ONLY services the model may recommend.
ClassMethod EvidenceSdoh(ctx As %DynamicObject) As %String
{
    set nl = $char(10), t = "Today's date is " _ ..AnchorDate() _ "." _ nl _ nl
    // patient record, grouped by resource type (same rendering as EvidenceText)
    if $isobject(ctx.fhir) && $isobject(ctx.fhir.resources) && (ctx.fhir.resources.%Size() > 0) {
        set grp = {}, it = ctx.fhir.resources.%GetIterator()
        while it.%GetNext(.k, .o) {
            set rt = o.resourceType
            if '$isobject(grp.%Get(rt)) do grp.%Set(rt, [])
            do grp.%Get(rt).%Push(o.display)
        }
        set t = t _ "Patient record:" _ nl
        set git = grp.%GetIterator()
        while git.%GetNext(.rt, .arr) {
            set line = "", j = arr.%GetIterator()
            while j.%GetNext(.kk, .d) { set line = line _ $select(line = "": "", 1: "; ") _ d }
            set t = t _ "- " _ rt _ ": " _ line _ nl
        }
        set t = t _ nl
    }
    set dir = ..GuidanceText(ctx, "community_resources")
    if dir '= "" {
        set t = t _ "Community resource directory - retrieved by semantic search over the patient's own screening answers. "
            _ "These are the ONLY services you may recommend; do not invent others:" _ nl _ dir
    }
    return t
}

/// ---- Evidence renderers (clean, clinician-facing, no internal labels) ----

ClassMethod EvidenceResultsFollowup(ctx As %DynamicObject) As %String
{
    set nl = $char(10)
    set t = "Today's date is " _ ..AnchorDate() _ ". Review EVERY abnormal result below (imaging report conclusions and flagged lab values), "
        _ "find whether the record documents a follow-up (Task, ServiceRequest, or Appointment) that addresses each one, and judge overdue/pending/closed against today and any recommended window stated in the report." _ nl _ nl
    // the full record, grouped: reports with conclusions+dates, flagged labs,
    // and the Tasks / ServiceRequests / Appointments that may close each loop
    if $isobject(ctx.fhir) && $isobject(ctx.fhir.resources) && (ctx.fhir.resources.%Size() > 0) {
        set grp = {}, it = ctx.fhir.resources.%GetIterator()
        while it.%GetNext(.k, .o) {
            set rt = o.resourceType
            if '$isobject(grp.%Get(rt)) do grp.%Set(rt, [])
            do grp.%Get(rt).%Push(o.display)
        }
        set t = t _ "Patient record:" _ nl
        set git = grp.%GetIterator()
        while git.%GetNext(.rt, .arr) {
            set line = "", j = arr.%GetIterator()
            while j.%GetNext(.kk, .d) { set line = line _ $select(line = "": "", 1: "; ") _ d }
            set t = t _ "- " _ rt _ ": " _ line _ nl
        }
        set t = t _ nl
    }
    // structured abnormal-result facts (SQL)
    if $isobject(ctx.sql) {
        set sit = ctx.sql.%GetIterator()
        while sit.%GetNext(.name, .fact) {
            if '$isobject(fact) continue
            set block = ..RenderFact(fact)
            if block '= "" set t = t _ block _ nl
        }
    }
    set guidance = ..GuidanceText(ctx, "clinical_followup_guidance")
    if guidance '= "" set t = t _ "Relevant clinical guidance:" _ nl _ guidance
    return t
}

ClassMethod EvidencePriorAuth(ctx As %DynamicObject) As %String
{
    set nl = $char(10)
    set requested = $select($isobject(ctx.context) && (ctx.context.requestedService '= ""): ctx.context.requestedService, 1: "the requested service")
    set sql = $select($isobject(ctx.sql): ctx.sql.%Get("prior_auth_supporting_evidence"), 1: "")
    set t = "Requested service: " _ requested _ nl _ nl _ "Patient clinical record:" _ nl
    if $isobject(sql) {
        if $isobject(sql.conditions) && (sql.conditions.%Size() > 0) {
            set list = "", it = sql.conditions.%GetIterator()
            while it.%GetNext(.k, .c) { set list = list _ $select(list = "": "", 1: ", ") _ c }
            set t = t _ "- Conditions: " _ list _ nl
        }
        if $isobject(sql.medications) && (sql.medications.%Size() > 0) {
            set t = t _ "- Medication history:" _ nl, it = sql.medications.%GetIterator()
            while it.%GetNext(.k, .m) {
                set t = t _ "    - " _ m.medication _ " (status: " _ m.status _ ")" _ $select(m.note '= "": " - " _ m.note, 1: "") _ nl
            }
        }
        if $isobject(sql.observations) && (sql.observations.%Size() > 0) {
            set t = t _ "- Observations:" _ nl, it = sql.observations.%GetIterator()
            while it.%GetNext(.k, .o) {
                if (o.value = "") continue
                set t = t _ "    - " _ o.code _ ": " _ o.value _ " " _ o.unit _ nl
            }
        }
    }
    set guidance = ..GuidanceText(ctx, "payer_policies")
    if guidance '= "" set t = t _ nl _ "Payer policy criteria (retrieved by semantic search over the payer's policy documents):" _ nl _ guidance
    return t
}

/// Render vector-search chunks for a collection as a readable guidance block.
ClassMethod GuidanceText(ctx As %DynamicObject, collection As %String) As %String
{
    if '$isobject(ctx.vector) return ""
    set chunks = ctx.vector.%Get(collection)
    if '$isobject(chunks) return ""
    set t = "", it = chunks.%GetIterator()
    while it.%GetNext(.k, .c) {
        set t = t _ "- " _ c.title _ ": " _ c.chunkText _ $char(10)
    }
    return t
}

/// Smart Patient Summary: a comprehensive, longitudinal evidence block. Opens
/// with computed demographics (name, age, sex) so the model can write a proper
/// clinical opener, then the full grouped record (problems, meds, allergies,
/// labs with values/dates, encounters, immunisations, care plan) and any alerts.
ClassMethod EvidenceSummary(ctx As %DynamicObject) As %String
{
    set nl = $char(10), t = ""
    set role = $select($isobject(ctx.context) && (ctx.context.role '= ""): ctx.context.role, 1: "treating clinician")
    set pres = ..FindResource(ctx, "Patient")
    if $isobject(pres) {
        set name = ##class(FAST.Runtime.FHIRReadOperation).Display("Patient", pres)
        set age = ..AgeFrom(pres.birthDate)
        set t = "Patient: " _ name _ $select(age '= "": ", " _ age _ "-year-old", 1: "") _ " " _ pres.gender
        if pres.birthDate '= "" set t = t _ " (date of birth " _ pres.birthDate _ ")"
        set t = t _ "." _ nl
    }
    set t = t _ "Requesting role / audience: " _ role _ "." _ nl _ nl
    set t = t _ ..EvidenceText(ctx)
    return t
}

/// First resource of a given type from the gathered FHIR evidence, or "".
ClassMethod FindResource(ctx As %DynamicObject, resourceType As %String) As %DynamicObject
{
    if '$isobject(ctx.fhir) || '$isobject(ctx.fhir.resources) return ""
    set it = ctx.fhir.resources.%GetIterator()
    while it.%GetNext(.k, .o) {
        if o.resourceType = resourceType return o.resource
    }
    return ""
}

/// Age in whole years at the dataset anchor date from a YYYY-MM-DD birthDate.
ClassMethod AgeFrom(birthDate As %String) As %String
{
    if $length(birthDate, "-") < 3 return ""
    set by = +$piece(birthDate, "-", 1), bm = +$piece(birthDate, "-", 2), bd = +$piece(birthDate, "-", 3)
    set ay = +$piece(..AnchorDate(), "-", 1), am = +$piece(..AnchorDate(), "-", 2), ad = +$piece(..AnchorDate(), "-", 3)
    if by = 0 return ""
    set age = ay - by
    if (am < bm) || ((am = bm) && (ad < bd)) set age = age - 1
    return age
}

/// NL->FHIR: the question + the real IRIS FHIR SQL schema to write against.
ClassMethod SchemaPrompt(ctx As %DynamicObject) As %String
{
    set nl = $char(10)
    set question = $select($isobject(ctx.context): ctx.context.question, 1: "")
    set anchor = ..AnchorDate()
    set cutoff = $zdate($zdateh(anchor, 3) - 183, 3)
    set days30 = $zdate($zdateh(anchor, 3) - 30, 3)
    set yr = +$piece(anchor, "-", 1)
    return "The user asks: """ _ question _ """" _ nl _ nl
        _ "Write a single read-only SQL SELECT for the InterSystems IRIS for Health FHIR SQL Builder schema below." _ nl _ nl
        _ "Tables:" _ nl
        _ "- HSFHIR_X0001_S.Patient(Key, _id, family, given, gender, birthdate). Key looks like 'Patient/<id>'. birthdate is 'YYYY-MM-DD'." _ nl
        _ "- HSFHIR_X0001_S.Observation(Key, code, patient, dateStart, status). Observation.patient = Patient.Key. "
        _ "The code column is a packed token string, so match a code with LIKE, e.g. code LIKE '%4548-4%'." _ nl
        _ "- HSFHIR_X0001_S_Observation.valueQuantity(Key, value, unit). Join valueQuantity.Key = Observation.Key for the numeric value." _ nl
        _ "- HSFHIR_X0001_S.Condition(Key, code, clinicalStatus, patient). Condition.patient = Patient.Key." _ nl
        _ "- HSFHIR_X0001_S.Encounter(Key, patient, class, status, dateStart, dateEnd). class is a packed token: emergency = LIKE '%EMER%', inpatient = LIKE '%IMP%', ambulatory = LIKE '%AMB%'. A cancelled status with a did-not-attend reason exists but reason text is not projected." _ nl
        _ "- HSFHIR_X0001_S.MedicationRequest(Key, patient, code, status, authoredon). code is the packed RxNorm token; status 'active' = currently prescribed." _ nl
        _ "- HSFHIR_X0001_S.Immunization(Key, patient, vaccineCode, ""date"", status). ""date"" is a reserved word - always quote it." _ nl _ nl
        _ "Code legend (match with LIKE '%<code>%'):" _ nl
        _ "- LOINC observations: HbA1c 4548-4, systolic BP 8480-6, diastolic BP 8462-4, BMI 39156-5, body weight 29463-7, "
        _ "LDL 13457-7, HDL 2085-9, total cholesterol 2093-3, triglycerides 2571-8, fasting glucose 1558-6, "
        _ "eGFR 33914-3, creatinine 2160-0, urea 22664-7, haemoglobin 718-7. "
        _ "Patients may have SEVERAL readings of the same test on different dates (real series) - for ""current"" values prefer the latest by dateStart." _ nl
        _ "- SNOMED conditions: type 2 diabetes 44054006, hypertension 59621000, heart failure 84114007, hyperlipidaemia 55822004, COPD 13645005, CKD stage 3 709044004, depression 35489007, obesity 414916001, atrial fibrillation 49436004." _ nl
        _ "- RxNorm medications (with drug class - use the class to decide which drugs answer the question): metformin 860975 (diabetes), "
        _ "lisinopril 314076 (blood pressure - ACE inhibitor), amlodipine 197361 (blood pressure - calcium channel blocker), "
        _ "atorvastatin 617312 (cholesterol statin - NOT a blood pressure drug), furosemide 200801 (loop diuretic - heart failure/fluid, only sometimes blood pressure), "
        _ "sertraline 312940 (antidepressant), tiotropium 896188 (COPD inhaler), apixaban 1364445 (anticoagulant)." _ nl _ nl
        _ "Rules:" _ nl
        _ "- IMPORTANT: every coded / status column (code, class, vaccineCode, clinicalStatus, category, verificationStatus) is stored as a PACKED search token, never a plain value. "
        _ "ALWAYS match these with LIKE '%value%' (e.g. clinicalStatus LIKE '%active%'), NEVER with = , or the comparison returns nothing. "
        _ "The plain string columns (status, dateStart, birthdate, authoredon, patient, Key) are normal values and compare normally." _ nl
        _ "- A single read-only SELECT only. Never write, and never use multiple statements." _ nl
        _ "- The dataset is a frozen snapshot whose ""today"" is " _ anchor _ ". ""The last 6 months"" means dateStart >= '" _ cutoff _ "'; ""the last 30 days"" means dateStart >= '" _ days30 _ "'. "
        _ "Ages are computed from birthdate against that date: ""over 65"" means birthdate <= '" _ (yr - 65) _ $extract(anchor, 5, 10) _ "'." _ nl
        _ "- Return human-friendly columns. For a patient name use %EXACT((given || ' ' || family)) - the %EXACT keeps natural capitalisation (DISTINCT would otherwise display names in uppercase). Use SELECT DISTINCT if joins could duplicate rows. Order results so the most clinically interesting rows come first." _ nl
        _ "- For trend questions (rising / falling between tests), use TOP 1 scalar subqueries ordered by dateStart - this exact pattern works: " _ nl
        _ "  SELECT %EXACT((p.given || ' ' || p.family)) AS Patient, "
        _ "(SELECT TOP 1 vq1.value FROM HSFHIR_X0001_S.Observation o1 JOIN HSFHIR_X0001_S_Observation.valueQuantity vq1 ON vq1.Key = o1.Key WHERE o1.patient = p.Key AND o1.code LIKE '%4548-4%' ORDER BY o1.dateStart ASC) AS FirstValue, "
        _ "(SELECT TOP 1 vq2.value FROM HSFHIR_X0001_S.Observation o2 JOIN HSFHIR_X0001_S_Observation.valueQuantity vq2 ON vq2.Key = o2.Key WHERE o2.patient = p.Key AND o2.code LIKE '%4548-4%' ORDER BY o2.dateStart DESC) AS LatestValue "
        _ "FROM HSFHIR_X0001_S.Patient p WHERE ... AND "
        _ "(SELECT TOP 1 vq2.value FROM HSFHIR_X0001_S.Observation o2 JOIN HSFHIR_X0001_S_Observation.valueQuantity vq2 ON vq2.Key = o2.Key WHERE o2.patient = p.Key AND o2.code LIKE '%4548-4%' ORDER BY o2.dateStart DESC) > "
        _ "(SELECT TOP 1 vq1.value FROM HSFHIR_X0001_S.Observation o1 JOIN HSFHIR_X0001_S_Observation.valueQuantity vq1 ON vq1.Key = o1.Key WHERE o1.patient = p.Key AND o1.code LIKE '%4548-4%' ORDER BY o1.dateStart ASC)" _ nl
        _ "- Example shape: SELECT DISTINCT %EXACT((p.given || ' ' || p.family)) AS Patient, vq.value AS HbA1c, o.dateStart AS Observed "
        _ "FROM HSFHIR_X0001_S.Observation o "
        _ "JOIN HSFHIR_X0001_S_Observation.valueQuantity vq ON vq.Key = o.Key "
        _ "JOIN HSFHIR_X0001_S.Patient p ON p.Key = o.patient "
        _ "WHERE o.code LIKE '%4548-4%' AND vq.value > 9 AND o.dateStart >= '" _ cutoff _ "'."
}

/// ---- Three-tier resolution; returns the parsed full-result object or "" ----
/// transport (optional output) describes the egress leg for the trace:
/// { via, url, httpStatus, note, source }.
ClassMethod Resolve(ctx As %DynamicObject, prompt As %DynamicObject, Output raw As %String, Output source As %String, Output transport As %DynamicObject) As %DynamicObject
{
    set raw = "", source = "deterministic", transport = ""
    set key = ..CacheKey(ctx.recipeId, prompt.system, prompt.user)
    // per-run cache bypass (the Run tab's "skip cache" switch): tier 1 is
    // skipped AND a live result is NOT stored, so bundled goldens stay intact.
    set noCache = +ctx.%Get("noCache")

    // Inside the production, the LLM leg is a REAL Ens message: AIHub sends a
    // FAST.Msg.LLMRequest (the literal HTTP request, auth masked) to the
    // LLMService operation, which answers from the bundled corpus (no network,
    // says so) or performs the live HTTPS call. The Visual Trace shows both
    // messages; tier logic and cache keys are identical to the direct path.
    set host = ctx.%Get("ensHost")
    if $isobject(host) {
        do ctx.%Remove("ensHost")
        set lreq = ##class(FAST.Msg.LLMRequest).Build(ctx.recipeId, prompt, key, noCache)
        set sc = host.SendRequestSync("LLMService", lreq, .lresp)
        if $$$ISOK(sc) && $isobject(lresp) {
            set transport = {}
            set transport.via = "LLMService"
            set transport.url = lreq.Url
            set transport.httpStatus = lresp.HttpStatus
            set transport.note = lresp.Note
            set transport.source = lresp.Source
            if lresp.Source = "cached" {
                set out = ##class(FAST.Util.JSON).Parse(lresp.CompletionJSON)
                if $isobject(out) { set raw = lresp.CompletionJSON, source = "cached"  return out }
            }
            if $extract(lresp.Source, 1, 4) = "live" {
                set clean = ..StripFences(lresp.CompletionJSON)
                set out = ##class(FAST.Util.JSON).Parse(clean)
                if $isobject(out) {
                    set raw = clean, source = lresp.Source
                    if 'noCache do ..StoreCache(key, $get(^FAST("llm", "model")), $extract(prompt.system _ " " _ prompt.user, 1, 1800), clean)
                    return out
                }
            }
            // "none" / "error" / unparseable -> deterministic fallback below.
            return ""
        }
        // message send failed: fall through to the direct path as a safety net.
    }

    // Tier 1 - bundled real LLM completion (the key-free demo path). The
    // "useCache" flag is the demo switch: on by default (always replay the
    // bundled response for a given input). A BYO-key user can turn it off to get
    // live calls instead. Cache-builds (which DO want fresh live calls) turn it
    // off, then the live result is captured below.
    if ..UseCache() && 'noCache {
        set hit = ##class(FAST.Data.LLMCache).KeyIdxOpen(key)
        if $isobject(hit) {
            set out = ##class(FAST.Util.JSON).Parse(hit.OutputJSON)
            if $isobject(out) { set raw = hit.OutputJSON, source = "cached"  return out }
        }
    }

    // Tier 2 - live LLM (only when a key is configured); cache the result.
    if ..HasLiveKey() {
        set msgs = []
        do msgs.%Push({"role": "system", "content": (prompt.system)})
        do msgs.%Push({"role": "user", "content": (prompt.user)})
        set sc = ##class(FAST.Runtime.LLMClient).Chat(msgs, .content, 1)
        if $$$ISOK(sc) {
            set clean = ..StripFences(content)
            set out = ##class(FAST.Util.JSON).Parse(clean)
            if $isobject(out) {
                set raw = clean, source = "live (" _ $get(^FAST("llm", "model"), "llm") _ ")"
                if 'noCache do ..StoreCache(key, $get(^FAST("llm", "model")), $extract(prompt.system _ " " _ prompt.user, 1, 1800), clean)
                return out
            }
        }
    }

    // Tier 3 - no cache, no key.
    return ""
}

/// Finalize the structured result: attach real evidence, normalize status and
/// safety, turn the LLM's draftAction into a proposedAction the writeback step
/// understands, and (for NL->FHIR) validate + execute the generated query.
ClassMethod Finalize(ByRef r As %DynamicObject, ctx As %DynamicObject, source As %String)
{
    set recipeId = ctx.recipeId
    set r.source = source
    set r.evidence = ..BuildEvidence(ctx)

    if r.status = "" {
        set r.status = $select(recipeId = "nl-to-fhir-query": "completed", 1: "needs_review")
    }
    set draftPending = (r.status '= "completed")
    set r.safety = {"requiresHumanReview": ($select(draftPending: "true", 1: "false")), "reason": "All clinical or administrative write-backs are drafts requiring human review."}

    // Turn an LLM-authored draftAction into the proposedAction shape.
    if r.%IsDefined("draftAction") && $isobject(r.draftAction) {
        set da = r.draftAction
        if da.status = "" set da.status = $select(da.resourceType = "DocumentReference": "current", 1: "draft")
        if da.%IsDefined("for") = 0, da.%IsDefined("subject") = 0, ctx.patientRef '= "" {
            // ensure the action references the patient
            if da.resourceType = "Task" { set da.for = {"reference": (ctx.patientRef)} }
            else { set da.subject = {"reference": (ctx.patientRef)} }
        }
        if da.%IsDefined("authoredOn") = 0, da.resourceType = "Task" set da.authoredOn = ..NowISO()
        if da.%IsDefined("date") = 0, da.resourceType = "DocumentReference" set da.date = ..NowISO()
        set pa = {}
        set pa.actionType = "FHIR_CREATE"
        set pa.resourceType = da.resourceType
        set pa.resource = da
        set r.proposedAction = pa
        do r.%Remove("draftAction")
    }

    if recipeId = "nl-to-fhir-query" do ..ExecuteQuery(.r)
}

/// Build the (real) evidence list from what RAG actually retrieved.
ClassMethod BuildEvidence(ctx As %DynamicObject) As %DynamicArray
{
    set holder = {}, holder.evidence = []
    if $isobject(ctx.vector) {
        set it = ctx.vector.%GetIterator()
        while it.%GetNext(.col, .chunks) {
            if '$isobject(chunks) continue
            set j = chunks.%GetIterator()
            while j.%GetNext(.k, .c) {
                do ..AddEvidence(holder, "KNOWLEDGE_CHUNK", col _ "/" _ c.documentId, c.title, "Semantic (vector) match, score " _ $fnumber(c.score, "", 2))
            }
        }
    }
    if $isobject(ctx.sql) {
        set it = ctx.sql.%GetIterator()
        while it.%GetNext(.name, .fact) {
            do ..AddEvidence(holder, "FHIR_QUERY", name, "Structured facts read from the FHIR repository", "Grounds the assessment in the record")
        }
    }
    if $isobject(ctx.fhir) && $isobject(ctx.fhir.resources) {
        set cnt = 0, it = ctx.fhir.resources.%GetIterator()
        while it.%GetNext(.k, .o) {
            set cnt = cnt + 1  if cnt > 8 quit
            do ..AddEvidence(holder, "FHIR_RESOURCE", o.resourceType, o.display, "From the patient record")
        }
    }
    return holder.evidence
}

/// ---- NL->FHIR: validate the LLM-generated query is read-only, then run it ----
ClassMethod ExecuteQuery(ByRef r As %DynamicObject)
{
    set sql = r.generatedQuery
    set r.generatedQueryType = "SQL"
    if '$isobject(r.%Get("limitations")) set r.limitations = []
    set r.resultPreview = []

    // Ambiguous question: the agent asked a clarifying question instead of
    // guessing - nothing to validate or run.
    if (r.clarification '= "") && (sql = "") {
        set r.validationStatus = "clarification"
        return
    }

    if (sql = "") || '..IsReadOnly(sql) {
        set r.validationStatus = "rejected"
        set r.readOnlyGuard = "objectscript"
        do r.limitations.%Push("The generated query was not a single safe read-only SELECT, so it was not executed.")
        return
    }
    // Second gate, defense in depth: AST-level parse via IRIS Embedded Python
    // (sqlparse) - catches what keyword matching cannot. Armed() probes the
    // Python runtime in a sacrificial job once per instance boot, because in
    // a broken runtime (see docs/embedded-python-bug.md) an in-process call
    // SIGSEGVs the serving process and no try/catch can stop a signal 11.
    // readOnlyGuard truthfully reports which gates actually ran.
    set guard = {"available": 0, "ok": 1, "reason": "embedded python not armed"}
    if ##class(FAST.Runtime.SqlGuard).Armed() set guard = ##class(FAST.Runtime.SqlGuard).Check(sql)
    if guard.available && 'guard.ok {
        set r.validationStatus = "rejected"
        set r.readOnlyGuard = "objectscript+sqlparse"
        do r.limitations.%Push("The Embedded Python sqlparse gate rejected the query: " _ guard.reason _ ". It was not executed.")
        return
    }
    set r.readOnlyGuard = $select(guard.available: "objectscript+sqlparse", 1: "objectscript")
    set r.validationStatus = "approved"

    set st = ##class(%SQL.Statement).%New()
    set sc = st.%Prepare(sql)
    if $$$ISERR(sc) {
        do r.limitations.%Push("The query was validated as read-only but could not be prepared: " _ $zstrip($system.Status.GetErrorText(sc), "<>W"))
        return
    }
    set rs = st.%Execute()
    if rs.%SQLCODE < 0 {
        do r.limitations.%Push("The query executed with SQLCODE " _ rs.%SQLCODE _ ": " _ rs.%Message)
        return
    }
    set md = rs.%GetMetadata(), cols = md.columns
    set n = 0
    while rs.%Next() {
        set n = n + 1  if n > 50 quit
        set row = {}
        for i = 1:1:cols.Count() {
            set c = cols.GetAt(i)
            set v = rs.%GetData(i)
            // IRIS FHIR search-projection string columns carry internal collation
            // prefix bytes; strip non-printable control chars from text cells so the
            // real values display cleanly (numeric cells are left untouched/typed).
            if (v '= "") && '$isvalidnum(v) set v = $zstrip(v, "*C")
            do row.%Set(c.colName, v)
        }
        do r.resultPreview.%Push(row)
    }
    set r.matchCount = r.resultPreview.%Size()
}

/// Whitelist guard: a single read-only SELECT, no DML/DDL, no second statement.
ClassMethod IsReadOnly(sql As %String) As %Boolean
{
    set s = $zconvert($zstrip(sql, "<>W"), "U")
    if s = "" return 0
    // must begin with SELECT (optionally inside parentheses)
    set head = $zstrip($translate(s, "(", " "), "<W")
    if $extract(head, 1, 7) '= "SELECT " return 0
    // reject a populated second statement after a ';'
    if (s [ ";") && ($zstrip($piece(s, ";", 2, *), "<>W") '= "") return 0
    // reject any write / DDL / procedure-call keywords
    set padded = " " _ $translate(s, $char(9, 10, 13), "   ") _ " "
    set bad = $listbuild(" INSERT ", " UPDATE ", " DELETE ", " DROP ", " ALTER ", " CREATE ", " TRUNCATE ", " MERGE ", " GRANT ", " REVOKE ", " CALL ", " EXEC ", " INTO ", "%XECUTE")
    set ptr = 0
    while $listnext(bad, ptr, kw) { if padded [ kw return 0 }
    return 1
}

/// Current time as a valid FHIR dateTime (ISO-8601, "T" separator + "Z").
ClassMethod NowISO() As %String
{
    return $translate($zdatetime($ztimestamp, 3), " ", "T") _ "Z"
}

/// ---- Legacy deterministic scaffold + prose overlay (nine non-hero recipes,
///      and the no-key/no-cache fallback for the heroes) ----

ClassMethod Build(ctx As %DynamicObject) As %DynamicObject
{
    set recipe = ctx.recipeId
    if recipe = "results-followup" return ..ResultsFollowup(ctx)
    if recipe = "prior-auth" return ..PriorAuth(ctx)
    if recipe = "nl-to-fhir-query" return ..NlToFhir(ctx)
    return ..Generic(ctx)
}

/// ---- Hero 1: Abnormal Results Follow-Up (deterministic fallback) ----
ClassMethod ResultsFollowup(ctx As %DynamicObject) As %DynamicObject
{
    set sql = ctx.sql.%Get("abnormal_result_followup_status")
    set patientRef = ctx.patientRef
    set ab = $select($isobject(sql) && $isobject(sql.abnormal) && (sql.abnormal.%Size() > 0): sql.abnormal.%Get(0), 1: "")
    set code = $select($isobject(ab): ab.code, 1: "result")
    set val = $select($isobject(ab): ab.value _ " " _ ab.unit, 1: "")
    set date = $select($isobject(ab): ab.date, 1: "")
    set hasFollowUp = $select($isobject(sql): sql.hasFollowUp, 1: 0)

    set r = ..Base("needs_review")
    set r.summary = "Abnormal " _ code _ " (" _ val _ ", " _ date _ ") has " _ $select(hasFollowUp: "documented follow-up.", 1: "no documented follow-up - the care loop appears open.")
    do r.findings.%Push("Abnormal " _ code _ ": " _ val)
    do r.findings.%Push($select(hasFollowUp: "Follow-up found.", 1: "No follow-up Task, ServiceRequest, or Appointment found for this patient."))
    set rec = {}
    set rec.priority = "urgent"
    set rec.owner = "care-team"
    set rec.text = "Create a follow-up Task: contact the patient, review and intensify therapy, and arrange diabetes education."
    do r.recommendations.%Push(rec)

    if 'hasFollowUp {
        set task = {}
        set task.resourceType = "Task"
        set task.status = "draft"
        set task.intent = "order"
        set task.priority = "urgent"
        set task.description = "Follow up abnormal " _ code _ " (" _ val _ ", " _ date _ "): contact patient, review/intensify therapy, arrange diabetes education."
        set task.for = {"reference": (patientRef)}
        set task.authoredOn = ..NowISO()
        set pa = {}
        set pa.actionType = "FHIR_CREATE"
        set pa.resourceType = "Task"
        set pa.resource = task
        set r.proposedAction = pa
    }
    return r
}

/// ---- Hero 2: Prior Authorization Evidence (deterministic fallback) ----
ClassMethod PriorAuth(ctx As %DynamicObject) As %DynamicObject
{
    set sql = ctx.sql.%Get("prior_auth_supporting_evidence")
    set requested = $select($isobject(ctx.context): ctx.context.requestedService, 1: "the requested service")
    set r = ..Base("needs_review")
    set r.requestedService = requested

    set matched = [], missing = []
    set bmi = ..FindObs(sql, "BMI", "body mass")
    if (bmi '= "") && (bmi >= 30) {
        do matched.%Push("Baseline BMI >= 30 (recorded " _ bmi _ " kg/m2)")
    } else {
        do missing.%Push("Documented baseline BMI within the last 6 months")
    }
    set failed = ..FindFailedTherapy(sql)
    if failed '= "" {
        do matched.%Push("Prior weight-management therapy trialled and inadequate: " _ failed)
    } else {
        do missing.%Push("Documentation of a prior weight-management therapy trial and outcome")
    }
    do missing.%Push("Documented 6-month comprehensive lifestyle modification program (enrollment dates and progress notes)")

    set r.policyCriteriaMatched = matched
    set r.missingEvidenceChecklist = missing
    set r.missingData = missing
    set r.summary = "Assembled prior authorization evidence for " _ requested _ ": " _ matched.%Size() _ " policy criteria met, " _ missing.%Size() _ " item(s) still required."
    set r.draftJustification = "The member has type 2 diabetes with obesity (BMI " _ bmi _ "). Prior therapy was trialled with inadequate response. Outstanding documentation is listed in the missing-evidence checklist and must be supplied before submission. This packet does not constitute a coverage determination."
    do r.findings.%Push(matched.%Size() _ " of the payer's documented criteria are satisfied by the record")
    do r.findings.%Push(missing.%Size() _ " item(s) are missing and would likely cause a denial if not supplied")
    set rec = {}
    set rec.priority = "routine"
    set rec.owner = "utilization-management"
    set rec.text = "Obtain the missing lifestyle-program documentation, then submit the evidence packet."
    do r.recommendations.%Push(rec)

    set doc = {}
    set doc.resourceType = "DocumentReference"
    set doc.status = "current"
    set doc.type = {"text": "Prior Authorization Evidence Packet"}
    set doc.subject = {"reference": (ctx.patientRef)}
    set doc.date = ($zdatetime($ztimestamp, 3))
    set doc.description = "Evidence packet for " _ requested
    set pa = {}
    set pa.actionType = "FHIR_CREATE"
    set pa.resourceType = "DocumentReference"
    set pa.resource = doc
    set r.proposedAction = pa
    return r
}

/// ---- Hero 3: Natural Language to FHIR Query (deterministic fallback) ----
/// Emits a REAL executable query over the FHIR SQL projections, so even the
/// no-LLM fallback runs for real (ExecuteQuery validates + executes it).
ClassMethod NlToFhir(ctx As %DynamicObject) As %DynamicObject
{
    set question = $select($isobject(ctx.context): ctx.context.question, 1: "")
    set cutoff = $zdate($zdateh(..AnchorDate(), 3) - 183, 3)
    set r = ..Base("completed")
    set r.userQuestion = question
    set r.interpretedIntent = "Find patients with an active type 2 diabetes condition who have an HbA1c (LOINC 4548-4) result above 9% recorded since " _ cutoff _ "."
    set r.generatedQueryType = "SQL"
    set r.generatedQuery = "SELECT DISTINCT (p.given || ' ' || p.family) AS Patient, vq.value AS HbA1c, o.dateStart AS Observed" _ $char(10)
        _ "FROM HSFHIR_X0001_S.Observation o" _ $char(10)
        _ "JOIN HSFHIR_X0001_S_Observation.valueQuantity vq ON vq.Key = o.Key" _ $char(10)
        _ "JOIN HSFHIR_X0001_S.Patient p ON p.Key = o.patient" _ $char(10)
        _ "WHERE o.code LIKE '%4548-4%' AND vq.value > 9 AND o.dateStart >= '" _ cutoff _ "'" _ $char(10)
        _ "  AND o.patient IN (SELECT patient FROM HSFHIR_X0001_S.Condition WHERE code LIKE '%44054006%')" _ $char(10)
        _ "ORDER BY vq.value DESC"
    set r.queryExplanation = "Read-only cohort query. Joins the diabetes diagnosis with recent HbA1c observations and filters on value and recency. No write operation is generated."
    set r.summary = "Interpreted the question and generated a validated read-only SQL query over the FHIR repository."
    return r
}

/// ---- Generic fallback for the nine non-hero templates ----
ClassMethod Generic(ctx As %DynamicObject) As %DynamicObject
{
    set def = ctx.def
    set fhirCount = $select($isobject(ctx.fhir): ctx.fhir.count, 1: 0)
    set r = ..Base($select($extract(def.action.type, 1, 5) = "draft": "needs_review", 1: "completed"))
    set r.summary = def.name _ " executed over " _ fhirCount _ " FHIR resource(s) and produced a draft structured result."
    do r.findings.%Push("Evidence gathered across configured FHIR / SQL / vector sources")
    do ..AddEvidence(r, "CONTEXT", def.id, "Flow executed", "Demonstrates the configured evidence pipeline")
    set rec = {}
    set rec.priority = "routine"
    set rec.owner = def.agent.role
    set rec.text = "Review the structured output and the proposed draft action."
    do r.recommendations.%Push(rec)
    if ($extract(def.action.type, 1, 5) = "draft") && (def.action.resourceType '= "") {
        set res = {}
        set res.resourceType = def.action.resourceType
        set res.status = "draft"
        set res.subject = {"reference": (ctx.patientRef)}
        set pa = {}
        set pa.actionType = "FHIR_CREATE"
        set pa.resourceType = def.action.resourceType
        set pa.resource = res
        set r.proposedAction = pa
    }
    return r
}

/// Legacy prose overlay for the non-hero recipes (cache -> live -> leave as-is).
ClassMethod Narrate(ctx As %DynamicObject, ByRef r As %DynamicObject)
{
    set def = ctx.%Get("def")
    if '$isobject(def) return
    set role = def.agent.role, instruction = def.agent.instruction
    set sys = "You are a " _ role _ ". " _ instruction _ " Use ONLY the supplied evidence; do not invent facts. "
            _ "Respond with a JSON object with keys: summary (string, 1-2 sentences), findings (array of short strings), "
            _ "recommendations (array of objects with priority, owner, text). Be concise and clinically careful."
    set user = "Request context: " _ ##class(FAST.Util.JSON).ToString(ctx.context, 0) _ $char(10, 10) _ "Evidence:" _ $char(10) _ ..EvidenceText(ctx)
    set key = ..CacheKey(ctx.recipeId, sys, user)

    set hit = ##class(FAST.Data.LLMCache).KeyIdxOpen(key)
    if $isobject(hit) {
        set out = ##class(FAST.Util.JSON).Parse(hit.OutputJSON)
        if $isobject(out) { do ..Overlay(.r, out, ctx.recipeId)  set r.source = "cached"  return }
    }
    if ..HasLiveKey() {
        set msgs = []
        do msgs.%Push({"role": "system", "content": (sys)})
        do msgs.%Push({"role": "user", "content": (user)})
        set sc = ##class(FAST.Runtime.LLMClient).Chat(msgs, .content, 1)
        if $$$ISOK(sc) {
            set out = ##class(FAST.Util.JSON).Parse(..StripFences(content))
            if $isobject(out) {
                do ..Overlay(.r, out, ctx.recipeId)
                set r.source = "live (" _ $get(^FAST("llm", "model"), "llm") _ ")"
                do ..StoreCache(key, $get(^FAST("llm", "model")), $extract(sys _ " " _ user, 1, 1800), ##class(FAST.Util.JSON).ToString(out, 0))
                return
            }
        }
    }
}

ClassMethod Overlay(ByRef r As %DynamicObject, out As %DynamicObject, recipeId As %String)
{
    if out.summary '= "" set r.summary = out.summary
    if $isobject(out.findings) set r.findings = out.findings
    if $isobject(out.recommendations) set r.recommendations = out.recommendations
}

/// ---- shared helpers ----

ClassMethod HasLiveKey() As %Boolean
{
    return ($get(^FAST("llm", "mode")) = "external") && (##class(FAST.Runtime.LLMClient).Key() '= "")
}

/// Whether to serve bundled cached responses (the default demo path). On unless
/// explicitly disabled via ^FAST("llm","useCache")=0 (e.g. a BYO-key user who
/// wants live calls, or a cache-build run capturing fresh responses).
ClassMethod UseCache() As %Boolean
{
    return ($get(^FAST("llm", "useCache"), 1) '= 0)
}

ClassMethod CacheKey(recipeId As %String, sys As %String, user As %String) As %String
{
    set p = sys _ $char(30) _ user
    return recipeId _ "|" _ $get(^FAST("llm", "model"), "?") _ "|" _ ..#PROMPTVERSION _ "|" _ $zcrc(p, 7) _ "-" _ $length(p)
}

ClassMethod StoreCache(key As %String, model As %String, preview As %String, outputJSON As %String)
{
    set c = ##class(FAST.Data.LLMCache).KeyIdxOpen(key)
    if '$isobject(c) {
        set c = ##class(FAST.Data.LLMCache).%New()
        set c.CacheKey = key
    }
    set c.Kind = "completion"
    set c.Model = model
    set c.PromptVersion = ..#PROMPTVERSION
    set c.InputPreview = preview
    set c.OutputJSON = outputJSON
    do c.%Save()
}

/// Flatten gathered evidence into a generic prompt block (legacy / non-hero).
/// Clean, clinician-facing evidence rendering for the generic agents. Groups the
/// real FHIR resources by type, renders the structured SQL facts by their known
/// shape, and adds retrieved guidance - with no internal labels (no "SQL",
/// "vector", or query/collection names) leaking to the model.
ClassMethod EvidenceText(ctx As %DynamicObject) As %String
{
    set nl = $char(10), t = ""

    // request context (role, requested service, free text, etc.)
    if $isobject(ctx.context) {
        set ctxLine = "", cit = ctx.context.%GetIterator()
        while cit.%GetNext(.ck, .cv) {
            if '$isobject(cv) && (cv '= "") set ctxLine = ctxLine _ $select(ctxLine = "": "", 1: "; ") _ ck _ ": " _ cv
        }
        if ctxLine '= "" set t = t _ "Request context: " _ ctxLine _ nl _ nl
    }

    // patient record (FHIR), grouped by resource type
    if $isobject(ctx.fhir) && $isobject(ctx.fhir.resources) && (ctx.fhir.resources.%Size() > 0) {
        set grp = {}, it = ctx.fhir.resources.%GetIterator()
        while it.%GetNext(.k, .o) {
            set rt = o.resourceType
            if '$isobject(grp.%Get(rt)) do grp.%Set(rt, [])
            do grp.%Get(rt).%Push(o.display)
        }
        set t = t _ "Patient record:" _ nl
        set git = grp.%GetIterator()
        while git.%GetNext(.rt, .arr) {
            set line = "", j = arr.%GetIterator()
            while j.%GetNext(.kk, .d) { set line = line _ $select(line = "": "", 1: "; ") _ d }
            set t = t _ "- " _ rt _ ": " _ line _ nl
        }
        set t = t _ nl
    }

    // structured facts (rendered by known shape, no query names)
    if $isobject(ctx.sql) {
        set sit = ctx.sql.%GetIterator()
        while sit.%GetNext(.name, .fact) {
            if '$isobject(fact) continue
            set block = ..RenderFact(fact)
            if block '= "" set t = t _ block _ nl
        }
    }

    // retrieved clinical guidance (vector RAG)
    if $isobject(ctx.vector) {
        set g = "", vit = ctx.vector.%GetIterator()
        while vit.%GetNext(.col, .chunks) {
            if '$isobject(chunks) continue
            set j = chunks.%GetIterator()
            while j.%GetNext(.kk, .c) { set g = g _ "- " _ c.title _ ": " _ c.chunkText _ nl }
        }
        if g '= "" set t = t _ "Relevant clinical guidance:" _ nl _ g
    }

    // reusable EvidenceSource components (custom agents) - rendered by known
    // shape where possible, raw facts otherwise
    if $isobject(ctx.sources) {
        set sit2 = ctx.sources.%GetIterator()
        while sit2.%GetNext(.slug, .facts) {
            if '$isobject(facts) continue
            set block = ..RenderFact(facts)
            if block = "" set block = "Evidence (" _ slug _ "): " _ $extract(##class(FAST.Util.JSON).ToString(facts, 0), 1, 2500) _ nl
            set t = t _ nl _ block
        }
    }
    return t
}

/// Render one structured-fact object by its known shape into clinician-facing text.
/// "rows" (last) is the generic shape a custom SQL EvidenceSource returns, so
/// author-written queries render as clean facts rather than raw JSON.
ClassMethod RenderFact(fact As %DynamicObject) As %String
{
    set nl = $char(10)
    set keys = $listbuild("conditions", "labs", "encounters", "medications", "admissions", "gaps", "goals", "openTasks", "abnormal", "matches", "rows")
    set ptr = 0
    while $listnext(keys, ptr, key) {
        if '$isobject(fact.%Get(key)) continue
        set arr = fact.%Get(key)
        if arr.%Size() = 0 continue
        set label = $case(key, "conditions": "Active problems", "labs": "Recent results", "encounters": "Encounters", "medications": "Medications", "admissions": "Admissions / ED visits", "gaps": "Open care gaps", "goals": "Care-plan goals", "openTasks": "Open tasks", "abnormal": "Abnormal results", "matches": "Cohort matches", "rows": "Structured facts", : key)
        set t = label _ ":" _ nl, it = arr.%GetIterator()
        while it.%GetNext(.k, .row) {
            set t = t _ "  - " _ ..RowText(row) _ nl
        }
        return t
    }
    return ""
}

/// Flatten a fact row object into a readable "k: v" line.
ClassMethod RowText(row As %DynamicObject) As %String
{
    if '$isobject(row) return row
    set s = "", it = row.%GetIterator()
    while it.%GetNext(.k, .v) {
        if $isobject(v) || (v = "") continue
        set s = s _ $select(s = "": "", 1: ", ") _ k _ ": " _ v
    }
    return s
}

ClassMethod StripFences(s As %String) As %String
{
    set s = $zstrip(s, "<>W")
    if $extract(s, 1, 3) = "```" {
        set s = $replace(s, "```json", "")
        set s = $replace(s, "```", "")
        set s = $zstrip(s, "<>W")
    }
    return s
}

ClassMethod Base(status As %String) As %DynamicObject
{
    set r = {}
    set r.status = status
    set r.summary = ""
    set r.findings = []
    set r.evidence = []
    set r.recommendations = []
    set r.missingData = []
    set r.safety = {"requiresHumanReview": ($select(status = "completed": "false", 1: "true")), "reason": "All clinical or administrative write-backs are drafts requiring human review."}
    set r.source = "deterministic"
    return r
}

ClassMethod AddEvidence(r As %DynamicObject, type As %String, source As %String, display As %String, relevance As %String)
{
    set e = {}
    set e.evidenceType = type
    set e.source = source
    set e.display = display
    set e.relevance = relevance
    do r.evidence.%Push(e)
}

ClassMethod FindObs(sql As %DynamicObject, term1 As %String, term2 As %String) As %String
{
    if '$isobject(sql) || '$isobject(sql.observations) return ""
    set it = sql.observations.%GetIterator()
    while it.%GetNext(.k, .o) {
        set lc = $zconvert(o.code, "l")
        if (lc [ $zconvert(term1, "l")) || (lc [ $zconvert(term2, "l")) return o.value
    }
    return ""
}

ClassMethod FindFailedTherapy(sql As %DynamicObject) As %String
{
    if '$isobject(sql) || '$isobject(sql.medications) return ""
    set it = sql.medications.%GetIterator()
    while it.%GetNext(.k, .m) {
        if (m.status = "completed") || ($isobject(m) && (m.note [ "discontinued")) || (m.note [ "insufficient") {
            return m.medication _ $select(m.note '= "": " - " _ m.note, 1: "")
        }
    }
    return ""
}

}
