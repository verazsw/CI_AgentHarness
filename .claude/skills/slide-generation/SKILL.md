---
name: slide-generation
description: "Generate 1) a 5-slide competitor readout deck summarizing new competitor clinical trial data or 2) a detailed readout slide deck for presenters to prepare and select information from. Includes BNMA plot integration, compound-specific landscape charts, and polished pptxgenjs output."
---

# Slide Generation Skill

## When to Use

- User asks for "slides", "a deck", "a presentation", or "a readout"
- User has extracted data and wants it formatted for leadership
- User says "summarize for the team" or "prepare for the meeting"
- User says "detailed deck" or "presenter prep" or "full readout"

## Mode Selection

Ask the user which mode, OR detect from their phrasing:

| Mode | Trigger Phrases | Output |
|------|----------------|--------|
| **Quick** (default) | "quick readout", "5-slide deck", "leadership briefing", "summary deck" | 5 slides |
| **Detailed** | "detailed deck", "presenter deck", "full readout", "deep dive", "presenter prep" | 8 fixed + 1 per BNMA plot |

If unclear, ask: "Quick 5-slide leadership briefing, or detailed presenter-prep deck?"

---

## Prerequisites

Before generating slides, gather information in this **priority order**:

1. **Lilly CILand article (INTERNAL — highest value if available)**
   - The Competitive Intelligence team publishes curated articles on SharePoint: `collab.lilly.com/sites/CILand/`
   - If user provides a CILand URL → fetch the page content and extract data, figures, and analysis
   - If user mentions a compound without a source → ask: "Is there a CILand article for this? The CI team may have already published an analysis."
   - CILand articles often include: summary, MOA, efficacy data tables, figures, competitive context, and strategic assessment
   - **How to use:** User pastes the SharePoint URL. Agent fetches with `curl` (may require authentication token). Extract text content, data tables, and any embedded figures.
   - > "Do you have the CILand article link? If the CI team has published on this, it's the best starting point — it's already curated with data and strategic context."

2. **Press release (PRIMARY EXTERNAL SOURCE)**
   - Ask user: "Do you have the press release? Is it a URL, pasted text, PDF, or PPTX?"
   - If PDF or PPTX: ask user to convert to image files (PNG/JPEG) and drop them in `figures/` folder
     > "Could you convert the press release pages to PNG images and drop them in the `figures/` folder? On Mac: open in Preview → File → Export → PNG. You only need the pages with figures you want embedded (study design, efficacy charts, safety tables)."
   - Extract all efficacy data, study design, safety signals from the press release FIRST

3. **Check `figures/` and `BNMA_output/` folders for BNMA plot PNGs** — if present (matching naming convention `{compound}_{endpoint}_{timepoint}_{date}.png`), interpret each for slide content

4. **ClinicalTrials.gov** — supplement with study design details, arms, sample size (only if press release is incomplete)

5. **PubMed** — search for related studies and competitive context (only if needed for landscape comparison)

**Key principle:** CILand articles (internal) and press releases (external) are the primary sources. ClinicalTrials.gov and PubMed are supplementary for gap-filling and landscape context.

## Figure Inventory (Run FIRST — Before Research)

Before gathering any data, catalog all available figures in the `figures/` directory. This ensures relevant images are embedded in the deck whether or not the user mentions them.

### Step 1: List all figures

```bash
ls -1 figures/ 2>/dev/null | grep -vE '^\.|README'
```

### Step 2: Classify each file by filename pattern

| Pattern | Classification | Action |
|---------|---------------|--------|
| Starts with uppercase letter + underscore (e.g., `APG777_EASI75_...`) | **BNMA plot** | Auto-include on BNMA slides |
| `page-*.png` or `page-*.jpg` | **Press release page** | Visually scan and classify (Step 3) |
| `study_design*.*` | **Study design figure** | Embed on Study Design slide |
| `efficacy*.*` or `*_efficacy_*.*` | **Efficacy chart** | Embed on Efficacy Results slide |
| `forest_plot*.*` | **Forest plot** | Embed on competitive comparison or subgroup slide |
| `safety*.*` | **Safety figure** | Embed on Safety slide |
| `landscape*.*` or `competitive*.*` | **Landscape chart** | Embed on Competitor Landscape slide |
| Any other `.png`/`.jpg`/`.jpeg` | **Unknown** | Visually inspect and classify into one of the above roles |

### Step 3: Visually classify press release pages (page-*.png)

If `page-*.png` files exist, visually read **EACH** page image and assign one of these roles:

| Role | What to look for | Slide placement |
|------|-----------------|-----------------|
| `study_design` | Randomization diagram, CONSORT flow, dosing schema, trial schematic | Study Design slide (`rightImage` in twoColumn, or dedicated `image` slide) |
| `efficacy_curve` | Line plots over time, bar charts of response rates, Kaplan-Meier | Efficacy Results (dedicated `image` slide after text results) |
| `competitive_chart` | Cross-trial comparison bars/tables from sponsor | Competitive Landscape (dedicated `image` slide after table) |
| `forest_plot` | Forest plot, subgroup analysis figure | Dedicated `image` slide after relevant efficacy section |
| `safety_table` | AE table, safety summary figure, lab results | Safety slide (embed or reference in speaker notes) |
| `informational` | Text-heavy pages, logos, legal disclosures, title pages | Do NOT embed — extract data only |

### Step 4: Build a figure manifest

Before proceeding to research, output a manifest in your working memory:

```
FIGURE MANIFEST:
- figures/APG777_EASI75_Wk16_2026-07-20.png → BNMA (EASI-75, Wk16)
- figures/page-08.png → competitive_chart (cross-trial bar chart)
- figures/page-10.png → study_design (randomization diagram)
- figures/page-14.png → efficacy_curve (EASI-75 time course)
- figures/study_design_APEX.png → study_design (auto-routed by name)
```

### Step 5: Route figures to slide positions

Use this routing table when building the JSON config slides array:

| Figure role | Slide type | Position in deck |
|-------------|-----------|------------------|
| `study_design` | `twoColumn` with `rightImage`, or dedicated `image` slide | After MOA / Drug Overview slides |
| `efficacy_curve` | `image` slide | Immediately after efficacy results text slide |
| `competitive_chart` | `image` slide | After competitor table slide |
| `forest_plot` | `image` slide | After relevant efficacy/BNMA section |
| `safety_table` | `image` slide or embedded in content slide | Within safety section |
| BNMA plot | `bnma` slide | Dedicated BNMA section (one slide per plot) |

**Rules:**
- If no figures exist for a slide slot → use text-only layout (never invent or describe a missing figure)
- If multiple figures match the same role → include all as separate slides (e.g., two efficacy curves = two image slides)
- Always add a source disclaimer on figure slides: "Source: [Sponsor] [publication/press release]. Review is required before disclosure."
- If the user provides a press release but no page images exist in `figures/` → prompt them to convert: "Could you convert the press release pages with figures to PNG and drop them in `figures/`?"

---

## Research Phase

> **Important:** Run the Figure Inventory above FIRST. The classified figures inform which slide types, layouts, and how many slides to include.

### Step 1: Press release (always first)

Ask the user for the press release source. If they have a PDF or PPTX:
> "Could you convert the press release to image files (PNG or JPEG)? I can extract information more accurately from images than raw PDF/PPTX."

Once provided, extract from the press release:
- All efficacy results (primary + secondary endpoints, response rates, CIs, p-values)
- Study design (arms, doses, population, randomization)
- Safety signals (AEs, discontinuation rates)
- Any figures (study design diagrams, efficacy charts) — embed these directly, do NOT re-generate

### Step 2: Supplement from ClinicalTrials.gov (if needed)

Only fetch if the press release is missing key details (sample size, allocation ratio, exact I/E criteria):

```bash
curl -s "https://clinicaltrials.gov/api/v2/studies/{NCT_ID}?format=json"
```

Search for related studies (for landscape context):
```bash
curl -s "https://clinicaltrials.gov/api/v2/studies?query.intr={drug_name}&query.cond={indication}&format=json&pageSize=5"
```

### Step 3: PubMed (for competitive context only)

```bash
curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term={drug_name}+{indication}+phase+3&retmode=json&retmax=3"
```

---

## BNMA Integration Workflow

> **Note:** BNMA plots are already identified during the Figure Inventory step above. This section covers interpretation and routing of those plots.

### Step 1: Check for BNMA plots

```bash
ls figures/*.png figures/*.jpg figures/*.jpeg BNMA_output/*.png BNMA_output/*.jpg 2>/dev/null | grep -E '/[A-Z]'
```

This filters for BNMA plots (which start with a compound code like `APG777_`) vs press release pages (which start with `page-`). Plots may be in either `figures/` or `BNMA_output/`.

### Step 2: Parse filenames

Extract compound, endpoint, and timepoint from filename convention `{compound}_{endpoint}_{timepoint}_{date}.{png|jpg}`:
- `APG777_EASI75_Wk16_2026-07-20.png` → compound: APG777 (zumilokibart), endpoint: EASI-75, timepoint: Week 16
- `APG777_IGA01_Wk16_2026-07-20.jpg` → compound: APG777 (zumilokibart), endpoint: IGA 0/1, timepoint: Week 16

### Step 3: Interpret each plot

For each PNG, apply the **bnma-interpretation** skill logic:
1. Identify plot type (forest, ridge, league table, network)
2. Read numerical data from the image (point estimates, CrIs, rankings)
3. Describe findings in plain language
4. Contextualize for Lilly (where does lebrikizumab rank?)

### Step 4: Route to slides

- **Quick mode:** Distill into 1 bullet for Key Summary:
  `"BNMA ranking: [Drug] #[N] for [endpoint] (OR [X]; CrI: [Y–Z]) — [above/below] lebrikizumab"`
- **Detailed mode:** Full interpretation card per plot (3-4 bullets + footnote)

---

## Quick Mode: 5-Slide Structure

### Slide 1: Key Summary (What leadership needs in 30 seconds)

**Content:** 3-5 bullets covering:
- What drug, what indication, what phase, what stage
- Top-line primary endpoint result (number vs placebo, p-value)
- How it compares to current landscape (better/similar/worse than standard)
- Any difference compared with this drug previous studies if there are any
- **BNMA ranking insight** (if plots available in `figures/`)
- Any surprises or implications for Lilly

**Format per bullet:**
```
• [Drug] [dose] achieved [X]% [endpoint] at Wk[Y] (vs [Z]% PBO; p[value])
• This is [higher/similar/lower] than [comparator] [A]% in [study name]
• BNMA: [Drug] ranks #[N] for [endpoint] — [above/below] lebrikizumab
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

**Figure embedding:** If the figure manifest contains a `study_design` figure (either a named file like `study_design_*.png` or a classified `page-*.png`), embed it using `rightImage` in a `twoColumn` layout (text left, figure right). If the study design figure is complex/detailed, use a dedicated `image` slide instead.

If press release has a detailed PDF file or PPTX file, ask user to convert it to image files (PNG, JPEG, etc.) and provide it. If the press release contains a study design figure, embed it directly on this slide — do NOT re-generate the design figure.

### Slide 3: Efficacy Results + Landscape Chart

**Content:**
- Primary endpoint result: response rate with CI and p-value per arm
- Key secondary endpoints
- Landscape bar chart: the new data plotted alongside all known competitors

**Figure embedding:** Check the figure manifest for `efficacy_curve` or `competitive_chart` figures. If an efficacy time-course figure exists (from press release or named file), add a dedicated `image` slide immediately after this slide to show the original figure. Do not re-generate figures that already exist in the source material — embed originals directly.

**Chart specification (for generated landscape chart):**
- X-axis: treatment names (drug + dose)
- Y-axis: response rate (%)
- Colors: compound-specific (see Compound Color Palette below)
- Error bars: 95% CI where available
- Title: "[Endpoint] at Week [X] — Competitive Landscape"
- Footnote: "Cross-trial comparison for illustrative purposes only. Review is required before disclosure."
- Include placebo bar as reference (gray)

**Chart R code** (saved as `landscape_chart.png` for embedding):
```r
library(ggplot2)

# Compound color map
compound_colors <- c(
  "lebrikizumab" = "#E1251B",
  "dupilumab" = "#0F3A85",
  "tralokinumab" = "#144B2D",
  "abrocitinib" = "#7B2D8B",
  "upadacitinib" = "#D4570A",
  "nemolizumab" = "#4A90A4",
  "rocatinlimab" = "#8B6914",
  "placebo" = "#999999"
)

# Build chart_data from extracted data + database
# chart_data must have columns: treatment, outcome, ci_lower, ci_upper, compound

p <- ggplot(chart_data, aes(x = reorder(treatment, outcome), y = outcome, fill = compound)) +
  geom_col(width = 0.7) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), width = 0.2) +
  scale_fill_manual(values = compound_colors, guide = "none") +
  coord_flip() +
  labs(
    title = paste0(endpoint, " at Week ", timepoint, " — Competitive Landscape"),
    x = NULL, y = "Response Rate (%)",
    caption = "Cross-trial comparison for illustrative purposes only.\nReview is required before disclosure."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "none"
  )
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

## Detailed Mode: 8+N Slide Structure

### Slide 1: Title Slide

| Element | Content |
|---------|---------|
| Main title | "Competitor Landscape Update: [Drug Name]" |
| Subtitle | "[Indication] — [Data Release Type] (e.g., Phase 3 Data, Conference Presentation)" |
| Date | Meeting date |
| Confidentiality | "CONFIDENTIAL — For Internal Use Only" |
| Disclaimer | "Review is required before disclosure." (smaller font, bottom) |
| Speaker notes | Brief context: why this update matters, what the audience will learn |

### Slide 2: Drug Overview

A high-level profile card for the new competitor drug.

| Element | Content |
|---------|---------|
| Drug name | Generic name (code name) |
| Sponsor | Company name |
| Modality | e.g., monoclonal antibody, JAK inhibitor, bispecific |
| Target | Molecular target (e.g., IL-13, IL-31, OX40) |
| Dosing | Route, dose, frequency |
| Development stage | Phase and indication |
| Competitive positioning | One-sentence summary of where this drug fits |
| Speaker notes | Sponsor pipeline strategy, prior successes/setbacks |

### Slide 3: Mechanism of Action

| Element | Content |
|---------|---------|
| Pathway description | How the drug works, where it intervenes |
| Differentiation | How this MOA differs from established therapies |
| Key differentiators | 2–3 bullets on what makes this MOA interesting or concerning |
| Speaker notes | Deeper mechanistic context, preclinical data, class effects |

### Slide 4: Study Design & Key Results

Two-section layout (left/right or top/bottom):

| Section | Content |
|---------|---------|
| **Study Design** (left) | Phase, N, arms, randomization, duration, primary endpoint, key I/E |
| **Key Results** (right) | Primary result, key secondaries, dose-response, safety highlights |
| Baseline characteristics | Disease severity, demographics summary |
| Speaker notes | Design caveats, how baseline severity compares to other trials |

**Figure embedding:** Check the figure manifest for `study_design` and `efficacy_curve` figures. If a study design figure exists, embed it using `rightImage` in a twoColumn layout or as a dedicated image slide. If efficacy figures (time-course plots, bar charts) exist, add dedicated `image` slides after this slide. If a `competitive_chart` figure exists from the press release, add it after the competitor table slide. Never re-generate a figure that already exists in the source material — embed the original.

### Slide 5: Broader Competitor Comparison

| Element | Content |
|---------|---------|
| Table columns | Drug, Sponsor, MOA/Target, Route, Phase/Status, Efficacy, Safety Signal |
| Rows | 4–8 drugs: new competitor, Lilly's drug, 3–6 approved/late-stage |
| Highlighting | Lilly in brand red; new competitor in contrasting accent |
| Caveats footnote | "Cross-trial comparisons are indirect..." |
| Speaker notes | Which comparisons are most/least reliable, placebo rate differences |

**Figure embedding:** If the figure manifest contains a `competitive_chart` or `landscape` figure, add a dedicated `image` slide immediately after this table slide to show the original competitive comparison figure from the source material.

### Slide 6: Head-to-Head vs Lilly Drug

Two-card layout side by side:

| Left Card: "Similarities" | Right Card: "Differences" |
|---------------------------|--------------------------|
| Shared patient population | Different MOA |
| Overlapping endpoints | Different route/dosing |
| Comparable efficacy class | Different safety profile |
| | Program maturity gap |

Speaker notes: nuanced assessment of which differences matter most clinically and commercially.

### Slides 7+: BNMA Results (One Slide Per Plot)

**Only generated if BNMA PNG files exist in `figures/`.** One slide per plot.

| Element | Content |
|---------|---------|
| Slide title | "BNMA: [Endpoint] at [Timepoint]" — parsed from filename |
| Image | Left side (~70% width): the BNMA ridge/forest plot |
| Interpretation card | Right side (~30% width): 3–4 bullet interpretation |
| Interpretation content | Ranking, comparison to Lilly drug, surprising findings, CrI width |
| Caveats | BNMA limitations footnote |
| Speaker notes | Detailed interpretation, network structure, sensitivity notes |

**Layout coordinates:**
- Image: x=0.3, y=1.05, w≈6.5, h≈3.9 (preserve aspect ratio)
- Interpretation card: x≈7.0, y=1.05, w≈2.7, h≈3.9

### Second-to-Last Slide: Implications for Lilly Strategy

Two-card layout:

| Left Card: "Competitive Threat" | Right Card: "Mitigating Factors" |
|--------------------------------|----------------------------------|
| 3–4 bullets on concerns | 3–4 bullets on Lilly advantages |
| Differentiated MOA, strong efficacy | Broader data, safety record |
| Convenient dosing, etc. | Established market, label breadth |

Speaker notes: probability of success, expected timelines, scenarios.

### Last Slide: Summary & Key Takeaways

| Element | Content |
|---------|---------|
| Takeaways | 4–5 numbered key takeaways, each one sentence |
| Recommended actions | 1–2 concrete next steps |
| Speaker notes | "So what" recap, open questions for discussion |

---

## Dual Output Format

For each slide, produce TWO versions:

### ANALYSIS (for the analyst / speaker notes)
- Full detail, can be longer
- Include specific numbers, study references, caveats
- Include source URLs
- This goes in speaker notes

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
BNMA ranking: #2 after abrocitinib 200mg (OR 1.05 favoring abrocitinib; CrI overlaps).
Source: https://clinicaltrials.gov/study/NCT02277743

### SLIDE
• EASI-75: 61.3% vs 14.7% PBO (p<0.001) at Wk16
• BNMA: ranks #2, comparable to abrocitinib (CrI overlaps)
• N=224 active, N=109 PBO; NRI estimand
```

---

## Speaker Notes Requirements (Both Modes)

**Every slide MUST have speaker notes** containing:
- Additional context not on the slide (to keep slides clean)
- Caveats and limitations relevant to that slide's content
- Talking points for the presenter
- Data sources and references with full URLs
- Anticipated audience questions and suggested responses

---

## PPTX Generation (python-pptx — REQUIRED)

After generating all slide content, you MUST create the `.pptx` file using the Python script with a JSON config.

### Generate the deck:

1. Write a JSON config file to `configs/{compound}_{study}_{date}.json` with the slide content
2. Run:

```bash
python3 scripts/generate_deck.py configs/{compound}_{study}_{date}.json
```

**JSON config structure:**
```json
{
  "mode": "detailed",
  "outputFile": "Compound_Study_Mode_Date.pptx",
  "slides": [
    {"type": "title", "title": "...", "subtitle": "...", "date": "...", "speakerNotes": "..."},
    {"type": "content", "title": "...", "sections": [{"header": "...", "bullets": [...], "x": 0.5, "y": 1.15, "w": 12.3, "h": 5.5}], "speakerNotes": "..."},
    {"type": "twoColumn", "title": "...", "leftColumn": {"header": "...", "bullets": [...]}, "rightColumn": {"header": "...", "bullets": [...]}, "speakerNotes": "..."},
    {"type": "image", "title": "...", "imagePath": "figures/page-10.png", "speakerNotes": "..."},
    {"type": "bnma", "title": "BNMA: EASI-75 at Wk16", "imagePath": "figures/APG777_EASI75_Wk16_2026-07-20.png", "interpretation": ["...", "..."], "speakerNotes": "..."},
    {"type": "table", "title": "...", "table": {"headers": [...], "rows": [[...]]}, "speakerNotes": "..."},
    {"type": "summary", "title": "...", "takeaways": ["...", "..."], "actions": ["...", "..."], "speakerNotes": "..."}
  ]
}
```

**Image paths in JSON:** Use relative paths from project root (e.g., `"figures/page-10.png"`). The script resolves them to absolute paths automatically.

**Config naming convention:** `configs/{compound}_{study}_{date}.json`
- `configs/zumilokibart_apex_2026-07-29.json`
- `configs/envudeucitinib_zasocitinib_pso_2026-07-29.json`

**Benefits of JSON configs:**
- Previous deck configs are preserved (can regenerate any deck without re-extracting data)
- No risk of overwriting the script
- Version-controllable
- Run `python3 scripts/generate_deck.py` (no args) to see available configs

### pptxgenjs Design System

**Constants:**
```javascript
const PRIMARY_COLOR = "E1251B";        // Lilly Red 2024 (from template theme)
const CONTENT_BG = "FBF5F5";           // Light neutral tinted from red
const CARD_BG = "FFFFFF";              // White
const BODY_TEXT = "212121";            // Dark gray (template dk1)
const WHITE_TEXT = "FFFFFF";
const ACCENT_TEXT = "FFC709";          // Gold highlight on dark backgrounds (template accent5)
const CAVEAT_COLOR = "666666";         // Medium gray
const HEADER_FONT = "Arial";
const BODY_FONT = "Arial";
```

**Compound colors (for charts):**
```javascript
const COMPOUND_COLORS = {
  lebrikizumab: "E1251B",
  dupilumab: "0F3A85",
  tralokinumab: "144B2D",
  abrocitinib: "7B2D8B",
  upadacitinib: "D4570A",
  nemolizumab: "4A90A4",
  rocatinlimab: "8B6914",
  placebo: "999999",
  other: "999999"
};
```

**Card helper:**
```javascript
function card(slide, x, y, w, h) {
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x, y, w, h,
    fill: { color: CARD_BG },
    rectRadius: 0.1,
    shadow: {
      type: "outer", color: "000000",
      blur: 6, offset: 2, angle: 135, opacity: 0.1
    },
  });
  return { x: x + 0.25, y: y + 0.1, w: w - 0.5, h: h - 0.2 };
}
```

**Top bar (content slides):**
```javascript
function addTopBar(slide, title) {
  slide.addShape(pres.shapes.RECTANGLE, {
    x: 0, y: 0, w: 10, h: 0.95,
    fill: { color: PRIMARY_COLOR }
  });
  slide.addText(title, {
    x: 0.6, y: 0.05, w: 8.5, h: 0.85,
    fontSize: 24, fontFace: HEADER_FONT,
    color: WHITE_TEXT, bold: true, valign: "middle", margin: 0
  });
}
```

**Footer bar (content slides):**
```javascript
function addFooter(slide, text) {
  slide.addShape(pres.shapes.RECTANGLE, {
    x: 0, y: 5.15, w: 10, h: 0.475,
    fill: { color: PRIMARY_COLOR }
  });
  slide.addText(text || "Review is required before disclosure.", {
    x: 0.5, y: 5.17, w: 9, h: 0.43,
    fontSize: 9, fontFace: BODY_FONT,
    color: WHITE_TEXT, valign: "middle"
  });
}
```

**BNMA slide (image + interpretation card):**
```javascript
function addBnmaSlide(pres, title, imagePath, interpretation, speakerNotes) {
  const slide = pres.addSlide({ bkgd: CONTENT_BG });
  addTopBar(slide, title);

  // BNMA plot image (left 70%)
  slide.addImage({
    path: imagePath,
    x: 0.3, y: 1.05, w: 6.5, h: 3.9,
    sizing: { type: "contain", w: 6.5, h: 3.9 }
  });

  // Interpretation card (right 30%)
  const c = card(slide, 7.0, 1.05, 2.7, 3.9);
  slide.addText("Key Findings", {
    x: c.x, y: c.y, w: c.w, h: 0.3,
    fontSize: 12, fontFace: HEADER_FONT, color: PRIMARY_COLOR, bold: true
  });
  slide.addText(interpretation.map((bullet, i) => ({
    text: bullet,
    options: {
      fontSize: 10.5, fontFace: BODY_FONT, color: BODY_TEXT,
      bullet: true, breakLine: i < interpretation.length - 1
    }
  })), { x: c.x, y: c.y + 0.35, w: c.w, h: c.h - 0.4 });

  addFooter(slide, "Random-effects BNMA; indirect comparison only. Review is required before disclosure.");
  slide.addNotes(speakerNotes);
}
```

**Title slide:**
```javascript
function addTitleSlide(pres, title, subtitle, date) {
  const slide = pres.addSlide({ bkgd: PRIMARY_COLOR });
  slide.addText(title, {
    x: 1, y: 1.5, w: 8, h: 1.5,
    fontSize: 34, fontFace: HEADER_FONT,
    color: WHITE_TEXT, bold: true, align: "center", valign: "middle"
  });
  slide.addText(subtitle, {
    x: 1, y: 3.0, w: 8, h: 0.8,
    fontSize: 17, fontFace: BODY_FONT,
    color: "F5D6B0", align: "center"
  });
  slide.addText(date + "\nCONFIDENTIAL — For Internal Use Only", {
    x: 1, y: 4.2, w: 8, h: 0.8,
    fontSize: 11, fontFace: BODY_FONT,
    color: WHITE_TEXT, align: "center"
  });
  slide.addText("Review is required before disclosure.", {
    x: 1, y: 5.0, w: 8, h: 0.4,
    fontSize: 9, fontFace: BODY_FONT,
    color: "F5D6B0", italic: true, align: "center"
  });
}
```

**Content slide with bullet cards:**
```javascript
function addContentSlide(pres, title, cards, speakerNotes, footerText) {
  const slide = pres.addSlide({ bkgd: CONTENT_BG });
  addTopBar(slide, title);

  // cards is array of { header, bullets, x, y, w, h }
  cards.forEach(({ header, bullets, x, y, w, h }) => {
    const c = card(slide, x, y, w, h);
    slide.addText(header, {
      x: c.x, y: c.y, w: c.w, h: 0.3,
      fontSize: 13, fontFace: HEADER_FONT, color: PRIMARY_COLOR, bold: true
    });
    slide.addText(bullets.map((b, i) => ({
      text: b,
      options: {
        fontSize: 11, fontFace: BODY_FONT, color: BODY_TEXT,
        bullet: true, breakLine: i < bullets.length - 1
      }
    })), { x: c.x, y: c.y + 0.35, w: c.w, h: c.h - 0.4 });
  });

  addFooter(slide, footerText);
  slide.addNotes(speakerNotes);
}
```

**Two-card layout (for head-to-head, implications slides):**
```javascript
function addTwoCardSlide(pres, title, leftCard, rightCard, speakerNotes, footerText) {
  const slide = pres.addSlide({ bkgd: CONTENT_BG });
  addTopBar(slide, title);

  // Left card
  const cl = card(slide, 0.4, 1.05, 4.4, 3.9);
  slide.addText(leftCard.header, {
    x: cl.x, y: cl.y, w: cl.w, h: 0.3,
    fontSize: 13, fontFace: HEADER_FONT, color: PRIMARY_COLOR, bold: true
  });
  slide.addText(leftCard.bullets.map((b, i) => ({
    text: b,
    options: {
      fontSize: 11, fontFace: BODY_FONT, color: BODY_TEXT,
      bullet: true, breakLine: i < leftCard.bullets.length - 1
    }
  })), { x: cl.x, y: cl.y + 0.35, w: cl.w, h: cl.h - 0.4 });

  // Right card
  const cr = card(slide, 5.2, 1.05, 4.4, 3.9);
  slide.addText(rightCard.header, {
    x: cr.x, y: cr.y, w: cr.w, h: 0.3,
    fontSize: 13, fontFace: HEADER_FONT, color: PRIMARY_COLOR, bold: true
  });
  slide.addText(rightCard.bullets.map((b, i) => ({
    text: b,
    options: {
      fontSize: 11, fontFace: BODY_FONT, color: BODY_TEXT,
      bullet: true, breakLine: i < rightCard.bullets.length - 1
    }
  })), { x: cr.x, y: cr.y + 0.35, w: cr.w, h: cr.h - 0.4 });

  addFooter(slide, footerText);
  slide.addNotes(speakerNotes);
}
```

**Chart image embedding:**
```javascript
function addChartSlide(pres, title, chartPath, speakerNotes) {
  const slide = pres.addSlide({ bkgd: CONTENT_BG });
  addTopBar(slide, title);

  slide.addImage({
    path: chartPath,
    x: 0.4, y: 1.05, w: 9.2, h: 3.9,
    sizing: { type: "contain", w: 9.2, h: 3.9 }
  });

  addFooter(slide, "Cross-trial comparison for illustrative purposes only. Review is required before disclosure.");
  slide.addNotes(speakerNotes);
}
```

**Summary/takeaway slide (full-color background):**
```javascript
function addSummarySlide(pres, takeaways, actions, speakerNotes) {
  const slide = pres.addSlide({ bkgd: PRIMARY_COLOR });

  slide.addText("Key Takeaways", {
    x: 0.8, y: 0.4, w: 8.4, h: 0.6,
    fontSize: 26, fontFace: HEADER_FONT,
    color: WHITE_TEXT, bold: true
  });

  slide.addText(takeaways.map((t, i) => ({
    text: `${i + 1}. ${t}`,
    options: {
      fontSize: 12, fontFace: BODY_FONT, color: WHITE_TEXT,
      breakLine: true
    }
  })), { x: 0.8, y: 1.2, w: 8.4, h: 2.5 });

  slide.addText("Recommended Actions", {
    x: 0.8, y: 3.8, w: 8.4, h: 0.4,
    fontSize: 14, fontFace: HEADER_FONT,
    color: ACCENT_TEXT, bold: true
  });
  slide.addText(actions.map((a, i) => ({
    text: a,
    options: {
      fontSize: 11, fontFace: BODY_FONT, color: WHITE_TEXT,
      bullet: true, breakLine: i < actions.length - 1
    }
  })), { x: 0.8, y: 4.2, w: 8.4, h: 1.0 });

  slide.addNotes(speakerNotes);
}
```

### Full script structure:

The engine at `scripts/generate_deck.py` handles all slide types. The agent writes a JSON config to `configs/`:

```json
{
    "mode": "quick or detailed",
    "outputFile": "Compound_Study_Mode_Date.pptx",
    "slides": [
        {"type": "title", "title": "...", "subtitle": "...", "date": "...", "speakerNotes": "..."},
        {"type": "content", "title": "...", "sections": [{"header": "...", "bullets": [...], "x": 0.5, "y": 1.15, "w": 12.3, "h": 5.5}], "speakerNotes": "..."},
        {"type": "twoColumn", "title": "...", "leftColumn": {"header": "...", "bullets": [...]}, "rightColumn": {"header": "...", "bullets": [...]}, "speakerNotes": "..."},
        {"type": "image", "title": "...", "imagePath": "figures/page-10.png", "speakerNotes": "..."},
        {"type": "bnma", "title": "BNMA: EASI-75 at Wk16", "imagePath": "figures/APG777_EASI75_Wk16_2026-07-20.png", "interpretation": ["...", "..."], "speakerNotes": "..."},
        {"type": "table", "title": "...", "table": {"headers": [...], "rows": [[...]]}, "speakerNotes": "..."},
        {"type": "summary", "title": "...", "takeaways": ["...", "..."], "actions": ["...", "..."], "speakerNotes": "..."}
    ]
}
```

### After writing the config:
```bash
python3 scripts/generate_deck.py configs/{compound}_{study}_{date}.json
```

Confirm the `.pptx` file was created in `slide_generated/`. Tell the user:
```
✓ Saved: slide_generated/competitor_deck_20260720.pptx
  Mode: [Quick/Detailed]
  Slides: [N]
  BNMA plots embedded: [N] (from figures/ or BNMA_output/)
  Landscape chart: included (compound colors applied)
```

---

## Style Rules

| Element | Value |
|---------|-------|
| Primary color (title bars, footers, title slide bg) | `#E1251B` (Lilly Red 2024) |
| Content slide background | `#FBF5F5` (light neutral) |
| Card backgrounds | `#FFFFFF` (white) |
| Body text | `#212121` (dark gray) |
| Text on primary backgrounds | `#FFFFFF` (white) |
| Subtitle on primary backgrounds | `#F5D6B0` (warm light) |
| Highlight on primary backgrounds | `#FFC709` (gold) — **never dark colors** |
| Header font | Arial, bold |
| Body font | Arial, regular |
| Title size | 24–28pt (content), 34–38pt (title slide) |
| Body size | 11–12pt |
| Table size | 9.5–10.5pt |
| Footnote size | 8.5–9.5pt |
| Footer | "Review is required before disclosure." on every slide |
| Cross-trial caveat | Required on any comparison slide |

### Compound Color Palette (for landscape charts)

| Compound | Hex | Note |
|----------|-----|------|
| Lebrikizumab (Lilly) | `#E1251B` | Always "ours" — highlighted |
| Dupilumab | `#0F3A85` | Blue (template accent2) |
| Tralokinumab | `#144B2D` | Green (template accent4) |
| Abrocitinib | `#7B2D8B` | Purple |
| Upadacitinib | `#D4570A` | Orange |
| Nemolizumab | `#4A90A4` | Teal |
| Rocatinlimab | `#8B6914` | Gold |
| New competitor (focus) | `#E63946` | Red accent (distinct from Lilly) |
| Others / Placebo | `#999999` | Gray |

---

## Narrative Arc (Detailed Mode)

The deck tells a story in four acts:
1. **What happened?** (Slides 1–4): Introduce the drug, explain MOA, show data
2. **How does it compare?** (Slides 5–6): Competitive context, head-to-head vs Lilly
3. **What does the evidence say?** (BNMA slides): Formal indirect comparison
4. **What should we do?** (Last 2 slides): Assess threat, recommend actions

---

## References

- See `references/indications.md` for endpoints and comparators per indication
- See `references/lilly-style.md` for branding rules
- See `references/extraction-rules.md` for derivation chain and Batman schema
- See `figures/README.md` for image folder naming conventions and how to prepare images
- Use `bnma-interpretation` skill logic for interpreting plots
