// Serialization of a triage conversation's answers into the `answers` input the
// agent receives. Shared VERBATIM by the chat UI and the cache builder
// (scripts/build-triage-cache.mjs) - the serialized string is part of the LLM
// cache key, so both sides must produce byte-identical text.

/** items: [{question, answer}] -> the agent's `answers` input string. */
export function serializeAnswers(items) {
  return items.map((qa) => `${qa.question} -> ${qa.answer}`).join(" | ");
}
