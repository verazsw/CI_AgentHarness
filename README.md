# Competitor Analysis Pipeline

Extracts, structures, data curation, QC, and summarizes competitor clinical trial readout for **immunology**. Primary Goal:
```bash
Quick, Accurate, Insights Competitor Readout Slide Deck for Urgent Request;

Deal with Special Cases In Development: 
Competitor didn't report placebo-arm response rate; 
Competitor didn't report per-arm sample size; 
Competitor only publish Ph1 result; 
Competitor BL characteristics are different; 
Competitor only publish intypical timepoints results
... 
```

## Setup

1. Download or clone this folder to your machine
2. Install prerequisites. This pipeline relies on python-pptx to generate slide deck. Claude desktop can still generate a downloadable `.pptx` Artifact but with limited features.
   ```bash
   pip install python-pptx
   ```
3. Open the folder in Claude Code:
   - **Terminal:** `cd` into the folder and run `claude`
   - **VS Code/Positron extension:** Open the folder, then use the Claude Code extension (Cmd+Shift+P → "Claude Code")
4. Start chatting

## How to Use

### Pipeline Mode (Recommended)

Provide all your materials in one message, select outputs, and the pipeline runs end-to-end:

#### Main Guidance Example:
```bash
Run this pipeline for the zumilokibart Ph2 Atopic Dermatitis readout.
Source: competitor readout press release are in: ~/competitor_agent/figures/, CI land update: ~/competitor_agent/figures/, ...
Existing BNMA input excel file for the AtD to edit: /Users/L099645/Library/CloudStorage/OneDrive-EliLillyandCompany/Documents/development/CI_test
Batman BNMA output path for the each endpoint: EASI: smb://lrlhps/users/xxxxx/EASI75_Ph2Ph3/AtD_Zum_Ph23/_output/batmanNMA_all_20260530_214958_output/, IGA: ...
I want: BNMA ridge plot + detailed slide deck
```
#### Tips

- Say "detailed" or "presenter prep" for the full 8+ slide deck; otherwise you get a quick 5-slide summary
- Drop images, press release, and all materials you have into **`figures/`** before asking for a deck — the agent auto-scans and classifies them
- **CILand articles:** Cannot be fetched by URL. Print the article text into pdf (better convert to png/jpeg) and put into **`figures/`**.
- **Press release PDFs:** PDF is totally fine. Better to Convert pages to png/jpeg and drop in `figures/`

<hr>

## $\color{red}\text{You can skip reading the text below to save your time}$

Or just say "run pipeline" and the agent will ask you to fill in, Leave any field blank if you don't have that resource — the pipeline adapts. For example:

```bash
1. Compound name:         (e.g., zumilokibart)
2. Indication:            (e.g., AD)
3. Source:                (paste text, or path to figures folder)
4. Batman NMA output path for each endpoint: (leave blank if none)
5. Compounds to compare:  (optional, comma-separated)
......
```

The agent will:

```bash
1. Confirm your inputs in a structured table
2. Show available outputs (slide deck, ridge plot, landscape summary)
3. Let you select one or more
4. Run everything end-to-end — no mid-run questions
5. Deliver all files with a summary of key findings
```

**Partial inputs are fine** — no Batman path? It skips the ridge plot. No URL? It works from figures only. The agent will search clinicaltrial.gov and PubMed automatically.

**Trigger words:** "run pipeline", "generate all", "run analysis", "batch run"

### Ad-Hoc Mode

You can also ask for one thing at a time:

| What you want | Example prompt |
|---|---|
| Extract data from a source | "Extract efficacy data from this press release: [paste URL]" |
| Generate a slide deck | "Generate a slide deck for the new dupilumab Phase 3 data" |
| Interpret a BNMA plot | "What does this BNMA forest plot show?" |
| Generate a BNMA ridge plot | "Generate a ridge plot from smb://lrlhps/users/..." |
| Look up a trial | "Look up NCT04314817 on ClinicalTrials.gov" |

## Supported Indications

AtD, Psoriasis, UC, RA, CRSwNP, PsA, Crohn's, SLE, Asthma, COPD, IPF, Allergic Rhinitis

## Using with Claude App (claude.ai)

This agent also works on claude.ai with limited features (no local R/Python scripts, no auto-scan of `figures/`). Upload skill files from `.claude/skills/` as project knowledge, paste your source text, and ask for a deck — Claude generates a downloadable `.pptx` Artifact.

## Notes

- Public resources for competitors are always limited — the agent warns when inference is highly uncertain
- All outputs include: **"Review is required before disclosure."**
- If something looks wrong, just tell the agent to fix it
