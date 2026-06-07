/// Generates a realistic, RICH synthetic patient population and loads it into the
/// REAL FHIR R4 repository in fast batch Bundles (FAST.Seed.SeedLoader.PutBundle).
/// This gives the FHIR server production-scale volume and clinical depth so the
/// cohort/population/worklist workflows are meaningful; the hand-crafted hero
/// patients are loaded separately and stay deterministic.
///
/// The population is fully DETERMINISTIC: a seeded PRNG (..Rand) replaces $random
/// and a fixed date anchor (..#ANCHORDATE) replaces $horolog, so every reseed
/// produces a byte-identical cohort. This keeps cohort prompts - and therefore the
/// bundled LLM cache keys - stable across reseeds and machines.
///
/// Locale is UK / NHS: every patient carries a valid (Mod-11 checksum) 10-digit
/// NHS number, an 8-digit hospital number, a full UK address (street, town,
/// postcode), a gendered name + title drawn from large multicultural pools (full
/// names are guaranteed unique across the cohort), plus clinical alerts (FHIR
/// Flag).
///
/// Every patient gets COMPREHENSIVE, longitudinal clinical data: a multi-problem
/// list (chronic + resolved), matched medications, a broad lab panel with trends,
/// several encounters across years, immunisations, occasional procedures, a care
/// plan, coverage, and notes. The first patients are additionally assigned to
/// SCENARIO bands so every one of the 12 agents has guaranteed, data-rich cases
/// (abnormal-result-no-followup, prior-auth, care-gap, polypharmacy, off-track
/// care plan, SDOH, trial-eligible, readmission risk, triage, lab-trend).
Class FAST.Seed.SyntheticData [ Abstract ]
{

/// Fixed "today" anchor so synthetic dates never drift with the wall clock.
Parameter ANCHORDATE = "2026-05-25";

/// Constant PRNG seed -> reproducible population on every run.
Parameter RNGSEED = 20260525;

/// Build n synthetic patients with rich, trended clinical data. Returns the total
/// number of FHIR resources created. Resources are flushed in batch Bundles.
ClassMethod Generate(n As %Integer = 1000) As %Integer
{
    do ..ClearSynthetic()
    set ^||fastrng = ..#RNGSEED
    kill ^||fastname, ^||fastcond
    // pre-count the hand-crafted hero patients' surnames so the <=2-per-surname
    // rule holds across the WHOLE 1007-patient cohort
    for fam = "Taylor", "Chen", "Okafor", "Novak", "Haddad", "Silva", "Andersson" {
        set ^||fastname("F", fam) = $get(^||fastname("F", fam), 0) + 1
    }
    set total = 0, batch = [], batchMax = 200
    do ..AddPractitioners(batch)
    for i = 1:1:n {
        do ..BuildPatient(i, batch)
        if batch.%Size() >= batchMax {
            set total = total + ##class(FAST.Seed.SeedLoader).PutBundle(batch)
            set batch = []
        }
    }
    if batch.%Size() > 0 set total = total + ##class(FAST.Seed.SeedLoader).PutBundle(batch)
    write "Generated ", total, " synthetic FHIR resources across ", n, " patients.", !
    return total
}

/// Delete any previously-seeded synthetic resources (ids starting "syn-") so a
/// reseed is idempotent and the population stays deterministic even if the
/// generator's resource set or id format changes. Hero patients (ids "pat-*") and
/// any clinician-approved drafts are left untouched.
ClassMethod ClearSynthetic()
{
    set rs = ##class(%SQL.Statement).%New().%ExecDirect(.s, "SELECT ResourceType, ResourceId FROM HSFHIR_X0001_R.Rsrc WHERE ResourceId %STARTSWITH 'syn-' AND Deleted = 0")
    set refs = []
    while rs.%Next() {
        do refs.%Push(rs.%Get("ResourceType") _ "/" _ rs.%Get("ResourceId"))
        if refs.%Size() >= 200 {
            do ##class(FAST.Seed.SeedLoader).DeleteBundle(refs)
            set refs = []
        }
    }
    if refs.%Size() > 0 do ##class(FAST.Seed.SeedLoader).DeleteBundle(refs)
}

/// Append all of one patient's resources to the batch array.
ClassMethod BuildPatient(i As %Integer, batch As %DynamicArray)
{
    set pid = "syn-pat-" _ ..Pad(i)
    set scenario = ..Scenario(i)

    // ---- demographics ----
    set gender = $select(..Rand(2): "female", 1: "male")
    set age = ..N(24, 89)
    // FLAGSHIP pin (overrides AFTER the draws, so the RNG stream is unchanged):
    // a young man with severe early-onset T2DM - the trial-matcher walkthrough
    // depends on his age failing the 40-75 trial windows
    if i = 1 set gender = "male", age = 27
    set byear = +$piece(..#ANCHORDATE, "-", 1) - age
    set name = ..UniqueName(gender)              // given$family
    set giv = $piece(name, "$", 1), fam = $piece(name, "$", 2)
    set title = $select(gender = "female": "Ms", 1: "Mr")

    set pat = {"resourceType": "Patient"}
    set pat.id = pid
    set pat.gender = gender
    set pat.birthDate = byear _ "-" _ ..Pad2(..N(1, 12)) _ "-" _ ..Pad2(..N(1, 28))
    set pat.identifier = []
    set nhs = ..NhsNumber()
    do pat.identifier.%Push({"system": "https://fhir.nhs.uk/Id/nhs-number", "value": (nhs)})
    set hosp = ..HospitalNumber()
    do pat.identifier.%Push({"system": "https://fhir.fast.health/Id/hospital-number", "value": (hosp)})
    set pat.name = [{"use": "official", "prefix": [(title)], "family": (fam), "given": [(giv)]}]
    set addr = ..Address()
    do pat.%Set("address", [(addr)])
    set pat.telecom = [{"system": "phone", "use": "home"}]
    do pat.telecom.%Get(0).%Set("value", "07" _ ..Pad2(..N(0,99)) _ " " _ ..Pad(..N(0,999)) _ ..Pad(..N(0,999)))
    // registered GP (one of the practice's named practitioners)
    set gpN = ..Rand(8) + 1
    set pat.generalPractitioner = [{"reference": ("Practitioner/syn-gp-" _ gpN), "display": (..GPName(gpN))}]
    do ..Add(batch, "Patient", pid, pat)

    // ---- comorbidity model (deterministic, scenario-influenced) ----
    set diabetic = (..Rand(100) < 42) || (scenario = "abnormal-followup") || (scenario = "prior-auth") || (scenario = "lab-trend") || (scenario = "care-gap")
    set htn      = (..Rand(100) < 38) || (scenario = "readmission") || (scenario = "polypharmacy")
    set lipid    = (..Rand(100) < 33) || (scenario = "polypharmacy")
    set ckd      = (..Rand(100) < 14) || (scenario = "readmission")
    set hf       = (..Rand(100) < 9)  || (scenario = "readmission")
    set copd     = (..Rand(100) < 11) || (scenario = "triage")
    set depr     = (..Rand(100) < 16) || (scenario = "sdoh")
    set obese    = (..Rand(100) < 28) || (scenario = "prior-auth")
    // The FLAGSHIP demo patient's profile is PINNED, not rolled: severe
    // early-onset T2DM with obesity and hyperlipidaemia (the trial-matcher,
    // med-safety and lab-explainer stories are crafted around exactly this).
    // Never let generator changes re-roll him.
    if i = 1 {
        set diabetic = 1, lipid = 1, obese = 1
        set htn = 0, ckd = 0, hf = 0, copd = 0, depr = 0
    }

    set cseq = 0, mseq = 0, oseq = 0, eseq = 0, fseq = 0, prseq = 0, imseq = 0

    // ---- problem list: scenario/comorbidity conditions (with matched meds) ----
    if diabetic { do ..AddCond(batch, pid, .cseq, "44054006", "Type 2 diabetes mellitus", "active") do ..AddMed(batch, pid, .mseq, "860975", "Metformin 1000mg twice daily", "active") }
    if htn      { do ..AddCond(batch, pid, .cseq, "59621000", "Essential hypertension", "active") do ..AddMed(batch, pid, .mseq, "314076", "Lisinopril 20mg once daily", "active") }
    if htn && (scenario = "polypharmacy") do ..AddMed(batch, pid, .mseq, "197361", "Amlodipine 5mg once daily", "active")
    if lipid    { do ..AddCond(batch, pid, .cseq, "55822004", "Hyperlipidaemia", "active") do ..AddMed(batch, pid, .mseq, "617312", "Atorvastatin 40mg at night", "active") }
    if ckd      do ..AddCond(batch, pid, .cseq, "709044004", "Chronic kidney disease stage 3", "active")
    if hf       { do ..AddCond(batch, pid, .cseq, "84114007", "Heart failure", "active") do ..AddMed(batch, pid, .mseq, "200801", "Furosemide 40mg once daily", "active") }
    if copd     { do ..AddCond(batch, pid, .cseq, "13645005", "Chronic obstructive pulmonary disease", "active") do ..AddMed(batch, pid, .mseq, "896188", "Tiotropium inhaler once daily", "active") }
    if depr     { do ..AddCond(batch, pid, .cseq, "35489007", "Depressive disorder", "active") do ..AddMed(batch, pid, .mseq, "312940", "Sertraline 50mg once daily", "active") }
    if obese    do ..AddCond(batch, pid, .cseq, "414916001", "Obesity", "active")
    if diabetic && (scenario = "prior-auth") do ..AddMed(batch, pid, .mseq, "1991302", "Empagliflozin 10mg once daily", "active")
    if (scenario = "polypharmacy") { do ..AddCond(batch, pid, .cseq, "49436004", "Atrial fibrillation", "active") do ..AddMed(batch, pid, .mseq, "1364445", "Apixaban 5mg twice daily", "active") }
    // the flagship's medication-safety drama: a recent short clarithromycin
    // course (chest infection) against his atorvastatin - a genuine, textbook
    // CYP3A4 interaction (statin myopathy risk) for the agent to catch
    if i = 1 {
        do ..AddCond(batch, pid, .cseq, "233604007", "Community-acquired pneumonia (mild)", "active")
        do ..AddMed(batch, pid, .mseq, "309342", "Clarithromycin 500mg twice daily - 7 day course", "active")
    }

    // ---- background chronic conditions so EVERY patient has a real problem list ----
    set want = ..N(2, 4)                         // each patient carries at least a few problems
    set tries = 0
    while (cseq < want) && (tries < 12) {
        set tries = tries + 1
        do ..AddBackgroundChronic(batch, pid, .cseq, .mseq)
    }
    // a couple of resolved / historical problems for longitudinal realism
    for r = 1:1:..N(1, 2) do ..AddHistory(batch, pid, .cseq)

    // ---- HbA1c series with a TREND (diabetics get 3 readings). Dates and
    // step sizes are jittered PER PATIENT so cohort queries never show the
    // tell-tale identical value+date rows of naive synthetic data ----
    if diabetic {
        set base = $select(scenario = "abnormal-followup": 96 + ..Rand(9), scenario = "lab-trend": 94 + ..Rand(7), scenario = "prior-auth": 82 + ..Rand(6), 1: 64 + ..Rand(48))
        set dir = $select(..Rand(2): -1, 1: 1)
        do ..AddObsTrend(batch, pid, .oseq, "4548-4", "Haemoglobin A1c", base, dir, "%", 1)
    } else {
        do ..AddObs(batch, pid, .oseq, "4548-4", "Haemoglobin A1c", (49 + ..Rand(14)) / 10, "%", ..RecentDate(), "")
    }
    // ---- blood pressure: a 3-reading series (rising for a third of the
    // hypertensives - real trend data for trend questions) ----
    set sys = $select(htn: ..N(138, 182), 1: ..N(108, 138))
    set dia = $select(htn: ..N(86, 104), 1: ..N(68, 86))
    set bpRising = htn && (..Rand(3) = 0)
    set bpStep1 = 4 + ..Rand(9), bpStep2 = 3 + ..Rand(8)
    set bpD1 = 300 + ..Rand(90), bpD2 = 140 + ..Rand(70), bpD3 = 5 + ..Rand(30)
    if bpRising {
        // earliest reading lowest, latest highest
        do ..AddObs(batch, pid, .oseq, "8480-6", "Systolic blood pressure", sys - bpStep1 - bpStep2, "mm[Hg]", ..DaysBeforeAnchor(bpD1), "")
        do ..AddObs(batch, pid, .oseq, "8480-6", "Systolic blood pressure", sys - bpStep2, "mm[Hg]", ..DaysBeforeAnchor(bpD2), $select((sys-bpStep2)>140:"H",1:""))
    } else {
        do ..AddObs(batch, pid, .oseq, "8480-6", "Systolic blood pressure", sys + ..Rand(11) - 5, "mm[Hg]", ..DaysBeforeAnchor(bpD1), "")
        do ..AddObs(batch, pid, .oseq, "8480-6", "Systolic blood pressure", sys + ..Rand(9) - 4, "mm[Hg]", ..DaysBeforeAnchor(bpD2), "")
    }
    do ..AddObs(batch, pid, .oseq, "8480-6", "Systolic blood pressure", sys, "mm[Hg]", ..DaysBeforeAnchor(bpD3), $select(sys>140:"H",1:""))
    do ..AddObs(batch, pid, .oseq, "8462-4", "Diastolic blood pressure", dia, "mm[Hg]", ..DaysBeforeAnchor(bpD3), $select(dia>90:"H",1:""))
    // ---- body habitus ----
    set bmi = $select(obese: (300 + ..Rand(120)), 1: (200 + ..Rand(90))) / 10
    do ..AddObs(batch, pid, .oseq, "39156-5", "Body mass index", bmi, "kg/m2", ..RecentDate(), $select(bmi>30:"H",1:""))
    set wt = (520 + (bmi * 17) + ..Rand(80)) / 10            // plausible kg from BMI
    do ..AddObs(batch, pid, .oseq, "29463-7", "Body weight", wt, "kg", ..RecentDate(), "")
    // ---- full lipid panel (internally coherent: total ~= LDL + HDL + trig/5) ----
    set ldl = $select(lipid: ..N(130, 205), 1: ..N(70, 130))
    set hdl = ..N(33, 68)
    set trig = $select(diabetic || obese: ..N(150, 320), 1: ..N(80, 190))
    set tchol = ldl + hdl + (trig \ 5)
    do ..AddObs(batch, pid, .oseq, "13457-7", "LDL cholesterol", ldl, "mg/dL", ..RecentDate(), $select(ldl>130:"H",1:""))
    do ..AddObs(batch, pid, .oseq, "2085-9", "HDL cholesterol", hdl, "mg/dL", ..RecentDate(), $select(hdl<40:"L",1:""))
    do ..AddObs(batch, pid, .oseq, "2571-8", "Triglycerides", trig, "mg/dL", ..RecentDate(), $select(trig>200:"H",1:""))
    do ..AddObs(batch, pid, .oseq, "2093-3", "Total cholesterol", tchol, "mg/dL", ..RecentDate(), $select(tchol>240:"H",1:""))
    // ---- renal + metabolic ----
    set egfr = $select(ckd: ..N(22, 58), 1: ..N(62, 110))
    do ..AddObs(batch, pid, .oseq, "33914-3", "eGFR", egfr, "mL/min/1.73m2", ..RecentDate(), $select(egfr<60:"L",1:""))
    set creat = $select(ckd: (140 + ..Rand(120)) / 100, 1: (70 + ..Rand(50)) / 100)
    do ..AddObs(batch, pid, .oseq, "2160-0", "Creatinine", creat, "mg/dL", ..RecentDate(), $select(creat>1.3:"H",1:""))
    set urea = $select(ckd: (80 + ..Rand(80)) / 10, 1: (30 + ..Rand(45)) / 10)
    do ..AddObs(batch, pid, .oseq, "22664-7", "Urea", urea, "mmol/L", ..RecentDate(), $select(urea>7.8:"H",1:""))
    set gluc = $select(diabetic: (70 + ..Rand(85)) / 10, 1: (42 + ..Rand(23)) / 10)
    do ..AddObs(batch, pid, .oseq, "1558-6", "Fasting glucose", gluc, "mmol/L", ..RecentDate(), $select(gluc>7:"H",1:""))
    // ---- broader panel (everyone) ----
    set hb = (110 + ..Rand(50)) / 10
    do ..AddObs(batch, pid, .oseq, "718-7", "Haemoglobin", hb, "g/dL", ..RecentDate(), $select(hb<12:"L",1:""))
    set tsh = (5 + ..Rand(60)) / 10
    do ..AddObs(batch, pid, .oseq, "3016-3", "TSH", tsh, "mIU/L", ..RecentDate(), $select(tsh>4:"H",1:""))
    do ..AddObs(batch, pid, .oseq, "2951-2", "Sodium", ..N(134, 144), "mmol/L", ..RecentDate(), "")
    do ..AddObs(batch, pid, .oseq, "2823-3", "Potassium", (35 + ..Rand(13)) / 10, "mmol/L", ..RecentDate(), "")
    do ..AddObs(batch, pid, .oseq, "1742-6", "ALT", ..N(12, 55), "U/L", ..RecentDate(), "")
    // ---- smoking status (text-valued, like real records) ----
    do ..AddTextObs(batch, pid, .oseq, "72166-2", "Tobacco smoking status", ..SmokingStatus(copd))

    // ---- diagnostic report tying labs together ----
    do ..Add(batch, "DiagnosticReport", pid_"-dr1", ..DiagReport(pid))

    // ---- a MedicationStatement (adherence) when on therapy ----
    if mseq > 0 do ..Add(batch, "MedicationStatement", pid_"-ms1", ..MedStatement(pid))

    // ---- allergies (about half of patients; can be multiple) ----
    if ..Rand(100) < 48 do ..AddAllergy(batch, pid, 1)
    if ..Rand(100) < 18 do ..AddAllergy(batch, pid, 2)

    // ---- encounters: longitudinal history + scenario-specific acute care ----
    do ..AddEnc(batch, pid, .eseq, "AMB", "Annual chronic disease review", ..DaysBeforeAnchor(..N(330, 420)), "finished")
    do ..AddEnc(batch, pid, .eseq, "AMB", "Medication review", ..DaysBeforeAnchor(..N(170, 260)), "finished")
    if (scenario = "readmission") {
        do ..AddEnc(batch, pid, .eseq, "IMP", "Inpatient admission - acute decompensated heart failure", ..DaysBeforeAnchor(48), "finished")
        // the last two band members are the genuinely LOW-risk discharges: an
        // uneventful recovery, no return to the emergency department
        if (i - 84) <= 10 do ..AddEnc(batch, pid, .eseq, "EMER", "Emergency attendance - breathlessness", ..DaysBeforeAnchor(12), "finished")
    } elseif (scenario = "triage") {
        do ..AddEnc(batch, pid, .eseq, "EMER", "Emergency attendance - in progress", ..DaysBeforeAnchor(1), "in-progress")
    } else {
        do ..AddEnc(batch, pid, .eseq, "AMB", ..PickEncReason(), ..RecentDate(), "finished")
    }

    // ---- immunisations (care-gap scenario deliberately overdue -> no recent flu) ----
    if (scenario '= "care-gap") do ..AddImm(batch, pid, .imseq, "158", "Influenza vaccine", ..DaysBeforeAnchor(..N(180, 240)))
    if ..Rand(100) < 60 do ..AddImm(batch, pid, .imseq, "133", "Pneumococcal vaccine", ..DaysBeforeAnchor(..N(400, 900)))
    if ..Rand(100) < 70 do ..AddImm(batch, pid, .imseq, "213", "COVID-19 vaccine", ..DaysBeforeAnchor(..N(150, 320)))

    // ---- occasional procedure for longitudinal richness ----
    if ..Rand(100) < 35 do ..AddProcedure(batch, pid, .prseq)

    // ---- care plan + goal for chronic patients (off-track for the navigator scenario) ----
    if (diabetic || htn || hf || ckd) {
        do ..Add(batch, "CarePlan", pid_"-cp1", ..CarePlan(pid, $select(scenario="careplan":"on-hold", 1:"active")))
        do ..Add(batch, "Goal", pid_"-goal1", ..Goal(pid, $select(scenario="careplan":"in-progress", 1:"improving")))
    }

    // ---- coverage (everyone) ----
    do ..Add(batch, "Coverage", pid_"-cov1", ..Coverage(pid, i))

    // ---- clinical alerts (FHIR Flag) for a subset; some scenarios always flagged ----
    // (sdoh band patients get a screening-specific flag in AddSdohExtras instead;
    // the two low-risk discharges at the end of the readmission band get no flag)
    if (scenario = "readmission") && ((i - 84) <= 10) do ..AddFlag(batch, pid, .fseq, "clinical", "High readmission risk")
    if ..Rand(100) < 32 do ..AddFlag(batch, pid, .fseq, ..PickFlag())
    if ..Rand(100) < 12 do ..AddFlag(batch, pid, .fseq, ..PickFlag())

    // ---- scenario-specific extras ----
    if (scenario = "prior-auth") do ..Add(batch, "ServiceRequest", pid_"-sr1", ..ServiceRequest(pid, "GLP-1 receptor agonist therapy"))
    if (scenario = "trial") do ..Add(batch, "ServiceRequest", pid_"-sr1", ..ServiceRequest(pid, "Oncology referral"))
    // upcoming appointment - never for abnormal-followup (its open loop must stay open)
    if (scenario '= "abnormal-followup") && (..Rand(100) < 55) do ..Add(batch, "Appointment", pid_"-ap1", ..Appointment(pid, ..DaysAfterAnchor(..N(7, 60))))
    // a clinical note document for richness
    if (..Rand(100) < 45) do ..Add(batch, "DocumentReference", pid_"-doc1", ..DocRef(pid))

    // ---- Social-needs screening + DNA history (appended LAST and derived only
    // from the patient index - consumes NO ..Rand draws, so every other patient
    // stays byte-identical and the bundled LLM cache keeps hitting). Covers the
    // sdoh band AND the patient-portal demo cohort (syn-pat-0001..0012), so every
    // portal patient has a grounded "Local support" offer. ----
    if (scenario = "sdoh") || (i <= 12) do ..AddSdohExtras(batch, pid, i)

    // ---- Trial band: bespoke trial-ready data for two demo patients (appended
    // LAST, fixed dates, NO ..Rand draws - same byte-identity rule as above) ----
    if (scenario = "trial") do ..AddTrialExtras(batch, pid, i)

    // ---- Readmission band: graded post-discharge risk signals (appended LAST,
    // fixed values/dates, NO ..Rand draws) so the risk worklist ranks a real
    // high / moderate / low spread ----
    if (scenario = "readmission") do ..AddReadmissionExtras(batch, pid, i)

    // ---- Results follow-up cohort: imaging findings in every loop state
    // (appended LAST, fixed values/dates, NO ..Rand draws) ----
    if (i >= 2) && (i <= 4) do ..AddResultsExtras(batch, pid, i)

    // ---- hand-written clinical notes for the demo-hero charts ----
    if (i = 1) || (i = 3) || (i = 61) || (i = 85) || (i = 97) do ..AddHeroNote(batch, pid, i)
}

/// A realistic free-text clinical note (DocumentReference) for each demo hero -
/// the depth judges drill into, and real unstructured evidence the agents
/// (e.g. the trial matcher) can genuinely read.
ClassMethod AddHeroNote(batch As %DynamicArray, pid As %String, i As %Integer)
{
    if i = 1 {
        set type = "GP consultation note", days = 4
        set txt = "Diabetes review + acute visit. Type 2 diabetes remains poorly controlled despite metformin 1g bd - latest HbA1c well above target and trending up. "
            _ "Completed the 6-month dietitian-led weight management programme last year without sustained weight loss; weight stable, BMI remains in the obese range. "
            _ "Today also presents with productive cough and fever - chest clinically consistent with mild community-acquired pneumonia, started clarithromycin 500mg bd for 7 days (NB on atorvastatin - counselled re muscle aches, consider statin pause if myalgia). "
            _ "Plan: repeat HbA1c and fasting lipids in 6 weeks, discuss treatment intensification options at next review, safety-netting advice given."
    } elseif i = 3 {
        set type = "Breast screening recall letter (copy)", days = 22
        set txt = "Copy of recall correspondence: recent screening mammogram showed suspicious calcifications in the left breast (BI-RADS 4). "
            _ "Assessment clinic appointment offered for further views and possible core biopsy - recommended within two weeks of the screening report. "
            _ "Patient to be contacted by the breast unit; GP copy filed."
    } elseif i = 61 {
        set type = "GP consultation note", days = 9
        set txt = "Long consultation. Mood low-normal; main stressors are practical: reports skipping meals towards the end of the month so the children can eat, "
            _ "has missed two clinic appointments this year because of transport difficulty, and admits stretching his tablets to every other day until payday. "
            _ "Social-needs screening completed today. Plan: social prescribing referral discussed and welcomed; continue current medication; review in 4 weeks."
    } elseif i = 85 {
        set type = "Hospital discharge summary", days = 46
        set txt = "Admission with acute decompensated heart failure: presented with worsening breathlessness, orthopnoea and 4kg weight gain over two weeks. "
            _ "Treated with IV furosemide with good diuresis; discharge weight 79.1kg. Echo during admission: globally impaired systolic function. "
            _ "Medication changes: furosemide increased to 40mg od, carvedilol and spironolactone continued. "
            _ "Discharge plan: daily weights (report gain over 2kg in 3 days), community heart failure nurse referral, bloods incl. renal profile and BNP in 2 weeks, cardiology clinic in 6 weeks."
    } else {
        set type = "Emergency department note (previous attendance)", days = 80
        set txt = "Previous ED attendance with breathlessness on background of COPD: treated with nebulised bronchodilators and a short course of oral steroids, discharged same day. "
            _ "Advised on inhaler technique and smoking cessation referral; declined cessation support on that occasion. Safety-netting advice given."
    }
    set dr = {"resourceType": "DocumentReference", "status": "current"}
    set dr.id = pid _ "-note1"
    set dr.type = {"text": (type)}
    set dr.subject = {"reference": ("Patient/" _ pid)}
    set dr.date = ..DaysBeforeAnchor(days) _ "T10:30:00Z"
    set dr.description = txt
    // content[] is REQUIRED in R4 - without it the FHIR server rejects the resource
    set dr.content = [{"attachment": {"contentType": "text/plain", "title": (type), "data": ($system.Encryption.Base64Encode($zconvert(txt, "O", "UTF8")))}}]
    do ..Add(batch, "DocumentReference", dr.id, dr)
}

/// Imaging findings for the Results Follow-Up Tracker, one loop state each:
/// 0003 (female) a BI-RADS 4 mammogram with NO documented follow-up (overdue),
/// 0002 a pulmonary nodule WITH a planned follow-up CT (pending), 0004 an
/// abnormal renal ultrasound whose follow-up was COMPLETED (closed). The hero
/// patient pat-abnormal-001 stays the pure open-lab case. NO ..Rand/..N.
ClassMethod AddResultsExtras(batch As %DynamicArray, pid As %String, i As %Integer)
{
    if i = 2 {
        do ..AddImagingReport(batch, pid, "Chest X-ray", "8mm pulmonary nodule in the right upper lobe - CT follow-up recommended within 3 months", ..DaysBeforeAnchor(18))
        set s = {"resourceType": "ServiceRequest", "status": "active", "intent": "order"}
        set s.id = pid _ "-trsr1"
        set s.code = {"text": "CT chest - pulmonary nodule follow-up"}
        set s.subject = {"reference": ("Patient/" _ pid)}
        set s.authoredOn = ..DaysBeforeAnchor(15)
        do ..Add(batch, "ServiceRequest", s.id, s)
    }
    if i = 3 {
        do ..AddImagingReport(batch, pid, "Screening mammogram", "Suspicious calcifications in the left breast (BI-RADS 4) - biopsy recommended within 2 weeks", ..DaysBeforeAnchor(24))
    }
    if i = 4 {
        do ..AddImagingReport(batch, pid, "Renal ultrasound", "Mild bilateral renal cortical thinning - repeat renal function testing advised", ..DaysBeforeAnchor(60))
        set t = {"resourceType": "Task", "status": "completed", "intent": "order", "priority": "routine"}
        set t.id = pid _ "-trtk1"
        set t.description = "Repeat renal function tests following abnormal ultrasound"
        set t.for = {"reference": ("Patient/" _ pid)}
        set t.authoredOn = ..DaysBeforeAnchor(55)
        set t.restriction = {"period": {"end": (..DaysBeforeAnchor(30))}}
        do ..Add(batch, "Task", t.id, t)
    }
}

ClassMethod AddImagingReport(batch As %DynamicArray, pid As %String, name As %String, conclusion As %String, date As %String)
{
    set dr = {"resourceType": "DiagnosticReport", "status": "final"}
    set dr.id = pid _ "-trdr1"
    set dr.code = {"text": (name)}
    set dr.subject = {"reference": ("Patient/" _ pid)}
    set dr.effectiveDateTime = date
    set dr.conclusion = conclusion
    do ..Add(batch, "DiagnosticReport", dr.id, dr)
}

/// Classic readmission-risk signals for the discharge band (syn-pat-0085..0096),
/// graded by band index b so the worklist has genuine spread: everyone gets a
/// BNP (850 falling to ~150 across the band), the sicker half (b<=6) a clearly
/// RISING second creatinine (2.4+, above the random first reading's 2.6 max only
/// for b<=3 - values chosen so the trend reads worsening for the top of the
/// band), the top three a second heart-failure admission, and the top two
/// HF polypharmacy (carvedilol + spironolactone). MUST NOT call ..Rand/..N.
ClassMethod AddReadmissionExtras(batch As %DynamicArray, pid As %String, i As %Integer)
{
    set b = i - 84                                  // 1..12 within the band
    set seq = 75
    // B-type natriuretic peptide, graded: b=1 -> 850 falling across the band;
    // the two low-risk discharges (b 11-12) get a NORMAL value (ref < 100)
    set bnp = $select(b <= 10: 910 - (b * 60), 1: 85 - ((b - 11) * 20))
    do ..AddObs(batch, pid, .seq, "42637-9", "BNP (B-type natriuretic peptide)", bnp, "pg/mL", ..DaysBeforeAnchor(8 + b), $select(bnp >= 400: "HH", bnp >= 100: "H", 1: ""))
    // rising creatinine for the sicker half: a recent value above their baseline
    if b <= 6 {
        set creat = (32 - b) / 10                   // 3.1, 3.0, 2.9, 2.8, 2.7, 2.6
        do ..AddObs(batch, pid, .seq, "2160-0", "Creatinine", creat, "mg/dL", ..DaysBeforeAnchor(5 + b), "H")
    }
    // a SECOND recent HF admission for the highest-risk three
    if b <= 3 {
        set dnaseq = 86
        do ..AddEnc(batch, pid, .dnaseq, "IMP", "Inpatient admission - heart failure exacerbation", ..DaysBeforeAnchor(28 + b), "finished")
    }
    // a rising WEIGHT series for the sicker half - the classic fluid-overload
    // signal after a heart-failure discharge (fixed values, oldest first)
    if b <= 6 {
        set baseWt = 780 + (b * 13)                  // 79.3 .. 84.8 kg x10
        do ..AddObs(batch, pid, .seq, "29463-7", "Body weight", (baseWt) / 10, "kg", ..DaysBeforeAnchor(20 + b), "")
        do ..AddObs(batch, pid, .seq, "29463-7", "Body weight", (baseWt + 14) / 10, "kg", ..DaysBeforeAnchor(11 + b), "")
        do ..AddObs(batch, pid, .seq, "29463-7", "Body weight", (baseWt + 31) / 10, "kg", ..DaysBeforeAnchor(3 + b), "H")
    }
    // HF polypharmacy for the top two
    if b <= 2 {
        for med = "200033$Carvedilol 6.25mg twice daily", "313096$Spironolactone 25mg once daily" {
            set m = {"resourceType": "MedicationRequest", "intent": "order", "status": "active"}
            set m.id = pid _ "-rxm" _ $extract($piece(med, "$", 1), 1, 3)
            set m.medicationCodeableConcept = {"coding": [{"system": "http://www.nlm.nih.gov/research/umls/rxnorm", "code": ($piece(med, "$", 1)), "display": ($piece(med, "$", 2))}], "text": ($piece(med, "$", 2))}
            set m.subject = {"reference": ("Patient/" _ pid)}
            set m.authoredOn = ..DaysBeforeAnchor(40 + b)
            do ..Add(batch, "MedicationRequest", m.id, m)
        }
    }
}

/// Bespoke clinical extras that make specific trial-band patients clean demo
/// matches for the trial registry. 0075 (T2DM + HTN) becomes the GLP-1 washout
/// case: obesity + BMI 38.2 + CURRENT semaglutide (excluded by METABOLIC-WT,
/// permitted by SHAPE-UP). 0073 (CKD stage 3 + hyperlipidaemia after the 2026-06
/// name-pool re-roll) gets the recent eGFR and potassium that NEPHRO-GUARD's
/// criteria ask for, alongside his natural LIPID-REACH fit. 0102 (HTN + CKD +
/// COPD) is a natural multi-trial candidate with no extras. MUST NOT call ..Rand/..N.
ClassMethod AddTrialExtras(batch As %DynamicArray, pid As %String, i As %Integer)
{
    if i = 75 {
        set c = {"resourceType": "Condition"}
        set c.id = pid _ "-trc1"
        set c.clinicalStatus = {"coding": [{"system": "http://terminology.hl7.org/CodeSystem/condition-clinical", "code": "active"}]}
        set c.code = {"coding": [{"system": "http://snomed.info/sct", "code": "414916001", "display": "Obesity"}], "text": "Obesity"}
        set c.subject = {"reference": ("Patient/" _ pid)}
        set c.recordedDate = ..DaysBeforeAnchor(700)
        do ..Add(batch, "Condition", c.id, c)
        set seq = 70
        do ..AddObs(batch, pid, .seq, "39156-5", "Body mass index", 38.2, "kg/m2", ..DaysBeforeAnchor(9), "H")
        set m = {"resourceType": "MedicationRequest", "intent": "order", "status": "active"}
        set m.id = pid _ "-trm1"
        set m.medicationCodeableConcept = {"coding": [{"system": "http://www.nlm.nih.gov/research/umls/rxnorm", "code": "1991302", "display": "Semaglutide 1mg once weekly injection"}], "text": "Semaglutide 1mg once weekly injection"}
        set m.subject = {"reference": ("Patient/" _ pid)}
        set m.authoredOn = ..DaysBeforeAnchor(120)
        do ..Add(batch, "MedicationRequest", m.id, m)
    }
    if i = 73 {
        set seq = 70
        do ..AddObs(batch, pid, .seq, "33914-3", "eGFR", 47, "mL/min/1.73m2", ..DaysBeforeAnchor(12), "L")
        do ..AddObs(batch, pid, .seq, "2823-3", "Potassium", 4.6, "mmol/L", ..DaysBeforeAnchor(12), "")
    }
}

/// Social-needs screening (QuestionnaireResponse), a screening Flag, and - for
/// patients reporting transport barriers - two DNA'd (cancelled) encounters.
/// Everything here is derived deterministically from the band index b; this method
/// MUST NOT call ..Rand/..N (see BuildPatient call-site comment).
ClassMethod AddSdohExtras(batch As %DynamicArray, pid As %String, i As %Integer)
{
    if i <= 12 {
        // patient-portal demo cohort. syn-pat-0001 (the flagship) deliberately has
        // NO transport need: transport adds DNA'd Encounters, and Encounter is in
        // the smart-summary / gaps evidence - keeping it out preserves the
        // flagship's existing cache entries.
        set b = i
        set pattern = $case(b,
            1: "food,money",
            2: "transport,medcost",
            3: "loneliness,mental",
            4: "housing,fuel",
            5: "food,loneliness",
            6: "transport,digital",
            7: "money,carer",
            8: "fuel,food",
            9: "housing,mental",
            10: "loneliness,transport",
            11: "money,medcost",
            : "food,transport")
    } else {
        set b = i - 60                              // 1..12 within the sdoh band
        // positive-domain pattern per band member; hero (b=1, syn-pat-0061) = food + transport + medication cost
        set pattern = $case(b,
            1: "food,transport,medcost",
            2: "housing,fuel",
            3: "loneliness,transport",
            4: "food,money",
            5: "housing,mental",
            6: "transport,digital",
            7: "food,loneliness",
            8: "money,carer",
            9: "fuel,food",
            10: "loneliness,mental",
            11: "transport,money",
            : "housing,food")
    }

    set qr = {"resourceType": "QuestionnaireResponse", "status": "completed"}
    set qr.id = pid _ "-qr1"
    set qr.questionnaire = "https://fhir.fast.health/Questionnaire/social-needs-screening"
    set qr.subject = {"reference": ("Patient/" _ pid)}
    set qr.authored = ..DaysBeforeAnchor(6 + b)
    set qr.item = []
    // the bespoke patient-voice lines belong to the sdoh-band hero only (b=1
    // there); portal-cohort patients always use the generic voice (bes=0)
    set bes = $select(i <= 12: 0, 1: b)
    for d = "food", "transport", "housing", "fuel", "medcost", "money", "loneliness", "mental", "carer", "digital" {
        set pos = (("," _ pattern _ ",") [ ("," _ d _ ","))
        set q = ..SdohQuestion(d), a = $select(pos: ..SdohPositive(d, bes), 1: ..SdohNegative(d))
        do qr.item.%Push({"linkId": (d), "text": (q), "answer": [{"valueString": (a)}]})
    }
    do ..Add(batch, "QuestionnaireResponse", qr.id, qr)

    // screening flag naming the positive domains (replaces the old generic one)
    set fl = 8
    do ..AddFlag(batch, pid, .fl, "safety", "Social needs identified on screening: " _ $replace(pattern, ",", ", "))

    // transport-positive patients carry a real DNA history (the inferred signal)
    if pattern [ "transport" {
        set dnaseq = 80
        do ..AddEnc(batch, pid, .dnaseq, "AMB", "Did not attend - transport difficulty", ..DaysBeforeAnchor(40 + b), "cancelled")
        do ..AddEnc(batch, pid, .dnaseq, "AMB", "Did not attend - transport difficulty", ..DaysBeforeAnchor(95 + b), "cancelled")
    }
}

/// Screening question text per social-needs domain.
ClassMethod SdohQuestion(d As %String) As %String
{
    return $case(d,
        "food": "In the last 3 months, did you ever worry about running out of food before you had money to buy more?",
        "transport": "Has a lack of reliable transport kept you from medical appointments or from getting your medicines?",
        "housing": "Are you worried about your current housing situation?",
        "fuel": "In the last 12 months, have you struggled to pay your gas or electricity bills?",
        "medcost": "Do you ever delay or skip taking your medicines because of the cost?",
        "money": "Do money worries make it hard to manage day to day?",
        "loneliness": "How often do you feel lonely or cut off from other people?",
        "mental": "Over the last 2 weeks, how often have you felt down, low or hopeless?",
        "carer": "Do you look after a family member or friend who could not manage without you?",
        : "Can you use the internet to book appointments or order repeat prescriptions?")
}

/// Patient-voice answer for a POSITIVE screen. The hero patient (b=1) gets
/// bespoke wording the demo leans on; others share a realistic generic voice.
ClassMethod SdohPositive(d As %String, b As %Integer) As %String
{
    if b = 1 {
        if d = "food" return "Yes - by the end of the month I'm often skipping meals so the kids can eat properly."
        if d = "transport" return "Yes. I've missed two clinic appointments this year because I can't always get a lift and the buses don't go near the surgery."
        if d = "medcost" return "Sometimes I make my tablets stretch by taking them every other day until payday."
    }
    return $case(d,
        "food": "Yes - towards the end of the month I often skip meals so there's enough for the rest of the family.",
        "transport": "Yes. I've missed appointments before because I couldn't get a lift and the bus doesn't go near the surgery.",
        "housing": "Yes - our landlord is selling up and I don't know where we'll go.",
        "fuel": "Yes, we only heat one room in winter and I've gone without to keep the meter topped up.",
        "medcost": "Sometimes I make my tablets stretch by taking them every other day.",
        "money": "Yes - once the bills are paid there's hardly anything left for the week.",
        "loneliness": "Most days. I can go the best part of a week without really speaking to anyone.",
        "mental": "More days than not, if I'm honest. Everything feels like a struggle at the moment.",
        "carer": "Yes, I look after my mum every day - I can't leave her for long.",
        : "No - I don't have the internet at home and I wouldn't know where to start.")
}

/// Short answer for a NEGATIVE screen.
ClassMethod SdohNegative(d As %String) As %String
{
    return $case(d,
        "food": "No",
        "transport": "No, I can usually get there",
        "housing": "No, we're settled",
        "fuel": "No",
        "medcost": "No, I always take them",
        "money": "Not really",
        "loneliness": "Hardly ever",
        "mental": "Not at all",
        "carer": "No",
        : "Yes, I manage fine online")
}

/// Scenario band for the first patients so each agent has guaranteed cases. After
/// the reserved bands, patients are general background population.
ClassMethod Scenario(i As %Integer) As %String
{
    if i <= 12 return "abnormal-followup"
    if i <= 24 return "prior-auth"
    if i <= 36 return "care-gap"
    if i <= 48 return "polypharmacy"
    if i <= 60 return "careplan"
    if i <= 72 return "sdoh"
    if i <= 84 return "trial"
    if i <= 96 return "readmission"
    if i <= 108 return "triage"
    if i <= 120 return "lab-trend"
    return "general"
}

// ---- resource builders ----

ClassMethod AddCond(batch As %DynamicArray, pid As %String, ByRef cseq, code, display, status As %String = "active")
{
    set cseq = cseq + 1
    set c = {"resourceType": "Condition"}
    set c.id = pid _ "-c" _ cseq
    set c.clinicalStatus = {"coding": [{"system": "http://terminology.hl7.org/CodeSystem/condition-clinical", "code": (status)}]}
    set c.code = {"coding": [{"system": "http://snomed.info/sct", "code": (code), "display": (display)}], "text": (display)}
    set c.subject = {"reference": ("Patient/" _ pid)}
    set c.recordedDate = $select(status = "resolved": ..OldDate(), 1: ..DaysBeforeAnchor(..N(120, 1400)))
    do ..Add(batch, "Condition", c.id, c)
}

/// Draw one background chronic condition (deterministic, no duplicates within a
/// patient) and, where appropriate, its matched medication.
ClassMethod AddBackgroundChronic(batch As %DynamicArray, pid As %String, ByRef cseq, ByRef mseq)
{
    set lB = ..BACKGROUND()
    set pick = $list(lB, ..Rand($listlength(lB)) + 1)
    set code = $piece(pick, "$", 1), disp = $piece(pick, "$", 2)
    set rx = $piece(pick, "$", 3), med = $piece(pick, "$", 4)
    // skip if this patient already has this condition code
    if $data(^||fastcond(pid, code)) quit
    set ^||fastcond(pid, code) = 1
    do ..AddCond(batch, pid, .cseq, code, disp, "active")
    if rx '= "" do ..AddMed(batch, pid, .mseq, rx, med, "active")
}

ClassMethod AddHistory(batch As %DynamicArray, pid As %String, ByRef cseq)
{
    set lH = ..HISTORY()
    set pick = $list(lH, ..Rand($listlength(lH)) + 1)
    do ..AddCond(batch, pid, .cseq, $piece(pick, "$", 1), $piece(pick, "$", 2), "resolved")
}

ClassMethod AddObs(batch As %DynamicArray, pid As %String, ByRef oseq, loinc, display, value, unit, date, interp)
{
    set oseq = oseq + 1
    do ..Add(batch, "Observation", pid _ "-o" _ oseq, ..Obs(pid, oseq, loinc, display, value, unit, date, interp))
}

/// Three readings of one analyte across time to show a trend. base is valuex10
/// (integer); dir is +1 (worsening) / -1 (improving). The most recent reading is
/// `recentHigh`-flagged if it is markedly elevated.
ClassMethod AddObsTrend(batch As %DynamicArray, pid As %String, ByRef oseq, loinc, display, base, dir, unit, recentHigh)
{
    // per-patient jittered dates and step sizes - no two patients share the
    // same reading dates, and trend magnitudes vary realistically
    set s1 = 3 + ..Rand(8), s2 = 3 + ..Rand(8)
    set d1 = 360 + ..Rand(120), d2 = 160 + ..Rand(90), d3 = 5 + ..Rand(40)
    set v1 = base / 10
    set v2 = (base + (dir * s1)) / 10
    set v3 = (base + (dir * (s1 + s2))) / 10
    do ..AddObs(batch, pid, .oseq, loinc, display, v1, unit, ..DaysBeforeAnchor(d1), $select(v1>9:"H",1:""))
    do ..AddObs(batch, pid, .oseq, loinc, display, v2, unit, ..DaysBeforeAnchor(d2), $select(v2>9:"H",1:""))
    do ..AddObs(batch, pid, .oseq, loinc, display, v3, unit, ..DaysBeforeAnchor(d3), $select(v3>9:"HH",v3>5.6:"H",1:""))
}

/// The practice's eight named GPs (real Practitioner resources).
ClassMethod GPName(n As %Integer) As %String
{
    set l = $listbuild("Dr Priya Sharma", "Dr James Whitfield", "Dr Amara Diallo", "Dr Tomasz Zielinski", "Dr Helen Carmichael", "Dr Rajan Mehta", "Dr Fiona MacLeod", "Dr Samuel Adeyemi")
    return $list(l, n)
}

ClassMethod AddPractitioners(batch As %DynamicArray)
{
    for n = 1:1:8 {
        set name = ..GPName(n)
        set pr = {"resourceType": "Practitioner"}
        set pr.id = "syn-gp-" _ n
        set fam = $piece(name, " ", *), giv = $piece(name, " ", 2)
        set pr.name = [{"use": "official", "prefix": ["Dr"], "family": (fam), "given": [(giv)]}]
        do ..Add(batch, "Practitioner", pr.id, pr)
    }
}

/// A text-valued Observation (e.g. smoking status).
ClassMethod AddTextObs(batch As %DynamicArray, pid As %String, ByRef oseq, loinc As %String, display As %String, value As %String)
{
    set oseq = oseq + 1
    set o = {"resourceType": "Observation", "status": "final"}
    set o.id = pid _ "-o" _ oseq
    set o.code = {"coding": [{"system": "http://loinc.org", "code": (loinc), "display": (display)}], "text": (display)}
    set o.subject = {"reference": ("Patient/" _ pid)}
    set o.effectiveDateTime = ..RecentDate()
    set o.valueString = value
    do ..Add(batch, "Observation", o.id, o)
}

/// A realistic smoking status; COPD patients skew current/ex with pack-years.
ClassMethod SmokingStatus(copd As %Boolean) As %String
{
    if copd {
        set l = $listbuild("Current smoker - about 20 cigarettes a day, 30 pack-years", "Current smoker - roll-ups, 25 pack-years", "Ex-smoker - quit 2021, 35 pack-years", "Ex-smoker - quit 2018, 40 pack-years")
        return $list(l, ..Rand($listlength(l)) + 1)
    }
    set l = $listbuild("Never smoked", "Never smoked", "Never smoked", "Ex-smoker - quit 2015, 8 pack-years", "Ex-smoker - quit 2020, 5 pack-years", "Current smoker - about 10 cigarettes a day, 12 pack-years", "Current smoker - social smoker, under 5 a day")
    return $list(l, ..Rand($listlength(l)) + 1)
}

ClassMethod Obs(pid As %String, seq As %Integer, loinc As %String, display As %String, value As %Numeric, unit As %String, date As %String, interp As %String) As %DynamicObject
{
    set o = {"resourceType": "Observation", "status": "final"}
    set o.id = pid _ "-o" _ seq
    set o.category = [{"coding": [{"system": "http://terminology.hl7.org/CodeSystem/observation-category", "code": "laboratory"}]}]
    set o.code = {"coding": [{"system": "http://loinc.org", "code": (loinc), "display": (display)}], "text": (display)}
    set o.subject = {"reference": ("Patient/" _ pid)}
    set o.effectiveDateTime = date
    set o.valueQuantity = {"unit": (unit), "system": "http://unitsofmeasure.org", "code": (unit)}
    do o.valueQuantity.%Set("value", value)
    if interp '= "" {
        set o.interpretation = [{"coding": [{"system": "http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation", "code": (interp)}]}]
    }
    return o
}

ClassMethod AddMed(batch As %DynamicArray, pid As %String, ByRef mseq, code, display, status)
{
    set mseq = mseq + 1
    set m = {"resourceType": "MedicationRequest", "intent": "order"}
    set m.id = pid _ "-m" _ mseq
    set m.status = status
    set m.medicationCodeableConcept = {"coding": [{"system": "http://www.nlm.nih.gov/research/umls/rxnorm", "code": (code), "display": (display)}], "text": (display)}
    set m.subject = {"reference": ("Patient/" _ pid)}
    set m.authoredOn = ..DaysBeforeAnchor(..N(60, 900))
    do ..Add(batch, "MedicationRequest", m.id, m)
}

ClassMethod MedStatement(pid As %String) As %DynamicObject
{
    set l = $listbuild(
        "Takes all medicines as prescribed; uses a weekly dosette box",
        "Mostly adherent; admits to occasionally missing the evening dose",
        "Takes medicines as prescribed; collects repeat prescriptions on time",
        "Adherence variable - sometimes stops tablets when feeling well",
        "Uses a pharmacy blister pack; family member prompts daily doses",
        "Self-manages medicines; keeps an up-to-date list in their phone")
    set m = {"resourceType": "MedicationStatement", "status": "active"}
    set m.id = pid _ "-ms1"
    set m.medicationCodeableConcept = {"text": ("Medication adherence: " _ $list(l, ..Rand($listlength(l)) + 1))}
    set m.subject = {"reference": ("Patient/" _ pid)}
    set m.dateAsserted = ..RecentDate()
    return m
}

ClassMethod AddAllergy(batch As %DynamicArray, pid As %String, seq As %Integer)
{
    set opts = $listbuild("Penicillin", "Sulfonamide antibiotics", "Aspirin", "Codeine", "Peanut", "Latex", "Shellfish", "Iodinated contrast media")
    // deterministic distinct-ish pick per sequence slot
    set idx = (..Rand($listlength(opts))) + 1
    set a = {"resourceType": "AllergyIntolerance"}
    set a.id = pid _ "-al" _ seq
    set a.clinicalStatus = {"coding": [{"system": "http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical", "code": "active"}]}
    set a.code = {"text": ($list(opts, idx))}
    set a.patient = {"reference": ("Patient/" _ pid)}
    set a.criticality = $select(..Rand(2): "high", 1: "low")
    set a.reaction = [{"manifestation": [{"text": ($select(..Rand(2): "Rash / urticaria", 1: "Anaphylaxis"))}]}]
    do ..Add(batch, "AllergyIntolerance", a.id, a)
}

ClassMethod AddEnc(batch As %DynamicArray, pid As %String, ByRef eseq, classCode, reason, date, status)
{
    set eseq = eseq + 1
    set e = {"resourceType": "Encounter"}
    set e.id = pid _ "-e" _ eseq
    set e.status = status
    set classDisp = $select(classCode = "IMP": "inpatient encounter", classCode = "EMER": "emergency", 1: "ambulatory")
    set e.class = {"system": "http://terminology.hl7.org/CodeSystem/v3-ActCode", "code": (classCode), "display": (classDisp)}
    set e.subject = {"reference": ("Patient/" _ pid)}
    set e.period = {"start": (date)}
    if status = "finished" do e.period.%Set("end", date)
    set e.reasonCode = [{"text": (reason)}]
    do ..Add(batch, "Encounter", e.id, e)
}

ClassMethod PickEncReason() As %String
{
    set l = $listbuild("Routine review", "Acute illness", "Follow-up appointment", "Medication review", "New symptom assessment", "Telephone consultation")
    return $list(l, ..Rand($listlength(l)) + 1)
}

ClassMethod AddImm(batch As %DynamicArray, pid As %String, ByRef imseq, cvx, text, date As %String)
{
    set imseq = imseq + 1
    set im = {"resourceType": "Immunization", "status": "completed"}
    set im.id = pid _ "-im" _ imseq
    set im.vaccineCode = {"coding": [{"system": "http://hl7.org/fhir/sid/cvx", "code": (cvx), "display": (text)}], "text": (text)}
    set im.patient = {"reference": ("Patient/" _ pid)}
    set im.occurrenceDateTime = date
    do ..Add(batch, "Immunization", im.id, im)
}

ClassMethod AddProcedure(batch As %DynamicArray, pid As %String, ByRef prseq)
{
    set lP = ..PROCEDURES()
    set pick = $list(lP, ..Rand($listlength(lP)) + 1)
    set prseq = prseq + 1
    set p = {"resourceType": "Procedure", "status": "completed"}
    set p.id = pid _ "-pr" _ prseq
    set p.code = {"coding": [{"system": "http://snomed.info/sct", "code": ($piece(pick, "$", 1)), "display": ($piece(pick, "$", 2))}], "text": ($piece(pick, "$", 2))}
    set p.subject = {"reference": ("Patient/" _ pid)}
    set p.performedDateTime = ..DaysBeforeAnchor(..N(120, 1500))
    do ..Add(batch, "Procedure", p.id, p)
}

ClassMethod AddFlag(batch As %DynamicArray, pid As %String, ByRef fseq, category As %String, text As %String = "")
{
    // Allow AddFlag(.,.,.,"cat$text") convenience from PickFlag.
    if text = "" { set text = $piece(category, "$", 2), category = $piece(category, "$", 1) }
    set fseq = fseq + 1
    set f = {"resourceType": "Flag", "status": "active"}
    set f.id = pid _ "-flag" _ fseq
    set f.category = [{"coding": [{"system": "http://terminology.hl7.org/CodeSystem/flag-category", "code": (category)}]}]
    set f.code = {"text": (text)}
    set f.subject = {"reference": ("Patient/" _ pid)}
    do ..Add(batch, "Flag", f.id, f)
}

ClassMethod PickFlag() As %String
{
    set l = $listbuild("safety$Falls risk", "infection$Infection control - MRSA colonisation", "clinical$DNACPR in place", "admin$Interpreter required", "safety$Safeguarding - adult at risk", "clinical$Complex care needs", "admin$Frequent non-attender (DNA)", "clinical$Anticoagulated - bleeding risk", "safety$Carer support in place", "clinical$Allergy alert - see allergy list")
    return $list(l, ..Rand($listlength(l)) + 1)
}

ClassMethod DiagReport(pid As %String) As %DynamicObject
{
    set d = {"resourceType": "DiagnosticReport", "status": "final"}
    set d.id = pid _ "-dr1"
    set d.category = [{"coding": [{"system": "http://terminology.hl7.org/CodeSystem/v2-0074", "code": "LAB", "display": "Laboratory"}]}]
    set d.code = {"coding": [{"system": "http://loinc.org", "code": "24323-8", "display": "Comprehensive metabolic panel"}], "text": "Comprehensive metabolic panel"}
    set d.subject = {"reference": ("Patient/" _ pid)}
    set d.effectiveDateTime = ..RecentDate()
    set d.conclusion = "Routine chronic-disease monitoring panel."
    return d
}

ClassMethod CarePlan(pid As %String, status As %String) As %DynamicObject
{
    set c = {"resourceType": "CarePlan", "intent": "plan"}
    set c.id = pid _ "-cp1"
    set c.status = status
    set c.title = "Chronic disease management plan"
    set c.subject = {"reference": ("Patient/" _ pid)}
    set c.period = {"start": (..OldDate())}
    return c
}

ClassMethod Goal(pid As %String, status As %String) As %DynamicObject
{
    set g = {"resourceType": "Goal"}
    set g.id = pid _ "-goal1"
    set g.lifecycleStatus = "active"
    set g.achievementStatus = {"coding": [{"system": "http://terminology.hl7.org/CodeSystem/goal-achievement", "code": (status)}]}
    set g.description = {"text": "HbA1c below 7.0% within 6 months"}
    set g.subject = {"reference": ("Patient/" _ pid)}
    return g
}

ClassMethod Coverage(pid As %String, i As %Integer) As %DynamicObject
{
    set lP = ..PAYER()
    set payer = $list(lP, (i # $listlength(lP)) + 1)
    set c = {"resourceType": "Coverage", "status": "active"}
    set c.id = pid _ "-cov1"
    set c.beneficiary = {"reference": ("Patient/" _ pid)}
    set c.payor = [{"display": (payer)}]
    return c
}

ClassMethod ServiceRequest(pid As %String, text As %String) As %DynamicObject
{
    set s = {"resourceType": "ServiceRequest", "status": "active", "intent": "order"}
    set s.id = pid _ "-sr1"
    set s.code = {"text": (text)}
    set s.subject = {"reference": ("Patient/" _ pid)}
    set s.authoredOn = ..RecentDate()
    return s
}

ClassMethod Appointment(pid As %String, date As %String) As %DynamicObject
{
    set a = {"resourceType": "Appointment", "status": "booked"}
    set a.id = pid _ "-ap1"
    set a.description = "Follow-up visit"
    set a.start = date _ "T09:00:00Z"
    set a.participant = [{"status": "accepted"}]
    do a.participant.%Get(0).%Set("actor", {"reference": ("Patient/" _ pid)})
    return a
}

ClassMethod DocRef(pid As %String) As %DynamicObject
{
    set l = $listbuild(
        "Routine review. Stable on current treatment; bloods reviewed and filed. Continue current plan, review in 6 months.",
        "Telephone consultation. Medication queries answered; no change to treatment. Repeat prescriptions issued.",
        "Seen by practice nurse for annual checks. Lifestyle advice given; leaflets provided. Recall set.",
        "Home visit summary. Coping at present with family support; district nurse to continue weekly visits.",
        "Medication review with pharmacist. Doses optimised; no interactions identified at this review. Adherence discussed.")
    set d = {"resourceType": "DocumentReference", "status": "current"}
    set d.id = pid _ "-doc1"
    set d.type = {"coding": [{"system": "http://loinc.org", "code": "34109-9", "display": "Note"}], "text": "Clinical note"}
    set d.subject = {"reference": ("Patient/" _ pid)}
    // anchored date (NEVER wall-clock - dates leak into evidence displays and
    // would break cache reproducibility across rebuilds)
    set d.date = ..RecentDate() _ "T09:00:00Z"
    set d.description = $list(l, ..Rand($listlength(l)) + 1)
    // content[] is REQUIRED in R4 - without it the FHIR server rejects the resource
    set d.content = [{"attachment": {"contentType": "text/plain", "title": "Clinical note", "data": ($system.Encryption.Base64Encode($zconvert(d.description, "O", "UTF8")))}}]
    return d
}

/// Append { resourceType, resourceId, resource } to a batch array.
ClassMethod Add(batch As %DynamicArray, rt As %String, id As %String, res As %DynamicObject)
{
    set item = {}
    set item.resourceType = rt
    set item.resourceId = id
    do item.%Set("resource", res)
    do batch.%Push(item)
}

// ---- identity helpers ----

/// Return a unique "given$family" not yet used in this cohort, drawing from the
/// gendered given-name pool + family pool. Re-rolls on collision (the pools give
/// ~10k+ combinations per gender, so a unique pick is found in a few tries).
ClassMethod UniqueName(gender As %String) As %String
{
    set lG = $select(gender = "female": ..FEMALE(), 1: ..MALE())
    set lF = ..FAMILY()
    set ng = $listlength(lG), nf = $listlength(lF)
    for att = 1:1:200 {
        set giv = $list(lG, ..Rand(ng) + 1)
        set fam = $list(lF, ..Rand(nf) + 1)
        // full name must be unique AND no surname may appear more than twice
        // across the whole cohort (hero surnames pre-counted in Generate)
        if $get(^||fastname("F", fam), 0) >= 2 continue
        if '$data(^||fastname(giv, fam)) {
            set ^||fastname(giv, fam) = 1
            set ^||fastname("F", fam) = $get(^||fastname("F", fam), 0) + 1
            return giv _ "$" _ fam
        }
    }
    return giv _ "$" _ fam
}

/// Valid 10-digit NHS number (Mod-11 check digit). First digit 1-9.
ClassMethod NhsNumber() As %String
{
    set num = 0, chk = 0
    for att = 1:1:20 {
        set num = ..N(1, 9), s = num * 10
        for k = 2:1:9 { set d = ..Rand(10), num = num _ d, s = s + (d * (11 - k)) }
        set chk = 11 - (s # 11)
        if chk = 11 set chk = 0
        if chk '= 10 return num _ chk     // 10 is invalid for NHS numbers - re-roll
    }
    return num _ 0
}

/// 8-digit hospital number, first digit 1-9.
ClassMethod HospitalNumber() As %String
{
    set h = ..N(1, 9)
    for k = 2:1:8 { set h = h _ ..Rand(10) }
    return h
}

/// A UK address object { line:[..], city, postalCode, country:"GB" }.
ClassMethod Address() As %DynamicObject
{
    set lS = ..STREETS(), lT = ..TOWNS()
    set line = ..N(1, 240) _ " " _ $list(lS, ..Rand($listlength(lS)) + 1)
    set a = {"country": "GB"}
    set a.line = [(line)]
    set a.city = $list(lT, ..Rand($listlength(lT)) + 1)
    set a.postalCode = ..Postcode()
    return a
}

/// A plausible UK-format postcode, e.g. "M14 5GH".
ClassMethod Postcode() As %String
{
    set L = "ABDEFGHJLNPRSTW"
    set nl = $length(L)
    set out = $extract(L, ..Rand(nl) + 1)
    if ..Rand(2) set out = out _ $extract(L, ..Rand(nl) + 1)
    set out = out _ ..Rand(10)
    if ..Rand(3) = 0 set out = out _ ..Rand(10)
    set out = out _ " " _ ..Rand(10) _ $extract(L, ..Rand(nl) + 1) _ $extract(L, ..Rand(nl) + 1)
    return out
}

// ---- pools ----

ClassMethod MALE() [ CodeMode = expression ]
{
$listbuild("Oliver","George","Harry","Jack","Charlie","Noah","Jacob","Thomas","Oscar","William","James","Henry","Leo","Alfie","Joshua","Freddie","Archie","Edward","Alexander","Max","Daniel","Samuel","Joseph","Benjamin","Ethan","Lucas","Arthur","Theodore","Harrison","Sebastian","Toby","Louie","Reuben","Elliot","Finley","Albert","Stanley","Ronnie","Frankie","Jude","Hugo","Rory","Felix","Jasper","Miles","Rupert","Gilbert","Wilfred","Edmund","Clive","Trevor","Nigel","Roger","Colin","Derek","Graham","Keith","Alan","Brian","Geoffrey","Howard","Leonard","Maurice","Norman","Raymond","Stuart","Vernon","Wesley","Barry","Clifford","Dennis","Gerald","Gordon","Harold","Ivor","Kenneth","Lawrence","Malcolm","Neil","Percy","Quentin","Roland","Sidney","Terence","Vince","Walter","Bernard","Cecil","Duncan","Fraser","Mohammed","Ibrahim","Yusuf","Omar","Ali","Hassan","Tariq","Khalid","Rajan","Arjun","Dev","Sanjay","Vikram","Ravi","Amit","Hiroshi","Kenji","Takeshi","Wei","Jun","Ming","Dmitri","Piotr","Tomasz","Lukas","Andrzej","Stefan","Marek","Carlos","Diego","Mateo","Luis","Rafael","Kwame","Kofi","Chidi","Emeka","Tunde","Sekou","Luca","Marco","Giovanni","Theo","Henrik","Lars","Erik","Sven","Olu","Samir","Callum")
}

ClassMethod FEMALE() [ CodeMode = expression ]
{
$listbuild("Olivia","Amelia","Isla","Ava","Emily","Sophia","Grace","Mia","Poppy","Ella","Lily","Freya","Charlotte","Daisy","Phoebe","Alice","Florence","Eleanor","Harriet","Matilda","Rosie","Imogen","Evelyn","Beatrice","Lottie","Martha","Nancy","Penelope","Tilly","Victoria","Margaret","Dorothy","Joan","Sheila","Audrey","Brenda","Carol","Diane","Eileen","Gillian","Hazel","Irene","Janet","Kathleen","Linda","Maureen","Norma","Pamela","Rita","Sandra","Theresa","Valerie","Wendy","Yvonne","Barbara","Cynthia","Deborah","Elaine","Frances","Gwen","Hilda","Iris","Joyce","Kay","Lorraine","Mavis","Nora","Olive","Patricia","Ruth","Sylvia","Vera","Winifred","Edith","Gladys","Mabel","Agnes","Constance","Doris","Ethel","Aisha","Fatima","Zara","Layla","Yasmin","Noor","Samira","Priya","Anjali","Meera","Divya","Kavita","Ling","Mei","Yuki","Sakura","Hana","Ingrid","Astrid","Freja","Elena","Olga","Katya","Magda","Zofia","Camila","Lucia","Sofia","Valentina","Ines","Amara","Ngozi","Chioma","Folake","Zainab","Maria","Carmen","Rosa","Bianca","Giulia","Farah","Leila","Nadia","Soraya","Anya")
}

ClassMethod FAMILY() [ CodeMode = expression ]
{
..FAMILYA() _ ..FAMILYB() _ ..FAMILYC() _ ..FAMILYD()
}

ClassMethod FAMILYA() [ CodeMode = expression ]
{
$listbuild("Smith","Jones","Taylor","Brown","Williams","Wilson","Davies","Evans","Thomas","Roberts","Walker","Wright","Robinson","Thompson","White","Hughes","Edwards","Green","Hall","Wood","Harris","Lewis","Martin","Jackson","Clarke","Clark","Turner","Hill","Scott","Cooper","Morris","Ward","Moore","King","Watson","Baker","Morgan","Allen","Young","Harrison","Mitchell","Anderson","Phillips","Lee","Bell","Parker","Davis","Bennett","Miller","Shaw","Cook","Simpson","Carter","Richardson","Marsh","Collins","Bailey","Price","Murphy","Cox","Richards","Gray","Mason","Ellis","Foster","Barnes","Fisher","Hunt","Stevens","Murray","Knight","Hudson","Stone","Holmes","Palmer","Mills","West","Webb","Rogers","Gibson","Chapman","Russell","Fox","Hart","Owen","Reynolds","Fletcher","Pearson","Spencer","Atkinson","Lane","Dixon","Grant","Hayes","Lloyd","Barker","Burton","Lawrence","Page","Reid","Holland","Armstrong","Dawson","Fowler","Gardner","Hamilton","Hopkins","Jenkins","Kennedy","Lambert","Matthews","Newman","Norris","Osborne","Perkins","Pratt","Quinn","Rhodes","Sanders","Sutton","Tucker","Vaughan","Wade","Walsh","Warren","Watts","Wells","Whitehead","Wilkinson","Woodward","Yates","Abbott","Ainsworth","Appleby","Ashford","Atherton","Bancroft","Barlow","Barnett","Beaumont","Beckett","Bingham","Blackburn","Blakely","Bond","Booth","Bowen","Bradley","Bradshaw","Brennan","Briggs","Brockley","Broughton","Buckley","Burgess","Burns","Byrne","Calvert","Carlisle","Carrington","Cartwright","Chadwick","Chambers","Chandler")
}

ClassMethod FAMILYB() [ CodeMode = expression ]
{
$listbuild("Charlton","Cheshire","Childs","Clayton","Clements","Coleman","Connolly","Conway","Cornish","Cotterill","Coulson","Crabtree","Crawford","Crompton","Crosby","Cunningham","Dalton","Daniels","Darby","Davenport","Day","Dean","Denton","Derbyshire","Dickinson","Dobson","Donnelly","Douglas","Dowling","Doyle","Draper","Duffield","Dunbar","Dunn","Eastwood","Eaton","Eccles","Egerton","Ellison","Elston","Emerson","Eyre","Fairbanks","Fairclough","Farley","Farrell","Faulkner","Fenton","Ferguson","Finch","Firth","Fitzgerald","Flanagan","Fleming","Flint","Forbes","Ford","Forsyth","Fortescue","Frampton","Francis","Freeman","Frost","Fry","Gallagher","Garfield","Garner","Garrett","Gaskell","Gibbons","Giles","Gill","Gilmore","Goddard","Godfrey","Goldsmith","Goodwin","Gould","Graves","Greenwood","Gregory","Gresham","Grey","Griffin","Griffiths","Grimshaw","Gunn","Hackett","Haig","Haines","Hale","Halliday","Hancock","Hanley","Harding","Hardy","Hargreaves","Harman","Harper","Hartley","Harvey","Hastings","Hawkins","Haywood","Heath","Henderson","Hendry","Hepworth","Herbert","Heron","Hewitt","Higgins","Hodgson","Holden","Holloway","Holt","Hooper","Hornby","Horton","Houghton","Howard","Howell","Hoyle","Hubbard","Hume","Humphries","Hutchinson","Ingram","Irving","Jarvis","Jennings","Jepson","Jordan","Kemp","Kendall","Kerr","Kershaw","Kimber","Kirby","Kirk","Kitson","Lacey","Laird","Lamb","Langley","Larkin","Latham","Lawson","Leach","Leigh","Lennox","Lindley","Lindsay","Little","Lockwood","Lomax","Long","Lovell","Lowe","Lyons","Macauley","Madden","Mallory","Maltby")
}

ClassMethod FAMILYC() [ CodeMode = expression ]
{
$listbuild("Manning","Mansfield","Marlow","Marriott","Marshall","Maskell","Mayfield","McCarthy","Mead","Mercer","Metcalfe","Middleton","Milburn","Milner","Molyneux","Moran","Morley","Morton","Moss","Murdoch","Naylor","Nelson","Nesbitt","Neville","Newton","Nicholls","Nicholson","Nixon","Noble","Nolan","Oakley","Ogden","Oldfield","Orme","Osgood","Overton","Oxley","Paige","Paisley","Parr","Parsons","Patton","Paxton","Peacock","Pearce","Pemberton","Pennington","Percival","Perry","Pickering","Pickford","Pilkington","Platt","Pollard","Poole","Pope","Porter","Potter","Poulton","Powell","Preston","Pritchard","Proctor","Pryce","Purcell","Radcliffe","Ramsay","Rankin","Ratcliffe","Rawlings","Redfern","Redman","Reeves","Rennie","Riley","Rimmer","Ripley","Rixon","Roach","Robson","Rochester","Rodgers","Rowe","Rowley","Royle","Rudd","Rushton","Rutherford","Ryder","Sadler","Salisbury","Sanderson","Saunders","Savage","Saxton","Scholes","Seabrook","Sedgwick","Selby","Shackleton","Sharp","Shelton","Shepherd","Sheppard","Sherwood","Short","Simmons","Sinclair","Skinner","Slater","Sloan","Small","Smedley","Snow","Southgate","Sparrow","Speight","Spence","Spofforth","Stafford","Stanton","Stapleton","Steele","Stephenson","Stirling","Stokes","Strickland","Stubbs","Summerfield","Swift","Sykes","Talbot","Tanner","Tate","Tennant","Thackeray","Thatcher","Thorne","Thornton","Tipton","Todd","Tomlinson","Townsend","Travers","Trent","Truman","Tyler","Underwood","Unwin","Vance","Vickers","Wadsworth","Wainwright","Wakefield","Waller","Wallis","Walmsley","Walton","Warburton","Wardle","Waring","Warner","Waterhouse","Weaver")
}

ClassMethod FAMILYD() [ CodeMode = expression ]
{
$listbuild("Webster","Weston","Whitfield","Whitley","Whittaker","Wickham","Wilcox","Wilde","Wilkes","Willis","Willoughby","Winder","Windsor","Winstanley","Winter","Wolfe","Wyatt","Patel","Begum","Hussain","Ahmed","Akhtar","Iqbal","Rashid","Malik","Chaudhry","Sharma","Singh","Kaur","Gupta","Mehta","Desai","Joshi","Reddy","Nair","Rao","Kapoor","Bhatt","Khan","Chen","Wang","Li","Zhang","Liu","Wu","Lin","Sato","Suzuki","Tanaka","Watanabe","Yamamoto","Nakamura","Kim","Park","Choi","Nguyen","Tran","Pham","Kowalski","Nowak","Wisniewski","Zielinski","Kaminski","Petrov","Ivanov","Volkov","Sokolov","Novak","Svoboda","Dvorak","Horak","Garcia","Rodriguez","Martinez","Hernandez","Lopez","Gonzalez","Perez","Sanchez","Ramirez","Torres","Silva","Santos","Oliveira","Costa","Pereira","Ferrari","Rossi","Romano","Ricci","Marino","Greco","Moreau","Dubois","Lefebvre","Laurent","Fontaine","Rousseau","Mueller","Schmidt","Schneider","Fischer","Weber","Wagner","Becker","Hoffmann","Jensen","Hansen","Pedersen","Larsen","Andersson","Johansson","Karlsson","Lindberg","Bergstrom","Okafor","Adeyemi","Okonkwo","Eze","Mensah","Boateng","Osei","Diallo","Toure","Keita","Haddad","Khalil","Nasser","Aziz","Farah","Osman","Demir","Yilmaz","Kaya","Celik","Aydin","Cohen","Levi","Mizrahi","Begovic","Kovac","Babic","Horvat","Popescu","Ionescu","Dimitrov","Georgiev","Papadopoulos","Nikolaou","Vasquez","Mendoza","Castillo","Rojas","Vargas","Fuentes","Salazar","Cabrera","Reyes","Dube","Ndlovu","Khumalo","Mokoena")
}

ClassMethod STREETS() [ CodeMode = expression ]
{
$listbuild("High Street","Station Road","Church Lane","Victoria Road","Mill Lane","Kings Road","Queens Road","Park Avenue","The Green","Manor Close","London Road","New Street","School Lane","Main Road","North Street","South Street","West Way","Elm Grove","Oak Avenue","Maple Close","Albert Road","George Street","Windsor Road","Springfield Road","Meadow View","Riverside Walk","Castle Street","Bridge Street","Chapel Lane","Orchard Way","Cherry Tree Road","The Crescent","Beech Drive","Hawthorn Close","Sycamore Avenue")
}

ClassMethod TOWNS() [ CodeMode = expression ]
{
$listbuild("Manchester","Leeds","Birmingham","Sheffield","Nottingham","Leicester","Coventry","Bristol","Reading","Brighton","York","Derby","Norwich","Oxford","Cambridge","Exeter","Bath","Durham","Preston","Plymouth","Southampton","Portsmouth","Sunderland","Wolverhampton","Stoke-on-Trent","Swindon","Luton","Bolton","Bournemouth","Ipswich","Middlesbrough","Blackpool","Huddersfield","Cardiff","Swansea")
}

/// Background chronic conditions: "snomed$display$rxnorm$medication" (med optional).
ClassMethod BACKGROUND() [ CodeMode = expression ]
{
$listbuild("40930008$Hypothyroidism$966222$Levothyroxine 100mcg once daily","49436004$Atrial fibrillation$1364445$Apixaban 5mg twice daily","396275006$Osteoarthritis$849574$Naproxen 250mg as required","235595009$Gastro-oesophageal reflux disease$198051$Omeprazole 20mg once daily","48694002$Anxiety disorder$312940$Sertraline 50mg once daily","195967001$Asthma$745679$Salbutamol inhaler as required","64859006$Osteoporosis$904419$Alendronic acid 70mg weekly","53741008$Coronary artery disease$243670$Aspirin 75mg once daily","37796009$Migraine$104894$Sumatriptan 50mg as required","24079001$Atopic eczema$$","9279000$Diverticular disease$$","26929004$Allergic rhinitis$$","73430006$Sleep apnoea$$","25064002$Tension headache$$","267032009$Iron deficiency anaemia$310968$Ferrous sulfate 200mg once daily","13644009$Hypercholesterolaemia$$","42399005$Benign prostatic hyperplasia$310429$Tamsulosin 400mcg once daily","69896004$Rheumatoid arthritis$$","190905008$Vitamin D deficiency$316672$Colecalciferol 800 units daily","82271004$Gout$104456$Allopurinol 100mg once daily")
}

/// Resolved / historical problems: "snomed$display".
ClassMethod HISTORY() [ CodeMode = expression ]
{
$listbuild("233604007$Pneumonia","10509002$Acute bronchitis","195662009$Acute pharyngitis","80146002$Appendicitis (post-appendicectomy)","125605004$Fracture of bone","422587007$Nausea and vomiting","62315008$Diarrhoea","21522001$Abdominal pain","267036007$Dyspnoea","68962001$Muscle strain","444814009$Viral upper respiratory infection","16114001$Fracture of ankle")
}

ClassMethod PROCEDURES() [ CodeMode = expression ]
{
$listbuild("73761001$Colonoscopy","40701008$Echocardiography","274025005$Knee arthroscopy","76752008$Skin lesion excision","18286008$Cataract surgery","225158009$Wound care","415070008$Percutaneous coronary intervention","312681000$Gastroscopy")
}

ClassMethod PAYER() [ CodeMode = expression ]
{
$listbuild("NHS England","NHS Greater Manchester ICB","NHS West Yorkshire ICB","Bupa","AXA Health","Vitality Health","NHS North East ICB","NHS Birmingham and Solihull ICB")
}

// ---- deterministic helpers ----

/// Deterministic PRNG (LCG) over a process-private seed, mirroring $random(n):
/// returns an integer in [0, n). Seeded once per Generate via ..#RNGSEED so the
/// whole population reproduces byte-for-byte on every reseed.
ClassMethod Rand(n As %Integer) As %Integer
{
    set ^||fastrng = ((($get(^||fastrng, ..#RNGSEED) * 1103515245) + 12345) # 2147483648)
    return ^||fastrng # n
}

ClassMethod N(low As %Integer, high As %Integer) As %Integer
{
    return low + ..Rand(high - low + 1)
}

ClassMethod Pad(i As %Integer) As %String
{
    return $extract("000" _ i, *-3, *)
}

ClassMethod Pad2(i As %Integer) As %String
{
    return $extract("0" _ i, *-1, *)
}

/// A date within the last ~5 months of the fixed anchor (inside the 6-month
/// cohort window) - anchored, not wall-clock, so it never drifts between reseeds.
ClassMethod RecentDate() As %String
{
    return $zdate($zdateh(..#ANCHORDATE, 3) - ..Rand(150), 3)
}

/// A date 8-30 months before the fixed anchor.
ClassMethod OldDate() As %String
{
    return $zdate($zdateh(..#ANCHORDATE, 3) - 240 - ..Rand(660), 3)
}

ClassMethod DaysBeforeAnchor(d As %Integer) As %String
{
    return $zdate($zdateh(..#ANCHORDATE, 3) - d, 3)
}

ClassMethod DaysAfterAnchor(d As %Integer) As %String
{
    return $zdate($zdateh(..#ANCHORDATE, 3) + d, 3)
}

ClassMethod NowISO() As %String
{
    return $translate($zdatetime($ztimestamp, 3), " ", "T") _ "Z"
}

}
