---
name: pipeline
description: Run the full competitor analysis pipeline. Triggered by "run pipeline", "generate all", "run analysis", or when user provides multiple inputs (compound + source + path) in one message.
---

# Pipeline Mode — Batch Competitor Analysis

Run the full analysis end-to-end: collect all inputs upfront, select outputs, execute without interruption.

## When to Activate

**Keyword triggers:** "run pipeline", "generate all", "run analysis", "batch run", "full analysis"

**Auto-detect:** When the user provides 2+ distinct input types in one message (any combination of: compound name + indication + source URL + Batman path + pasted text), offer pipeline mode:

> "It looks like you have multiple inputs ready. Would you like me to run the full pipeline? I'll confirm everything first, then generate your selected outputs end-to-end."

If the user declines, fall back to the most relevant individual skill.

## Step 1: Parse Inputs

Extract from the user's message:

| Field | How to detect |
|-------|---------------|
| **Compound** | Drug name (e.g., zumilokibart, lebrikizumab, dupilumab) |
| **Indication** | Disease abbreviation or name (AD, Psoriasis, UC, etc.) |
| **Source URL** | Any URL — CILand (collab.lilly.com), press release, ClinicalTrials.gov |
| **Batman path** | Path starting with `smb://`, `//`, or `/Volumes/` containing Batman output |
| **Pasted text** | Raw efficacy data or press release text pasted directly |
| **Figures** | Auto-scan `figures/` directory for matching compound/indication images |

**Partial inputs are fine.** Not everything is required — the pipeline adapts:
- No Batman path → skip ridge plot
- No source URL or text → skip data extraction (use existing figures only)
- No figures in `figures/` → skip BNMA interpretation (unless ridge plot generates one)

## Step 2: Confirm Inputs & Select Outputs

Present the structured confirmation table, then the output menu:

```
📋 Pipeline Inputs:
┌──────────────────┬────────────────────────────────────────────────┐
│ Compound         │ <detected or "not specified">                  │
│ Indication       │ <detected or "not specified">                  │
│ Source           │ <URL or "pasted text" or "none">               │
│ Batman path      │ <path or "none">                               │
│ Figures detected │ <N files matching compound/indication>         │
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

### 3a. Data Extraction (if source URL or pasted text provided)

Follow the `data-extraction` skill logic:
- Fetch URL content via `curl` (CILand, press release, ClinicalTrials.gov)
- Extract structured efficacy table (arms × endpoints)
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
  • zumilokibart_apex_2026-08-14.pptx (Detailed presenter deck, 10 slides)

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
| Batman path not accessible | Report "Cannot access path — is the network drive mounted?" and skip ridge plot, continue other outputs |
| Source URL unreachable | Report "Could not fetch URL" and skip extraction, continue with figures only |
| R package missing | Report which package and how to install, skip that step |
| No figures for deck | Generate text-only deck, note "No BNMA figures available for embedding" |
| Extraction uncertain | Flag in QA notes with ⚠️, include in delivery |

**Never silently fail.** If a step is skipped, always explain why in the delivery summary.

## Notes

- This skill orchestrates the other skills — it does NOT replace them. Users can still invoke individual skills directly.
- The pipeline saves its execution log so users can rerun: "Run the same pipeline again with updated Batman output."
- For the BNMA ridge plot compound selection: if the user said specific compounds in their initial message (e.g., "compare vs dupilumab and upadacitinib"), honor that over the auto-recommendation.
