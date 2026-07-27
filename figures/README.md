# Figures Folder

Drop all images here before generating a slide deck — BNMA plots, press release page images, study design diagrams, etc.

## What Goes Here

| File type | How to prepare | Example |
|---|---|---|
| **BNMA plots** | Export from R/Batman as PNG or JPEG | `APG777_EASI75_Wk16_2026-07-20.png` |
| **Press release pages** | Convert PDF → PNG (see below) | `page-01.png`, `page-02.png`, ... |
| **Study design figures** | Screenshot or export from source | `study_design.png` |
| **Efficacy charts** | Screenshot from press release | `efficacy_chart.png` |

## BNMA Plot Naming Convention

Format: `{compound}_{endpoint}_{timepoint}_{date}.png`

**Examples:**
- `APG777_EASI75_Wk16_2026-07-20.png`
- `APG777_IGA01_Wk16_2026-07-20.png`
- `DPX_EASI75_Wk16_ph23_2026-07-20.png` (Phase 2/3 combined)

## How to Convert PDF to Images (No Extra Tools Needed)

**Mac (Preview):**
1. Open the PDF in Preview
2. File → Export
3. Format: PNG, Resolution: 200+
4. Save each page you need into this `figures/` folder

**Mac (Quick alternative):**
- Open PDF, screenshot the pages you need (Cmd+Shift+4), save here

**Windows:**
- Open in PowerPoint or Adobe Reader → Save/Export as images

## What the Agent Does

When you ask for a slide deck, the agent will:

1. **Auto-detect** BNMA plot PNGs (by naming convention) in this folder
2. **Parse** the endpoint and timepoint from the filename
3. **Interpret** the plot visually (rankings, credible intervals, key findings)
4. **Embed** images + interpretation into your slide deck
5. **Embed** press release figures (study design, efficacy charts) directly into slides

## Tips

- Higher-resolution PNGs (≥150 dpi) render better on slides
- For BNMA: include both EASI-75 and IGA 0/1 plots for a complete AD readout
- For press release pages: you don't need to convert ALL pages — just the ones with figures you want embedded (study design, efficacy results, safety table)
