# Competitor Analysis Agent

Extracts, structures, and summarizes competitor clinical trial data for immunology.

## Getting Started

### Option 1: Claude Code (Recommended)

Claude Code gives you the complete experience: data extraction, BNMA interpretation, landscape charts, and automated `.pptx` slide decks.

**Setup:**

1. Download or clone this folder to your machine
2. Install prerequisites:
   ```bash
   pip install python-pptx
   ```
3. Open the folder in Claude Code:
   - **Terminal:** `cd` into the folder and run `claude`
   - **VS Code/Positron extension:** Open the folder, then use the Claude Code extension (Cmd+Shift+P → "Claude Code")
4. Start chatting — all skills load automatically

**Example prompts to try:**

| What you want | Example prompt |
|---|---|
| Extract data from a press release | "Extract efficacy data from this press release: [paste URL]" |
| Extract from a CILand article | "Extract data from this CI article: [paste collab.lilly.com URL]" |
| Summarize a competitor readout | "Summarize this competitor readout for AD" |
| Generate a quick 5-slide deck | "Generate a slide deck for the new dupilumab Phase 3 data" |
| Generate a detailed presenter deck | "Create a detailed presenter-prep deck for the zumilokibart APEX Phase 2B readout in AD" |
| Interpret a BNMA plot | "What does this BNMA forest plot show?" (store image in `figures/`) |
| Look up a trial | "Look up NCT04314817 on ClinicalTrials.gov" |
| Add data to the database | "I've QC'd — please add this data to our database" |
| Check latest competitor news | "Any new AD competitor updates this week?" |

**Tips:**

- Say "detailed" or "presenter prep" for the full 8+ slide deck; otherwise you get a quick 5-slide summary

- Drop all images into the **`figures/`** folder before asking for a deck — BNMA plots, press release page screenshots, study design diagrams, etc. The agent auto-scans and classifies all figures.

- **Figure naming:** Use descriptive names for auto-routing (e.g., `study_design_APEX.png`, `efficacy_PASI90_timecourse.png`). See `figures/README.md` for the full naming guide.

- **BNMA plot naming convention:** `{compound}_{endpoint}_{timepoint}_{date}.png` (e.g., `APG777_EASI75_Wk16_2026-07-20.png`)

- **Press release PDFs:** Convert pages to images (PNG/JPEG) and drop them in `figures/`. On Mac: open in Preview → File → Export → select PNG. The agent will ask you to do this if you provide a PDF.

- **CILand articles:** You can paste a `collab.lilly.com/sites/CILand/...` URL and the agent will try to fetch and extract data from it. If auth is needed, paste the article text directly.

- The agent will always show you extracted data before saving anything — you get a chance to QC


### Option 2: Claude App (claude.ai)

The Claude app can generate slide decks too. Our skill file (`.claude/skills/slide-generation/SKILL.md`) contains **pptxgenjs JavaScript templates** — when Claude runs on the app, it uses these templates to produce a `.pptx` as a downloadable Artifact.

**How the two platforms use the same skill differently:**

| | Claude Code | Claude App |
|---|---|---|
| **Generation method** | `scripts/generate_deck.py` (python-pptx, runs locally) | pptxgenjs templates from our SKILL.md (runs in Artifact sandbox) |
| **BNMA plots** | Auto-detected from `figures/` folder | User uploads images into the chat |
| **Landscape chart** | Generated via R/ggplot2 locally | Not available |
| **CILand integration** | Fetches via URL (with auth if available) | User pastes article text |
| **Output** | `.pptx` saved to your disk | `.pptx` downloadable from Artifact |

**To use on claude.ai:**

1. Create a Project and upload the skill files from `.claude/skills/` as project knowledge (including `references/`)

2. Paste or link your press release source

3. Upload BNMA plot images directly into the chat if you want them interpreted and embedded

4. Ask for a deck — Claude uses the pptxgenjs JavaScript code from our skill to generate a downloadable `.pptx` Artifact

### What the Agent Will Ask You

No matter which prompt you start with, expect the agent to:

1. **Ask for your data source** — "Do you have a CILand article, press release URL, pasted text, or a PDF?"
2. **Ask Quick vs Detailed** (if ambiguous) — "Quick 5-slide leadership briefing, or detailed presenter-prep deck?"
3. **Show extracted data for your review** — a formatted table of efficacy numbers
4. **Confirm the output** — file name, slide count, which BNMA plots were embedded

## Data Sources (Priority Order)

| Priority | Source | Best for |
|:---:|---|---|
| 1 | **CILand articles** (collab.lilly.com/sites/CILand/) | Curated internal analysis with data + strategic context |
| 2 | **Press releases** (sponsor investor pages) | Primary external source with official numbers |
| 3 | **figures/ folder** (BNMA plots, page images) | Visual data already prepared locally |
| 4 | **ClinicalTrials.gov** | Study design, arms, sample size |
| 5 | **PubMed** | Published results and competitive context |

## Current Supported Indications in Immunology

AD, Psoriasis, UC, RA, CRSwNP, PsA, Crohn's, SLE, Asthma, COPD, IPF, Allergic Rhinitis

## Notes

- Public resources for competitors are always limited — the agent warns when inference is highly uncertain
- All outputs include: **"Review is required before disclosure."**
- If something looks wrong, just tell the agent to fix it

## Roadmap: Microsoft Teams / CILand Auto-Detection

Currently, the agent requires users to paste a CILand URL or provide source material. A future enhancement would add automatic detection of new CI team publications:

**Planned (requires MCP server + Azure AD setup):**
- Auto-detect new CILand articles by compound or indication
- Search CI publications: "What's the latest on BBT001?"
- Monitor Teams channel for competitor updates
- Pull figures directly from SharePoint pages

**What's needed:**
- Azure AD app registration with Graph API permissions (`Sites.Read.All`)
- MCP server wrapping Microsoft Graph API calls
- Configuration in `.claude/settings.json`

Contact IT to evaluate feasibility of Graph API access to the CILand SharePoint site.
