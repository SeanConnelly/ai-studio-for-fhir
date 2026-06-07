// Expansion of the "Surprise me" question catalogue (seed/demo-inputs/
// ask-questions.json). Shared VERBATIM by the Ask page (vite import) and the
// cache builder (node import) - the expanded strings are LLM cache keys, so
// both sides must produce byte-identical text.
//
// Slot syntax: a slots key may be a single name ("months": [..]) or a pipe
// group ("cond|test|thr": ["diabetic|HbA1c|9", ...]) whose values substitute
// together (keeps clinically sensible pairings). Variants are the cross
// product of all slot groups, minus any catalogue exclusions.

/** Expand one template into its question variants. */
function expandTemplate(template) {
  const groups = Object.entries(template.slots || {});
  let texts = [template.text];
  for (const [names, values] of groups) {
    const keys = names.split("|");
    const next = [];
    for (const t of texts) {
      for (const v of values) {
        const parts = String(v).split("|");
        let s = t;
        keys.forEach((k, i) => { s = s.split(`{${k}}`).join(parts[i]); });
        next.push(s);
      }
    }
    texts = next;
  }
  return texts;
}

/** All question variants across the catalogue, exclusions removed. */
export function allQuestions(catalogue) {
  const excluded = new Set(catalogue.exclusions || []);
  const out = [];
  for (const t of catalogue.templates || []) {
    for (const q of expandTemplate(t)) {
      if (!excluded.has(q)) out.push(q);
    }
  }
  return out;
}

/** One random variant. */
export function randomQuestion(catalogue) {
  const all = allQuestions(catalogue);
  return all[Math.floor(Math.random() * all.length)];
}
