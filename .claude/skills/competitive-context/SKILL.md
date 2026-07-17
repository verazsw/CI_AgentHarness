---
name: competitive-context
description: "Research the competitive landscape for a given indication. Find approved drugs, late-stage pipeline, and compare efficacy data across competitors. Triggered when user asks about the landscape, competitors, or comparison."
---

# Competitive Context Skill

> This file contains instructions for the Claude agent. You don't need to read this — just talk to the agent directly.

## When to Use

- User asks "what's the competitive landscape for AD?"
- User asks to compare a drug against competitors
- User wants context for where new data sits relative to existing treatments
- User asks about approved or pipeline drugs for an indication

## Workflow

### Step 1: Identify indication

Determine the therapeutic area. Refer to `references/indications.md` for the full list and key comparators.

### Step 2: Research approved competitors

For each indication, search for current data using web search:

**Key search queries:**
- "{indication} approved treatments 2024 2025"
- "{drug name} Phase 3 results {endpoint}"
- "{drug name} prescribing information {endpoint} efficacy"

**Known key comparators per indication** (from `references/indications.md`):
- AD: dupilumab/Dupixent, lebrikizumab/Ebglyss, tralokinumab/Adbry, abrocitinib/Cibinqo, upadacitinib/Rinvoq
- UC: adalimumab/Humira, vedolizumab/Entyvio, upadacitinib/Rinvoq, ozanimod/Zeposia
- PSO: secukinumab/Cosentyx, ixekizumab/Taltz, risankizumab/Skyrizi, guselkumab/Tremfya, bimekizumab/Bimzelx
- (see `references/indications.md` for all indications)

### Step 3: Build comparison table

Present a landscape comparison at the default timepoint for the indication:

```
## Competitive Landscape: Atopic Dermatitis — EASI-75 at Week 16

| Drug | Dose | Study | N | EASI-75 (%) | vs Placebo | Estimand | Phase |
|------|------|-------|---|-------------|-----------|----------|-------|
| dupilumab | 300mg Q2W | LIBERTY AD SOLO 1 | 224 | 51.3 | 37.3pp | NRI | 3 |
| lebrikizumab | 250mg Q2W | ADvocate 1 | 283 | 58.8 | 41.4pp | NRI | 3 |
| tralokinumab | 300mg Q2W | ECZTRA 1 | 601 | 25.0 | 9.0pp | NRI | 3 |
| abrocitinib | 200mg QD | JADE MONO-2 | 155 | 61.0 | 51.4pp | NRI | 3 |
| placebo | — | (pooled) | — | ~15 | — | NRI | — |

Notes:
- Cross-trial comparison for context only — not head-to-head
- Different study populations, inclusion criteria, and placebo rates
- BNMA provides formal indirect comparison (see BNMA skill)

Review is required before disclosure.
```

### Step 4: Identify gaps and pipeline

Search for late-stage pipeline:
- "{indication} Phase 3 pipeline 2025 2026"
- ClinicalTrials.gov: `https://clinicaltrials.gov/api/v2/studies?query.cond={condition}&filter.overallStatus=RECRUITING&filter.phase=PHASE3&format=json&pageSize=10`

Flag drugs in Phase 2/3 that could change the landscape.

### Step 5: Contextualize new data

When the user has new data (e.g., just extracted):
- Where does it rank vs existing treatments?
- Is it better/worse/similar to the current standard?
- Any caveats (different population, timepoint, estimand)?

**Always caveat cross-trial comparisons:**
> "This is a naive cross-trial comparison. Differences in study design, patient populations, and placebo rates limit direct comparisons. BNMA provides a more rigorous indirect comparison."

## References

- See `references/indications.md` for comparators and endpoints per indication
