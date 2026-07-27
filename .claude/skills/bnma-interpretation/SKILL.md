---
name: bnma-interpretation
description: "Interpret BNMA (Bayesian Network Meta-Analysis) output images — forest plots, ridge plots, league tables, and network diagrams. Describe findings in plain language: which treatments rank best, credible intervals, probability of being best, and clinical implications."
---

# BNMA Interpretation Skill

## When to Use

- User uploads or references a BNMA forest plot, ridge plot, or league table image
- User asks "what does this BNMA show?" or "which drug is best?"
- User wants BNMA results described for a slide deck or summary
- User asks about indirect comparisons or relative efficacy ranking

## Input Types

### Forest Plot
Shows treatment effects (odds ratios or risk differences) vs a reference treatment (usually placebo). Each treatment has a point estimate + credible interval (CrI) horizontal bar.

**What to extract:**
- Reference treatment (what everything is compared against)
- Each treatment's point estimate
- Each treatment's 95% CrI (credible interval)
- Whether CrI crosses 1.0 (for OR) or 0 (for RD) — indicates statistical significance
- Ranking from best to worst

### Ridge Plot (Density Plot)
Shows the posterior probability distribution for each treatment's effect. Overlapping distributions indicate similar efficacy.

**What to extract:**
- Which treatments have distributions clearly separated from others (= meaningfully different)
- Which treatments overlap substantially (= similar efficacy)
- The mode (peak) of each distribution (= most likely treatment effect)
- The spread of each distribution (narrow = precise estimate; wide = uncertain)

### League Table
Matrix showing pairwise comparisons between all treatments. Each cell contains an effect estimate + CrI.

**What to extract:**
- Head-to-head comparisons of interest (new drug vs established competitors)
- Which comparisons are statistically significant (CrI excludes 1.0 or 0)
- Direction of effect (which treatment is favored in each pair)

### Network Diagram
Shows which treatments are connected by direct evidence (trials). Line thickness = number of studies; node size = number of patients.

**What to extract:**
- Which comparisons have direct evidence vs rely on indirect only
- How well-connected the network is (any disconnected components?)
- Key treatments that serve as bridge nodes (usually placebo)

---

## Interpretation Workflow

### Step 1: Identify the plot type and context

- What type of plot is this? (forest, ridge, league, network)
- What endpoint? (EASI-75, IGA 0/1, ACR20, etc.)
- What timepoint?
- What's the reference treatment?
- What model? (random effects vs fixed effects)

### Step 2: Read the data from the image

Carefully extract numerical values visible in the plot:
- Point estimates
- Credible interval bounds
- Treatment names/labels
- Any probability rankings (P(best), SUCRA, etc.)

### Step 3: Describe findings in plain language

**For leadership/non-statisticians:**
```
Key findings from the [endpoint] BNMA at Week [X]:

1. RANKING: [Drug A] ranks highest with [OR/RR] of [X] (95% CrI: [Y–Z]) vs placebo
2. COMPARISON: [Drug B] is [statistically similar to / significantly better than / significantly worse than] [Drug A] — the difference [does/does not] exclude the null
3. UNCERTAINTY: [Drug C] has a wide credible interval, suggesting limited evidence
4. CLINICAL: The top [N] treatments are [all JAK inhibitors / all biologics / a mix], suggesting [class effect / differentiation within class]
```

**For the slide deck (concise):**
```
• [Drug A] ranks #1: OR [X] (CrI: [Y–Z]) vs PBO
• [Drug B] comparable: OR [X] (CrI overlaps Drug A)
• [New drug] positions [above/below] [comparator] in the ranking
```

### Step 4: Contextualize for Lilly

- Where does the Lilly compound (or competitor to Lilly) rank?
- Has the ranking changed from previous BNMA? (if user provides context)
- What does this mean for competitive positioning?

---

## Important Caveats (always include)

1. **Indirect comparison:** "BNMA results are based on indirect comparisons across different trials. Direct head-to-head data is more reliable where available."

2. **Heterogeneity:** "Differences in study populations, placebo rates, and study designs may affect comparisons."

3. **Credible intervals vs confidence intervals:** "CrIs are Bayesian credible intervals — 95% probability the true value lies within this range (different from frequentist CIs)."

4. **SUCRA/P(best) interpretation:** "A higher SUCRA or P(best) indicates a greater probability of being the best treatment, but should be interpreted alongside the CrI width."

---

## Output for Slides

When this interpretation feeds into slide generation, provide:

```
BNMA Context (for Slide 5):

ANALYSIS:
[Full interpretation with numbers, caveats, clinical meaning]

SLIDE:
• [Drug A] ranks #1 for [endpoint] (OR [X]; CrI: [Y–Z])
• [New drug] positions [where] in the ranking
• Network includes [N] treatments from [N] trials
• [Key clinical implication in one sentence]

Footnote: Random-effects BNMA; NRI estimand; indirect comparison only.
```

---

## Output for Slide Embedding

When this skill is invoked from the **slide-generation** skill (BNMA plots found in `figures/`), provide structured output in two formats:

### For Key Summary bullet (Quick mode — 1 sentence):

```
BNMA: [Drug] ranks #[N] for [endpoint] at [timepoint] (OR [X]; CrI: [Y–Z]) — [above/below] lebrikizumab
```

### For Interpretation Card (Detailed mode — 3-4 bullets for the 30% panel):

```
• [Drug] ranks #[N] for [endpoint] (OR [X]; CrI: [Y–Z])
• [Significantly better/comparable to/below] [comparator] (CrI [overlaps/excludes] null)
• Network: [N] treatments from [N] trials; [random/fixed] effects model
• [Key clinical takeaway in one sentence]
```

### Footnote (always include on BNMA slides):

```
Random-effects BNMA; [estimand if known]; indirect comparison only.
```

### Speaker Notes (for the BNMA slide):

Provide the full ANALYSIS-level interpretation including:
- Complete ranking of all visible treatments
- CrI bounds for key comparisons
- Network connectivity notes
- Heterogeneity assessment
- Caveats specific to this analysis
- How this ranking has changed (if user provides prior BNMA context)

---

## References

- See `references/indications.md` for endpoint codes and comparators
- See `references/extraction-rules.md` for estimand definitions
