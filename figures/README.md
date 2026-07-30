# Figures Folder

Drop all images here before generating a slide deck — BNMA plots, press release page images, study design diagrams, etc.

## What Goes Here

| File type | How to prepare | Example |
|---|---|---|
| **BNMA plots** | Export from R/Batman as PNG or JPEG | `APG777_EASI75_Wk16_2026-07-20.png` |
| **Press release pages** | Convert PDF → PNG (see below) | `page-01.png`, `page-02.png`, ... |
| **Study design figures** | Screenshot or export from source | `study_design.png` or `study_design_APEX.png` |
| **Efficacy charts** | Screenshot from press release | `efficacy_EASI75_timecourse.png` |
| **Competitive charts** | Cross-trial comparison figures | `competitive_landscape.png` |
| **Forest plots** | Subgroup or meta-analysis figures | `forest_plot_PASI75.png` |
| **Safety figures** | AE tables or safety summaries | `safety_summary.png` |

## BNMA Plot Naming Convention

Format: `{compound}_{endpoint}_{timepoint}_{date}.png`

**Examples:**
- `APG777_EASI75_Wk16_2026-07-20.png`
- `APG777_IGA01_Wk16_2026-07-20.png`
- `zasocitinib_envudeucitinib_PASI75_Wk16_2026-07-29.png`
- `DPX_EASI75_Wk16_ph23_2026-07-20.png` (Phase 2/3 combined)

## Recommended Naming for Non-BNMA Figures

If you can name figures descriptively (instead of generic `page-XX.png`), the agent will auto-route them to the correct slide position without needing to visually inspect each one:

| Naming pattern | Auto-routes to |
|---|---|
| `study_design_*.png` | Study Design slide (as `rightImage` or full slide) |
| `efficacy_*.png` | Efficacy Results slide (dedicated image slide) |
| `forest_plot_*.png` | Forest plot slide (after efficacy section) |
| `safety_*.png` | Safety slide (embedded or dedicated) |
| `landscape_*.png` or `competitive_*.png` | Competitor Landscape slide (after table) |

**Examples:**
- `study_design_ONWARD1.png` → embedded on Study Design slide
- `efficacy_PASI90_timecourse.png` → embedded as full image slide after efficacy results
- `competitive_oral_psoriasis_bars.png` → embedded after competitor table
- `forest_plot_subgroups.png` → dedicated slide in efficacy section
- `safety_TEAEs_table.png` → embedded on or after safety slide

The `page-XX.png` format still works — the agent will visually scan and classify each page into one of the above roles. But descriptive names save time and reduce errors.

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

1. **Inventory** all files in this folder (runs FIRST, before any research)
2. **Classify** each file by naming pattern or visual inspection:
   - BNMA plots (uppercase compound code) → BNMA slides
   - Named figures (`study_design_*`, `efficacy_*`, etc.) → auto-routed to matching slide
   - Press release pages (`page-*.png`) → visually scanned and classified
3. **Build a figure manifest** mapping each file to a slide position
4. **Embed** figures into the appropriate slides (study design, efficacy, landscape, safety)
5. **Interpret** BNMA plots (rankings, credible intervals, key findings)

## Tips

- Higher-resolution PNGs (≥150 dpi) render better on slides
- For BNMA: include plots for all relevant endpoints (e.g., both PASI-75 and PASI-100 for psoriasis)
- For press release pages: you don't need ALL pages — just the ones with figures (study design, efficacy results, safety table, competitive comparisons)
- Descriptive filenames (e.g., `study_design_LATITUDE.png`) are faster and more reliable than generic `page-XX.png`
