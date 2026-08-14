---
name: pipeline
description: Run the full competitor analysis pipeline. Triggered by "run pipeline", "generate all", "run analysis", or when user provides multiple inputs (compound + source + path) in one message.
---

# Pipeline Mode — Batch Competitor Analysis

Run the full analysis end-to-end: collect all inputs upfront, select outputs, execute without interruption.

## When to Activate

**Keyword triggers:** "run pipeline", "generate all", "run analysis", "batch run", "full analysis"

**Auto-detect:** When the user provides 2+ distinct input types in one message (any combination of: compound name + indication + source URL + Batman path + pasted text), offer pipeline mode.

## Step 1: Collect Inputs

When the user triggers pipeline mode but hasn't provided structured inputs, show this template and ask them to fill it in (leave blank if not available):

```
Please provide your inputs (leave blank if you don't have it):

1. Compound name:
2. Indication:
3. Source (paste text, or path to folder with figure screenshots):
4. Batman NMA output path (smb:// or //):
5. Specific compounds to compare (optional):
```

If the user already provided inputs in their message, parse them and proceed to Step 2.

**Input rules:**
- **Compound**: Drug name (e.g., zumilokibart, lebrikizumab, dupilumab)
- **Indication**: Disease abbreviation (AD, Psoriasis, UC, Crohn, CRSwNP, etc.)
- **Source**: Can be any of:
  - A folder path containing figure screenshots (e.g., `~/competitor_agent/figures`)
  - Pasted article text directly in chat
  - A public press release URL (e.g., sponsor investor page)
  - Note: Internal SharePoint/CILand URLs (collab.lilly.com) are NOT fetchable — Claude Code cannot authenticate to corporate SSO. If user provides a CILand URL, ask them to paste the article text instead.
- **Batman path**: Path starting with `smb://`, `//`, or `/Volumes/` pointing to a Batman NMA output directory containing `FullPosteriorSamples.csv`
- **Compounds to compare**: Comma-separated list (optional — if blank, the agent auto-recommends based on indication and mechanism class)

## Step 2: Confirm Inputs & Select Outputs

Present the structured confirmation table, then the output menu:

```
📋 Pipeline Inputs:
┌──────────────────┬────────────────────────────────────────────────┐
│ Compound         │ <value or "—">                                 │
│ Indication       │ <value or "—">                                 │
│ Source           │ <description or "—">                           │
│ Batman path      │ <path or "—">                                  │
│ Figures detected │ <N files matching compound/indication>         │
│ Compounds        │ <list or "auto-recommend">                     │
└──────────────────┴────────────────────────────────────────────────┘

🎯 Available Outputs (select one or more, or "all"):
  1. Quick slide deck (5 slides — leadership briefing)
  2. Detailed presenter-prep deck (8+ slides with speaker notes)
  3. BNMA ridge plot (requires Batman path)
  4. Competitive landscape summary (text + comparison table)

Which outputs would you like?
```

**Mark unavailable outputs** — e.g., if no Batman path was provided, show:
```
  3. BNMA ridge plot ⚠️ (requires Batman path — not provided)
```

**Wait for user response.** Once they confirm inputs and select outputs, proceed without further interruptions unless an error occurs.

## Step 3: Execute Pipeline

Run the selected outputs in this order (skip any that weren't selected or lack inputs):

### 3a. Data Extraction (if source provided)

Follow the `data-extraction` skill logic:
- If source is a folder path: scan for images, classify them, extract visible data from screenshots
- If source is pasted text: extract structured efficacy table (arms × endpoints)
- If source is a public URL: fetch via `curl` and extract
- CILand/SharePoint URLs: DO NOT attempt to fetch. Tell user: "CILand requires corporate login — please paste the article text instead."
- Store result in memory for later use by slide generation

Do NOT pause to show the user the extracted table mid-pipeline. Accumulate for final delivery.

### 3b. BNMA Ridge Plot (if Batman path provided and selected)

Follow the `bnma-ridge-plot` skill logic with one modification:
- Run `--suggest_only` to get recommended compounds
- **Auto-accept the recommended list** without asking user (pipeline mode = no mid-run interruptions)
- UNLESS the user explicitly specified compounds in their input — then use those
- Generate the plot and save to `figures/`

```bash
Rscript scripts/generate_ridge_plot.R \
  --batman_dir "<converted_path>" \
  --focus "<compound>" \
  --indication "<indication>" \
  --suggest_only
```

Then:
```bash
Rscript scripts/generate_ridge_plot.R \
  --batman_dir "<converted_path>" \
  --compounds "<recommended_list>" \
  --focus "<compound>" \
  --indication "<indication>" \
  --output "figures/<ENDPOINT>_BNMA_ridge_<YYYY-MM-DD>.png" \
  --title "<Endpoint> Treatment Effects vs Placebo"
```

Path conversion: `smb://lrlhps/...` or `//lrlhps/...` → check `/Volumes/lrlhps/...` first, then `/Volumes/<username>/...` (common mount pattern).

### 3c. Competitive Landscape (if selected)

Follow the `competitive-context` skill logic:
- Search ClinicalTrials.gov for competing trials in the same indication
- Identify approved and late-stage compounds
- Generate comparison table

### 3d. Slide Deck (if selected)

Follow the `slide-generation` skill logic:
- Use extracted data from step 3a
- Use BNMA ridge plot from step 3b (auto-detected in `figures/`)
- Use landscape data from step 3c
- Write JSON config to `configs/`
- Run `python3 scripts/generate_deck.py configs/<name>.json`
- Quick mode → 5 slides; Detailed mode → 8+ slides with speaker notes

### 3e. QA Verification (automatic — always runs)

Follow the `qa-verification` skill logic:
- Cross-check extracted numbers against source
- Verify slide content completeness
- Check BNMA plot rendering
- Flag any discrepancies

## Step 4: Deliver All Outputs

Present a single delivery summary:

```
✅ Pipeline Complete

📁 Generated Files:
  • figures/EASI75_BNMA_ridge_2026-08-14.png (BNMA ridge plot)
  • Zumilokibart_APG777_APEX_AD_Detailed_2026-08-14.pptx (Detailed presenter deck, 10 slides)

📊 Key Findings:
  • [1-2 sentence BNMA interpretation — top-ranked treatment, CrI]
  • [1-2 sentence landscape summary — # competitors, closest threat]

⚠️ QA Notes:
  • [Any warnings, uncertain inferences, missing data]

Review is required before disclosure.
```

## Error Handling

| Error | Action |
|-------|--------|
| Batman path not accessible | Report "Cannot access path — is the network drive mounted?" and skip ridge plot |
| CILand/SharePoint URL | Ask user to paste article text instead (cannot authenticate) |
| Source URL unreachable | Report and skip extraction, continue with figures only |
| R package missing | Report which package and how to install, skip that step |
| No figures for deck | Generate text-only deck, note it in delivery |
| Extraction uncertain | Flag in QA notes with ⚠️ |

**Never silently fail.** If a step is skipped, always explain why in the delivery summary.

## Notes

- This skill orchestrates the other skills — it does NOT replace them. Users can still invoke individual skills directly.
- For BNMA compound selection: if the user specified compounds in input #5, honor that over the auto-recommendation.
- CILand URLs cannot be fetched — always ask for pasted text.
