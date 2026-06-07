#!/usr/bin/env bash
#
# Smoke test for FHIR Agent Studio. Verifies the running app end to end using
# only curl + grep (no jq/python needed).
#
# Usage:  ./test/smoke-test.sh [base-url]
#   default base: http://localhost:42773/fhir-agent-studio/api
#
set -u

BASE="${1:-http://localhost:42773/fhir-agent-studio/api}"
FAILS=0

pass() { echo "[ok]   $1"; }
fail() { echo "[FAIL] $1"; FAILS=$((FAILS + 1)); }

echo "Smoke testing $BASE"
echo

# 1. status ok
S=$(curl -s "$BASE/status")
echo "$S" | grep -q '"status":"ok"' && pass "API status ok" || fail "API status not ok"

# 2. 12 templates
echo "$S" | grep -q '"templates":12' && pass "12 templates loaded" || fail "expected 12 templates"

# 3. knowledge docs present (vector search corpus)
KD=$(echo "$S" | grep -o '"knowledgeDocuments":[0-9]*' | grep -o '[0-9]*$')
[ "${KD:-0}" -ge 40 ] && pass "$KD knowledge documents" || fail "expected >= 40 knowledge documents, got ${KD:-0}"

# 4. create a flow from a hero template
curl -s -X POST "$BASE/flows/from-template/results-followup" | grep -q '"slug":"results-followup"' \
  && pass "created flow results-followup" || fail "could not create flow"

# 5. compile → all 7 artefacts
C=$(curl -s -X POST "$BASE/flows/results-followup/compile")
if echo "$C" | grep -q 'recipe.json' && echo "$C" | grep -q 'module.xml' \
   && echo "$C" | grep -q 'healthconnect-mapping.json'; then
  pass "compiled results-followup (artefacts present)"
else
  fail "compile did not produce expected artefacts"
fi

# 6. run the agent with studio inputs (defaults → reproduces the demo case)
R=$(curl -s -X POST "$BASE/flows/results-followup/run" -H "Content-Type: application/json" -d '{"inputs":{}}')
echo "$R" | grep -q '"status":"needs_review"' && pass "ran results-followup (needs_review)" || fail "run status unexpected"

# 7. draft FHIR action present (safety: needs review, not committed)
echo "$R" | grep -q '"resourceType":"Task"' && pass "drafted a Task action" || fail "no drafted Task"

# 8. trace has 8 HealthConnect steps (incl. the LLMService egress leg)
STEPS=$(echo "$R" | grep -o '"componentName"' | wc -l | tr -d ' ')
if [ "$STEPS" = "8" ]; then pass "trace has 8 steps"; else fail "trace has $STEPS steps (expected 8)"; fi

# 9. prior-auth vector-grounded missing-evidence checklist (via the run endpoint)
P=$(curl -s -X POST "$BASE/flows/prior-auth/run" -H "Content-Type: application/json" -d '{"inputs":{}}')
echo "$P" | grep -q 'lifestyle modification program' && pass "prior-auth missing-evidence checklist" || fail "prior-auth checklist missing"

# 10. NL→FHIR query returns matches (via the run endpoint)
N=$(curl -s -X POST "$BASE/flows/nl-to-fhir-query/run" -H "Content-Type: application/json" -d '{"inputs":{}}')
echo "$N" | grep -q '"validationStatus":"approved"' && pass "NL→FHIR query approved" || fail "NL query not approved"

# 11. trigger-driven patient picker is backed by the real FHIR repo
curl -s "$BASE/options/patients" | grep -q 'pat-abnormal-001' && pass "patient picker lists real FHIR patients" || fail "patient options missing"

# 12. all 12 agents are LLM-authored and replay from the bundled cache (sampling)
CACHEDOK=1
for slug in smart-patient-summary medication-safety gaps-in-care care-plan-navigator sdoh-referral clinical-trial-matcher readmission-risk conversational-triage lab-explainer; do
  A=$(curl -s -X POST "$BASE/flows/$slug/run" -H "Content-Type: application/json" -d '{"inputs":{}}')
  echo "$A" | grep -q '"source":"cached"' || { CACHEDOK=0; echo "   ($slug not cached)"; }
done
[ "$CACHEDOK" = "1" ] && pass "9 non-hero agents replay from bundled cache (source=cached)" || fail "some agents did not replay from cache"

# 13. reusable component CRUD (Prompt Manager)
curl -s -X POST "$BASE/components/prompts" -H "Content-Type: application/json" \
  -d '{"slug":"smoke-prompt","name":"Smoke","systemTemplate":"x"}' | grep -q '"created":true' \
  && pass "component create (prompt)" || fail "component create failed"
curl -s "$BASE/components/prompts/smoke-prompt" | grep -q '"slug":"smoke-prompt"' \
  && pass "component get" || fail "component get failed"
curl -s -X DELETE "$BASE/components/prompts/smoke-prompt" | grep -q '"deleted":1' \
  && pass "component delete" || fail "component delete failed"

# 14. explicit FHIR tools — reverse-chain cohort + terminology resolve
DCOUNT=$(curl -s "$BASE/fhir/tools/cohort?code=44054006&resourceType=Condition" | grep -o '"count":[0-9]*' | grep -o '[0-9]*$')
[ "${DCOUNT:-0}" -ge 1 ] && pass "FHIR cohort tool ($DCOUNT diabetics via _has)" || fail "cohort tool returned no patients"
curl -s "$BASE/fhir/tools/terminology?text=type%202%20diabetes" | grep -q '"code":"44054006"' \
  && pass "terminology resolve (type 2 diabetes -> SNOMED 44054006)" || fail "terminology resolve failed"

# 15. patient search over the real FHIR repository
curl -s "$BASE/fhir/tools/patient-search?gender=female" | grep -q '"count"' \
  && pass "patient search tool" || fail "patient search failed"

# 16. approval workflow commits a draft to the FHIR repo + audits it.
# The committed Task is deleted again afterwards — otherwise it closes the
# abnormal-result hero's open loop and changes that scenario for later runs.
RID=$(echo "$R" | grep -o '"requestId":"[^"]*"' | head -1 | sed 's/.*:"//;s/"//')
if [ -n "$RID" ]; then
  AID=$(curl -s "$BASE/invocations/$RID" | grep -o '"id":"[0-9]*"' | head -1 | sed 's/.*:"//;s/"//')
  if [ -n "$AID" ]; then
    AP=$(curl -s -X POST "$BASE/invocations/$RID/actions/$AID/approve" -H "Content-Type: application/json" -d '{"reviewer":"smoke"}')
    if echo "$AP" | grep -q '"committedResourceRef"'; then
      pass "approval commits draft to FHIR + audits"
      CREF=$(echo "$AP" | grep -o '"committedResourceRef":"[^"]*"' | sed 's/.*:"//;s/"//')
      FHIRBASE="${BASE%/api}/fhir/r4"
      # the FHIR endpoint requires auth (demo credentials); verify the HTTP code
      DCODE=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE -u "_SYSTEM:SYS" "$FHIRBASE/$CREF")
      case "$DCODE" in
        200|204) pass "smoke cleanup: removed committed $CREF (open loop restored)" ;;
        *) fail "could not delete committed $CREF (HTTP $DCODE)" ;;
      esac
    else
      fail "approval did not commit"
    fi
  else
    fail "no proposed action id for approval"
  fi
else
  fail "no requestId for approval"
fi

echo
if [ "$FAILS" -eq 0 ]; then
  echo "All smoke tests passed."
  exit 0
else
  echo "$FAILS smoke test(s) failed."
  exit 1
fi
