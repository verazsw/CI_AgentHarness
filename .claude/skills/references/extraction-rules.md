# Extraction Rules, Derivation Chain, QC Checks, and Batman Schema

## Fields to Extract

For each treatment arm in a study, extract:

### Required Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `treatment` | text | Generic drug name, standardized | "dupilumab" |
| `dose` | text | Dose with units | "300mg" |
| `frequency` | text | Dosing schedule | "Q2W", "QD", "Q4W" |
| `n_pts` | integer | Number of patients in this arm | 245 |
| `endpoint` | text | Standardized endpoint code | "easi75" |
| `timepoint_weeks` | integer | Assessment week | 16 |
| `outcome_value` | numeric | Response rate (%) or mean change | 61.3 |

### Optional Fields (extract if reported)

| Field | Type | Description |
|-------|------|-------------|
| `ci_lower` | numeric | Lower 95% CI bound |
| `ci_upper` | numeric | Upper 95% CI bound |
| `p_value` | numeric | P-value vs comparator |
| `se` | numeric | Standard error |
| `sd` | numeric | Standard deviation (continuous endpoints) |
| `n_events` | integer | Number of responders (r) — for binary |
| `estimand` | text | NRI, mNRI, observed, LOCF, MMRM |
| `study_name` | text | Trial name (e.g., "LIBERTY AD CHRONOS") |
| `nct_id` | text | NCT identifier |
| `phase` | text | Phase 2, Phase 3, etc. |

---

## Derivation Chain (converting to BNMA-ready format)

### Binary endpoints (response rates)

```
Input:  outcome_value (%) + n_pts
Output: r, n, y, se

Step 1: n_events = round(outcome_value / 100 × n_pts)
Step 2: r = n_events
Step 3: n = n_pts
Step 4: y = r / n
Step 5: se = sqrt(y × (1-y) / n)   [binomial standard error]
```

### Continuous endpoints (mean change from baseline)

```
Input:  outcome_value (mean change) + n_pts + SD or SE
Output: y, se

Step 1: y = outcome_value (directly — this IS the mean change)
Step 2: If SE reported → se = SE
        If only SD reported → se = SD / sqrt(n_pts)
Step 3: r = NA, n_events = NA (not applicable for continuous)
```

---

## QC Checks (run after extraction)

| ID | Severity | Check | Logic |
|----|----------|-------|-------|
| Q1 | Warning | Derivation match | `round(outcome_value/100 × n_pts)` should equal `n_events` |
| Q2 | Warning | y = r/n | Must match within 0.001 tolerance |
| Q3 | Error | Missing required | `n` always required; `r` required for binary |
| Q4 | Warning | Naming convention | Active arms should include mg + frequency + route |
| Q5 | Error/Info | Value range | Binary: must be [0,100]; >80% flagged as Info |
| Q6 | Warning | Small N | n_pts < 10 |
| Q7 | Warning/Error | N inference | Flagged when N was inferred (Warning) or not reported (Error) |
| Q8 | Error | No placebo | No placebo/comparator arm present |
| Q9 | Error | Duplicate | Same (study, treatment) already exists in dataset |
| Q10 | Warning | Active < placebo | Active arm response lower than placebo (unexpected) |
| Q11 | Error/Warning | SE range | SE must be positive; SE > 3× |mean change| (continuous only) |

**Pass/fail:**
- PASS if no issues or all Info-level
- BLOCKED if any Error-severity issues

---

## Sample Size Rules (CRITICAL)

**NEVER assume equal randomization.**

Priority for determining per-arm N:
1. Source explicitly states per-arm N → use directly
2. ClinicalTrials.gov registry per-arm data
3. Allocation ratio stated (e.g., "2:1") → derive: `arm_n = total_n × ratio_part / sum(ratio)`
4. Cannot determine → flag "N not reported per arm" — do NOT guess

**Ratio parsing:** "2:1" → [2,1]; "1:1:1" → [1,1,1]; "3:2:1" → [3,2,1]

**Rounding:** Per-arm Ns must sum to total_n exactly. Add remainder to largest-ratio arm.

---

## Estimand Detection

Patterns to look for in outcome descriptions:

| Pattern | Estimand code |
|---------|--------------|
| "non-responder imputation", "NRI" | `NRI` |
| "modified NRI", "mNRI" | `mNRI` |
| "treatment policy" | `treatment_policy` |
| "MCMC", "multiple imputation" | `MCMC_MI` |
| "MMRM", "mixed model" | `MMRM` |
| "observed", "as observed", "completer" | `observed` |
| "LOCF", "last observation" | `LOCF` |

**Priority for BNMA:** NRI > mNRI > treatment_policy > observed > LOCF

---

## Multi-Source Merge Priority

1. **Press release / publication** — highest priority, most current
2. **ClinicalTrials.gov** — structured but may lag
3. **PubMed abstract** — confirms, less granular
4. **Free text (user pasted)** — lowest

**Key rule:** If press release already has arms with outcome values, fallback sources provide metadata only — do NOT override press release numbers.

**Per-arm completeness score:** count of non-NA among (outcome_value, n_pts, n_events, measurement_time). For each (endpoint, treatment) pair, pick highest-completeness row from highest-priority source.

---

## ClinicalTrials.gov API Parsing

**URL:** `https://clinicaltrials.gov/api/v2/studies/{NCT_ID}?format=json`

**Key JSON paths:**
```
protocolSection.identificationModule.officialTitle     → study name
protocolSection.identificationModule.nctId             → NCT ID
protocolSection.designModule.phases                    → phase
protocolSection.designModule.designInfo.allocation     → randomized?
protocolSection.armsInterventionsModule.armGroups      → arm descriptions
protocolSection.eligibilityModule                      → population criteria

resultsSection.outcomeMeasures[].measure               → endpoint name
resultsSection.outcomeMeasures[].groups[].title         → arm name
resultsSection.outcomeMeasures[].groups[].denominator   → arm N
resultsSection.outcomeMeasures[].classes[0].categories[].measurements[].value → result
```

**Timepoint detection** (regex cascade on timeframe string):
1. "week X" or "X weeks" → X
2. "day X" or "X days" → X ÷ 7
3. "month X" or "X months" → X × 4
4. Title patterns ("at Week X") → X
5. Fallback: indication default

---

## Batman Schema (37 columns — exact order)

```
study, study_ind, treat, arm_ind, n, r, y, se,
Link_to_Article, Location, Publication_Year,
Number_of_Treatment_Arms, Sponsor, Source, Trial_Acronym,
Trial_Registry_Number, Trial_Start_Year, Trial_End_Year,
Primary_Study_Treatment, Clinical_Phase, Inclusion_Criteria,
Exclusion_Criteria, Treatment_Arm, Dose_Description,
Treatmen_1_Frequency, Treatment_1_ROA, Outcome_Short_Form,
Outcome_Measurement_Time, Outcome_Measurement_Time_Unit,
Outcome_Value, N_pts_in_Analysis, N_Events_in_Analysis,
Statistical_Population, Minimum_age, Imputation_Method,
Maximum_age, Minimum_Age
```

Note: "Treatmen_1_Frequency" (missing 't') is a legacy typo from the upstream template.

### Column mapping:

| Batman Column | Source Field |
|---------------|-------------|
| `study` | trial_acronym or study_name |
| `study_ind` | auto-increment from existing max |
| `treat` | treatment name |
| `arm_ind` | sequential within study |
| `n` | n_pts |
| `r` | n_events (responders) |
| `y` | outcome_value / 100 (proportion, not percentage) |
| `se` | sqrt(y×(1-y)/n) for binary; SD/sqrt(n) for continuous |
| `Trial_Registry_Number` | NCT ID |
| `Outcome_Short_Form` | endpoint code |
| `Outcome_Measurement_Time` | timepoint (weeks) |
| `Outcome_Measurement_Time_Unit` | "Weeks" |
| `Outcome_Value` | raw outcome_value |
| `N_pts_in_Analysis` | n_pts |
| `N_Events_in_Analysis` | n_events |
| `Imputation_Method` | estimand |
| `Statistical_Population` | ITT/mITT/PP |

### Frequency inference from treatment name:

| Pattern | Value |
|---------|-------|
| Q2W, q2w, every 2 weeks | Q2W |
| Q4W, q4w, monthly | Q4W |
| Q8W, every 8 weeks | Q8W |
| QW, weekly | QW |
| QD, daily, once daily | QD |
| BID, twice daily | BID |

### Route inference from treatment name:

| Pattern | Value |
|---------|-------|
| SC, subcutaneous | SC |
| IV, intravenous, infusion | IV |
| oral, tablet, capsule | Oral |
| topical, cream, ointment | Topical |
