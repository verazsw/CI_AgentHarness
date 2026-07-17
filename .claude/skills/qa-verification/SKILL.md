---
name: qa-verification
description: "Quality-check agent outputs before delivery. Verify extracted data accuracy, slide content completeness, chart correctness, and BNMA interpretation validity. Run this after generating any deliverable. Triggered by 'check this', 'verify', 'QC', or automatically before final delivery."
---

# QA Verification Skill

## When to Use

- After data extraction — verify numbers match source
- After slide generation — verify content completeness and accuracy
- After chart generation — verify visual matches data
- Before any data is saved to the database
- User says "check this", "verify", "QC", or "is this correct?"
- Automatically before delivering any final output to user

## QA Philosophy

**Expect 2-3 revision rounds.** The first output is rarely perfect. This skill catches issues BEFORE the user has to find them.

---

## QA Checklist: Data Extraction

### Content Checks

| # | Check | How to verify |
|---|-------|---------------|
| 1 | **Numbers match source** | Re-read the source text — does every extracted number appear verbatim? |
| 2 | **No phantom arms** | Every arm in the table has an actual numerical result in the source |
| 3 | **Correct endpoint mapping** | "EASI 75%" → `easi75`, not `easi90` or something else |
| 4 | **Placebo present** | BNMA requires a common comparator |
| 5 | **N per arm is actual** | Not assumed from total ÷ number of arms |
| 6 | **Estimand identified** | NRI/mNRI/observed/LOCF — stated explicitly |
| 7 | **Timepoint correct** | Week 16 is not confused with Week 12 or Week 52 |
| 8 | **CI direction** | Lower bound < point estimate < upper bound |
| 9 | **Drug name correct** | Generic name, correct spelling, not confused with similar drugs |
| 10 | **Dose/frequency match** | "300mg Q2W" not "300mg QW" |

### Derivation Checks

| # | Check | Formula |
|---|-------|---------|
| 11 | r/n ≈ y | `round(outcome_value/100 × n) == responders` within ±1 |
| 12 | SE reasonable | Binary: `se = sqrt(y(1-y)/n)` should match. SE should not be 0 or >0.5 |
| 13 | Value range | Binary: 0-100%. If >80%, flag as noteworthy (not necessarily wrong) |

### Completeness Checks

| # | Check | Requirement |
|---|-------|-------------|
| 14 | All target endpoints covered | If user asked for EASI-75 + IGA 0/1, both must be present |
| 15 | Source attribution | NCT ID or URL is recorded |
| 16 | Warnings listed | Any uncertainty or inference is explicitly flagged |

---

## QA Checklist: Slide Generation

### Content Checks

| # | Check | What to verify |
|---|-------|----------------|
| 1 | **Key summary is accurate** | Top-line numbers match extraction |
| 2 | **No numbers from memory** | Every statistic traces back to a source |
| 3 | **Comparisons are fair** | Same endpoint, same timepoint, same estimand |
| 4 | **Cross-trial caveat present** | "Cross-trial comparison for illustrative purposes only" |
| 5 | **Study design is correct** | Phase, arms, N, population — verify against CT.gov or source |
| 6 | **Sponsor is correct** | Easy to confuse (e.g., Sanofi/Regeneron for dupilumab) |

### Completeness Checks

| # | Check | What to verify |
|---|-------|----------------|
| 7 | All 5 slides present | Summary, Design, Efficacy, Safety/Competitive, Development |
| 8 | Dual format present | ANALYSIS + SLIDE for each |
| 9 | SLIDE length OK | MAX 80 words per slide, MAX 20 words per bullet |
| 10 | Disclaimer present | "Review is required before disclosure" |
| 11 | Data source footnote | Study name + source on each slide |

### Chart Checks

| # | Check | What to verify |
|---|-------|----------------|
| 12 | Chart data matches extraction | Bar heights = extracted outcome_value |
| 13 | Error bars match CIs | Not wider or narrower than extracted |
| 14 | Labels correct | Treatment names, endpoint, timepoint in title |
| 15 | New data highlighted | Lilly red for new, gray for existing |
| 16 | Placebo included | As reference bar |

---

## QA Checklist: BNMA Interpretation

| # | Check | What to verify |
|---|-------|----------------|
| 1 | Plot type correctly identified | Forest vs ridge vs league vs network |
| 2 | Reference treatment correct | Usually placebo — verify from plot axis |
| 3 | Rankings match visual | #1 ranked is actually highest/leftmost in plot |
| 4 | CrI crossing null noted | Treatments crossing 1.0 (OR) or 0 (RD) are "not significant" |
| 5 | Uncertainty acknowledged | Wide CrIs = uncertain; narrow = precise |
| 6 | Caveats included | Indirect comparison disclaimer |

---

## Verification Process

### For data extraction:
```
1. Re-read the original source
2. For each row in the extracted table:
   - Find the EXACT number in the source text
   - Confirm endpoint name matches
   - Confirm arm N matches
3. Run derivation check: r/n ≈ y
4. Check completeness: all requested endpoints present?
5. Report: "✓ Verified" or "⚠️ Issues found: [list]"
```

### For slides:
```
1. Cross-reference every number against the extraction table
2. Check slide length (word count)
3. Verify chart data matches
4. Confirm all 5 slides present
5. Check disclaimer
6. Report: "✓ Slides verified" or "⚠️ Issues: [list]"
```

---

## Handling Revisions

When issues are found:

1. **State the issue clearly:** "Slide 3 shows EASI-75 of 63.1% but the extracted data shows 61.3%"
2. **Propose the fix:** "Correcting to 61.3% (from LIBERTY AD SOLO 1, NRI estimand)"
3. **Apply the fix** and show the corrected version
4. **Re-verify** the corrected output

**Common revision triggers from users:**
- "The N is wrong" → re-check source for per-arm N
- "That's the wrong timepoint" → switch to correct week
- "Include the loading dose arm too" → re-extract with additional arm
- "Use observed estimand instead" → switch estimand, recalculate
- "Add safety data" → need to extract additional information

---

## Final Delivery Gate

Before presenting ANY output as final:

- [ ] All QC checks pass (no Error-severity issues)
- [ ] Warnings are explicitly listed for user awareness
- [ ] "Review is required before disclosure" is included
- [ ] Source attribution is complete
- [ ] User has been asked "Does this look correct?" at least once
