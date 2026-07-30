---
name: data-extraction
description: "Extract structured clinical trial efficacy data from press releases, ClinicalTrials.gov, PubMed abstracts, CILand articles, or pasted text. Produces a formatted table of treatment arms with endpoints, response rates, CIs, and sample sizes."
---

# Data Extraction Skill

## When to Use

- User provides a press release URL, PDF content, or pasted text about a clinical trial
- User provides a CILand SharePoint article URL (collab.lilly.com/sites/CILand/...)
- User asks to "extract data" or "pull the numbers" from a source
- User provides an NCT ID to look up on ClinicalTrials.gov
- User asks about a specific study's results

## Supported Sources (Priority Order)

1. **CILand articles** — `collab.lilly.com/sites/CILand/SitePages/...` (internal, curated, often has data + strategic context)
2. **Press releases** — Sponsor company investor pages, biospace.com, PR Newswire
3. **ClinicalTrials.gov** — NCT IDs, study results
4. **PubMed abstracts** — Published data
5. **Pasted text** — User-supplied content

## Workflow Overview

This is a 2-phase pipeline with fallback:

```
Phase 1: Extract from primary source (CILand / press release / pasted text)
    ↓
Check: Is extraction sufficient? (≥2 arms, placebo present, outcome values, per-arm N)
    ↓ NO
Phase 2: Fallback to ClinicalTrials.gov + PubMed for missing data
    ↓
Merge: Combine sources with priority (ciland > press_release > ctgov > pubmed > free_text)
    ↓
Present: Show structured table to user with warnings
```

---

## Phase 1: Primary Source Extraction

### Fetching URLs (3-tier fallback)

Try in order:
1. Live HTTP/2: `curl -s -L -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" "{URL}"`
2. If fails, force HTTP/1.1: `curl -s -L --http1.1 -H "User-Agent: Mozilla/5.0..." "{URL}"`
3. If fails, Wayback Machine: `curl -s "https://web.archive.org/web/{URL}"`

**Note on CILand URLs:** SharePoint pages at `collab.lilly.com` may require authentication. If curl returns a login redirect or 403:
- Ask user: "The CILand page requires authentication. Could you paste the article text, or copy the page content here?"
- Alternatively, if an auth token is available in environment, use: `curl -s -L -H "Authorization: Bearer $CILAND_TOKEN" "{URL}"`
- Future: MCP connector will handle this automatically

### Cleaning HTML to text

- Remove `<script>` and `<style>` blocks entirely
- Strip all remaining HTML tags
- Replace `&nbsp;` → space, `&amp;` → &
- Collapse whitespace
- For PDFs: preserve newlines (critical for table layouts)

### Extraction from text (LLM-powered)

Ask Claude to extract structured JSON from the cleaned text with these critical rules:

**Prompt rules:**
1. Extract ONLY the primary study reported in this document
2. Extract ONLY arms where numerical outcome values are explicitly reported
3. Do NOT create phantom arms (if a drug is mentioned but no numbers given, skip it)
4. For each arm, extract: treatment name, dose, frequency, n_pts, endpoint, timepoint, outcome_value, ci_lower, ci_upper, p_value, estimand

**Indication-specific hints** (injected into prompt based on indication):
- AD: "Use 'iga01' for IGA 0/1 or vIGA-AD 0/1, 'easi75' for EASI-75, 'easi90' for EASI-90"
- UC: "Use 'clin_remission' for Clinical Remission (MMS-based), 'clin_response' for Clinical Response"
- PSO: "Use 'pasi75' for PASI-75, 'pasi90' for PASI-90, 'pasi100' for PASI-100"
- (See references/indications.md for all)

**For continuous endpoints (e.g., Allergic Rhinitis):**
- Extract mean change from baseline (not responder rate)
- Also extract SD and SE if reported
- The outcome_value is the mean change, not a percentage

### After LLM returns:

1. Drop any arms where outcome_value is NA (phantom arms)
2. Normalize endpoint strings to canonical codes using the indication's match patterns
3. Filter to only the target endpoints user requested

---

## Phase 2: Fallback Sources

Triggered when Phase 1 extraction is insufficient (missing arms, no outcome values, no per-arm N).

### ClinicalTrials.gov

```bash
curl -s "https://clinicaltrials.gov/api/v2/studies/{NCT_ID}?format=json"
```

**Parse the resultsSection:**
- For each target endpoint, find matching `outcomeMeasures` using indication-specific match functions
- Extract denominators per group (= per-arm N)
- Extract values from `classes[0].categories[].measurements[].value` (first class only — avoids subcomponents)
- Detect timepoint: regex cascade → week > day÷7 > month×4 > title patterns
- Detect estimand from description: NRI, mNRI, Treatment policy, MCMC-MI, MMRM, OC, LOCF
- Detect IGA variant: vIGA-AD vs rIGA
- Detect statistical population: ITT/FAS, mITT, PP, Safety

**Important:** If press release already has arms with outcome data, CT.gov provides **metadata only** (allocation ratio, links, study design) — arms from press release take priority.

### PubMed

```bash
# Search
curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term={drug_name}+{indication}&retmode=json&retmax=5"
# Fetch
curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id={PMID}&rettype=abstract"
```

Use LLM to extract from abstract text, same rules as Phase 1.

---

## Merge Logic

When data comes from multiple sources, merge with priority:

**Source priority:** press_release > ctgov > pubmed > free_text

**Per-arm scoring:** For each arm row, score = count of non-NA fields among (outcome_value, n_pts, n_events, measurement_time). Higher score = more complete.

**Merge rule:** For each unique (endpoint, treatment) pair, pick the row with highest completeness from the highest-priority source.

---

## Sufficiency Check

Before presenting results, verify:
- [ ] ≥ 2 arms extracted
- [ ] At least one placebo/comparator arm present
- [ ] Outcome values are not all NA
- [ ] Per-arm N is available (or can be inferred from ratio)
- [ ] At least one target endpoint matched
- [ ] Study has an identifier (NCT ID or study name)

If insufficient, report what's missing and suggest user provide additional source.

---

## Sample Size Rules (CRITICAL)

**NEVER assume equal randomization.**

Priority for determining per-arm N:
1. Source explicitly states per-arm N → use directly
2. ClinicalTrials.gov registry per-arm data
3. Allocation ratio stated (e.g., "2:1") → derive: `arm_n = total_n × ratio_part / sum(ratio)`
4. Cannot determine → flag as "N not reported per arm", do NOT guess

**Ratio parsing:** "2:1" → [2,1]; "1:1:1" → [1,1,1]; "3:2:1" → [3,2,1]

**Rounding adjustment:** After dividing by ratio, per-arm Ns must sum to total_n exactly. Add/subtract the remainder from the largest-ratio arm.

---

## Estimand Detection

Look for these patterns in outcome descriptions:
- "non-responder imputation" or "NRI" → `NRI`
- "modified NRI" or "mNRI" → `mNRI`
- "treatment policy" → `treatment_policy`
- "MCMC" or "multiple imputation" → `MCMC_MI`
- "MMRM" or "mixed model" → `MMRM`
- "observed" or "as observed" or "completer" → `observed`
- "LOCF" or "last observation" → `LOCF`

**Priority for BNMA (indications with NRI preference):** NRI > mNRI > observed > LOCF

If only non-preferred estimand available, flag: "⚠️ Only [observed] estimand — NRI preferred for BNMA"

---

## Output Format

```
## Extracted Data: [Study Name] — [Indication]

Source: [URL or NCT ID]
Phase: [Phase 2/3]
Sponsor: [Company]
Timepoint: Week [X]
Estimand: [NRI/observed/etc.]

| Treatment | Dose | Freq | N | Endpoint | Result (%) | 95% CI | p-value |
|-----------|------|------|---|----------|-----------|--------|---------|
| dupilumab | 300mg | Q2W | 245 | EASI-75 | 61.3 | 54.2–68.4 | <0.001 |
| placebo | — | — | 123 | EASI-75 | 14.7 | 8.9–20.5 | — |

⚠️ Warnings:
- [list any issues]

Review is required before disclosure.
```

---

## References

- See `references/indications.md` for endpoint codes and default timepoints per indication
- See `references/extraction-rules.md` for Batman column mapping and QC checks
