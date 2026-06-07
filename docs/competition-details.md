We are building an entry for the InterSystems AI Agents for FHIR programming contest.

Core contest requirements:
- The app must be fully functional, not just a wrapper around an existing library.
- It must work on Community Edition IRIS or IRIS for Health.
- It must be open source, hosted somewhere accessible such as GitHub or GitLab.
- The README must be in English and should include clear installation steps, usage instructions, and preferably a demo video or detailed walkthrough.
- The app should be easy for judges to run and evaluate.
- Submissions are due June 7; voting/judging runs June 8–14.
- Apps can be improved during voting, but late fixes may not be seen by judges.

Scoring / quality priorities:
- There is a $12,000 prize pool with both expert judging and community voting.
- The contest includes suggested tasks worth a major 5-point bonus.
- Only one suggested task bonus can count per application, so pick one and implement it deeply rather than trying to cover many superficially.
- Suggested task examples include:
  - Smart patient summary generator
  - FHIR prior authorization co-pilot
  - Preventive screening / care-gap finder
- The solution should clearly align with one suggested task and document that alignment in the README.

Technical theme:
- The app should combine FHIR interoperability with agentic AI.
- FHIR provides structured healthcare data, standard APIs, terminology integration, and cross-system interoperability.
- The AI agent should add reasoning, tool orchestration, contextual understanding, clinical summarization, and multi-step task planning.
- The agent should not treat the LLM as the source of truth. It should use tools/API calls against the FHIR server.
- For write/update operations, include approval steps and guardrails so the agent cannot silently modify clinical data.

Strong solution architecture ideas:
- Implement explicit tools for FHIR operations:
  - FHIR search
  - FHIR read
  - FHIR update
  - Patient `$everything`
  - Terminology lookup / code resolution
  - Summarization sub-agent or summarization pipeline
- Use terminology resolution before clinical searches, e.g. resolve “type 2 diabetes mellitus” to SNOMED CT before searching Conditions.
- Support reverse-chain FHIR queries where appropriate, e.g. finding Patients based on Condition codes using `_has`.
- Keep token usage under control by extracting relevant fields from FHIR bundles before sending them to the LLM.
- Consider a sub-agent or preprocessing step that converts large FHIR bundles into compact clinical summaries.

Useful demo behaviours to implement:
- “Create an effective summary of patient X.”
- “Find all patients with last name Larson.”
- “Show SNOMED CT codes for type 2 diabetes mellitus.”
- “Find all patients with type 2 diabetes.”
- “Prepare an update to patient X’s identifier, but require human approval before applying it.”

Important safety / quality features:
- Never hallucinate clinical facts; cite or trace summaries back to FHIR resources.
- Show what FHIR query was generated.
- Show which tools were called.
- Show terminology codes used in searches.
- For updates, show old value, proposed new value, affected resource, and require confirmation.
- Prefer read-only functionality unless write support is carefully guarded.
- Add audit-style logs of agent actions.

README should emphasize:
- Which suggested task we implemented and why.
- How to run against IRIS / IRIS for Health.
- Required environment variables.
- Example prompts.
- Architecture diagram or explanation of agent tools.
- Screenshots or demo video.
- Known limitations.
- Safety guardrails.
- How the solution uses FHIR resources and InterSystems features.

The strongest implementation will look like a real agentic healthcare app, not just a chat UI. It should demonstrate that the agent can plan, call FHIR tools, resolve terminology, reduce bundle size, summarize clinically, and safely handle proposed data changes.