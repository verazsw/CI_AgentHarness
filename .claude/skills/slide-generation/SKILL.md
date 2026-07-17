---
name: slide-generation
description: "Generate a 5-slide competitor readout deck summarizing new clinical trial data. Includes Key Summary, Study Design, Efficacy Results with landscape chart, Safety & Competitive Insights, and Development Program. Triggered when user asks for slides, a deck, a presentation, or a readout."
---

# Slide Generation Skill

## When to Use

- User asks for "slides", "a deck", "a presentation", or "a readout"
- User has extracted data and wants it formatted for leadership
- User says "summarize for the team" or "prepare for the meeting"

## Prerequisites

Before generating slides, gather:
1. Extracted efficacy data (use data-extraction skill if needed)
2. Context from ClinicalTrials.gov (study design, endpoints)
3. PubMed abstracts for related studies (competitive context)
4. User's press release text (if provided)
5. BNMA plot image (if user provides one)

## Research Phase

Before writing slides, gather research context:

### Fetch study data from ClinicalTrials.gov:
```bash
curl -s "https://clinicaltrials.gov/api/v2/studies/{NCT_ID}?format=json"
```
Extract: official title, phase, status, arms, interventions, eligibility, sponsor.

### Search for related studies:
```bash
curl -s "https://clinicaltrials.gov/api/v2/studies?query.intr={drug_name}&query.cond={indication}&format=json&pageSize=5"
```

### Search PubMed for competitor context:
```bash
curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term={drug_name}+{indication}+phase+3&retmode=json&retmax=3"
```

---

## The 5-Slide Structure

### Slide 1: Key Summary (What leadership needs in 30 seconds)

**Content:** 3-5 bullets covering:
- What drug, what indication, what phase, what stage
- Top-line primary endpoint result (number vs placebo, p-value)
- How it compares to current landscape (better/similar/worse than standard)
- Any surprises or implications for Lilly
- Safety signal if notable

**Format per bullet:**
```
• [Drug] [dose] achieved [X]% [endpoint] at Wk[Y] (vs [Z]% PBO; p[value])
• This is [higher/similar/lower] than [comparator] [A]% in [study name]
• [Implication for Lilly compound or strategy]
```

### Slide 2: Study Design

**Content:** Structured summary of:
- Study name / NCT ID / Phase
- Arms: drug name, dose, frequency, route for each
- Population: key inclusion criteria, severity requirements, prior treatment
- Primary endpoint definition
- Key secondary endpoints
- Assessment timepoints
- Sample size per arm (with allocation ratio)
- Randomization and blinding

### Slide 3: Efficacy Results + Landscape Chart

**Content:**
- Primary endpoint result: response rate with CI and p-value per arm
- Key secondary endpoints
- Landscape bar chart: the new data plotted alongside all known competitors at the same endpoint/timepoint

**Chart specification:**
- X-axis: treatment names (drug + dose)
- Y-axis: response rate (%)
- Color: Lilly red (#C8102E) for the new data, gray (#999999) for known competitors
- Error bars: 95% CI where available
- Title: "[Endpoint] at Week [X] — Competitive Landscape"
- Footnote: "Cross-trial comparison for illustrative purposes only"
- Include placebo bar as reference

**To generate the chart** (R code):
```r
library(ggplot2)
chart_data <- data.frame(
  treatment = c("Drug A 300mg Q2W", "Drug B 200mg QD", "Placebo"),
  outcome = c(61.3, 55.0, 14.7),
  ci_lower = c(54.2, 47.0, 8.9),
  ci_upper = c(68.4, 63.0, 20.5),
  is_new = c(TRUE, FALSE, FALSE)
)
p <- ggplot(chart_data, aes(x = reorder(treatment, outcome), y = outcome)) +
  geom_col(aes(fill = is_new), width = 0.7) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), width = 0.2) +
  scale_fill_manual(values = c("FALSE" = "#999999", "TRUE" = "#C8102E")) +
  coord_flip() +
  labs(title = "EASI-75 at Week 16", x = NULL, y = "Response Rate (%)",
       caption = "Cross-trial comparison for illustrative purposes only.\nReview is required before disclosure.") +
  theme_minimal() + theme(legend.position = "none")
ggsave("landscape_chart.png", p, width = 10, height = 6, dpi = 150)
```

### Slide 4: Safety & Competitive Insights

**Content:**
- Key safety findings (discontinuation rates, notable AEs, serious AEs)
- How safety profile compares to competitors
- Differentiation factors (onset of action, durability, convenience)
- Cross-trial context caveats

### Slide 5: Development Program & Implications

**Content:**
- Ongoing/planned studies for this drug
- Expected regulatory timelines
- Implications for Lilly's competitive positioning
- Strategic considerations

---

## Dual Output Format

For each slide, produce TWO versions:

### ANALYSIS (for the analyst reading the deck)
- Full detail, can be longer
- Include specific numbers, study references, caveats
- This is what goes in the speaker notes or appendix

### SLIDE (for the PowerPoint text)
- MAX 80 words per slide
- MAX 20 words per bullet
- Fragment style — no full sentences
- Numbers and comparisons, not prose

**Example:**
```
### ANALYSIS
Dupilumab 300mg Q2W achieved EASI-75 of 61.3% at Week 16 (95% CI: 54.2–68.4%)
versus 14.7% placebo (p<0.001) in LIBERTY AD SOLO 1 (N=224 active, N=109 placebo).
This is comparable to lebrikizumab 250mg Q2W (58.8% in ADvocate 1) and lower than
abrocitinib 200mg QD (61.0% in JADE MONO-2). NRI estimand used.

### SLIDE
• EASI-75: 61.3% vs 14.7% PBO (p<0.001) at Wk16
• Comparable to lebrikizumab (58.8%), below abrocitinib (61.0%)
• N=224 active, N=109 PBO; NRI estimand
```

---

## Output Delivery

Present slides as structured text:

```
---
SLIDE 1: KEY SUMMARY
---
### ANALYSIS
[detailed content]

### SLIDE
• Bullet 1
• Bullet 2
• Bullet 3

---
SLIDE 2: STUDY DESIGN
---
[...]
```

If the user asks for a file, generate the chart PNG via R and offer to help create PPTX.

---

## Style Rules

- Lilly red (#C8102E) for accent and new data
- Gray (#999999) for existing competitor data
- Font: Arial for body
- Every slide footer: "Review is required before disclosure"
- Footnotes: data source, study name, estimand used
- Cross-trial comparison caveat on landscape slides

---

## Saving as PPTX File (REQUIRED)

After generating slide content, you MUST save it as a `.pptx` file using the Lilly corporate template. Use R `officer` package:

**Template location:** `templates/lilly-template.pptx` (in the project folder)

**R code to generate the PPTX:**

```r
library(officer)

# Read the Lilly corporate template
pptx <- read_pptx("templates/lilly-template.pptx")

# Get available slide layouts from the template
layout_summary(pptx)  # Run this first to see what layouts exist

# Add slides using the template's layouts
# Layout "Title Slide" = red background title (slide 1)
# Layout "Title and Content" or similar = bullet slides (slides 2-5)

# Slide 1: Title
pptx <- add_slide(pptx, layout = "Title Slide", master = "Office Theme")
pptx <- ph_with(pptx, value = "Competitor Landscape Update: [Drug Name]",
                 location = ph_location_type(type = "ctrTitle"))
pptx <- ph_with(pptx, value = "[Indication] — [Date]",
                 location = ph_location_type(type = "subTitle"))

# Slides 2-5: Content slides
pptx <- add_slide(pptx, layout = "Title and Content", master = "Office Theme")
pptx <- ph_with(pptx, value = "Key Summary",
                 location = ph_location_type(type = "title"))
pptx <- ph_with(pptx, value = c(
  "Bullet 1: top-line result",
  "Bullet 2: comparison to landscape",
  "Bullet 3: implication"
), location = ph_location_type(type = "body"))

# Add chart image (if generated)
# pptx <- add_slide(pptx, layout = "Title and Content", master = "Office Theme")
# pptx <- ph_with(pptx, value = external_img("landscape_chart.png", width = 9, height = 5),
#                  location = ph_location(left = 0.5, top = 1.5, width = 9, height = 5))

# Add footer to all slides
# pptx <- on_slide(pptx, index = 1)  # etc.

# Save
output_path <- paste0("competitor_deck_", format(Sys.Date(), "%Y%m%d"), ".pptx")
print(pptx, target = output_path)
cat("Saved:", output_path, "\n")
```

**Important notes on the Lilly template:**
- The template has a red title slide layout (Lilly branding)
- Use `layout_summary(pptx)` to discover exact layout names available
- Font: Times New Roman for headers, Arial for body (the template enforces this)
- Footer: "Company Confidential © 2026 Eli Lilly and Company" is in the template
- Always add "Review is required before disclosure" as a text box or in the body

**Output location:** Save the file in the current working directory. Tell the user the filename:
```
✓ Saved: competitor_deck_20260717.pptx (in your current folder)
```

---

## References

- See `references/indications.md` for endpoints and comparators
- See `references/lilly-style.md` for branding
