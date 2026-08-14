---
name: bnma-ridge-plot
description: Generate BNMA ridge plot from Batman NMA output. Triggered when user provides a Batman output path (smb://, //, or /Volumes/) or asks to generate a BNMA ridge/density plot.
---

# BNMA Ridge Plot Generation

Generate a publication-quality ridge plot (posterior density plot) from Batman NMA output using `scripts/generate_ridge_plot.R`.

## Trigger

User provides a Batman NMA output path or asks to generate a BNMA ridge/density plot. Paths look like:
- `smb://lrlhps/users/<user>/<project>/_output/batmanNMA_<model>_<id>_<timestamp>_output/<model_spec>/`
- `//lrlhps/users/...`
- `/Volumes/lrlhps/users/...`

## Workflow

### Step 1: Parse and validate the Batman output path

Convert the path to local filesystem access:
- `smb://lrlhps/...` → `/Volumes/lrlhps/...`
- `//lrlhps/...` → `/Volumes/lrlhps/...`
- `/Volumes/lrlhps/...` → use as-is

Verify the path exists and contains `FullPosteriorSamples.csv`:
```bash
ls "<converted_path>/FullPosteriorSamples.csv"
```

If not found, check if the user gave a parent directory and list available model subdirectories:
```bash
Rscript scripts/generate_ridge_plot.R --batman_dir "<parent_path>" --suggest_only --indication "unknown"
```

### Step 2: Identify the context

From the path and conversation, determine:
- **Indication** (AD, Psoriasis, UC, Crohn, CRSwNP, etc.)
- **Endpoint** (e.g., EASI75, PASI75, IGA 0/1) — infer from parent folder name
- **Focus compound** — the Lilly compound of interest (e.g., lebrikizumab, baricitinib, mirikizumab)

Ask the user if any of these cannot be inferred.

### Step 3: Get available treatments

Read the treatment columns from the data:
```bash
head -1 "<converted_path>/FullPosteriorSamples.csv"
```

### Step 4: Suggest compounds for the figure

Run the suggestion engine:
```bash
Rscript scripts/generate_ridge_plot.R \
  --batman_dir "<converted_path>" \
  --focus "<focus_compound>" \
  --indication "<indication>" \
  --suggest_only
```

This outputs a JSON object with:
- `recommended`: list of suggested compounds with rationale
- `available`: all treatments in the model
- `focus`: the focus compound

Present the recommendation to the user in a clear table format:
- Group by mechanism class (IL-13, JAK, IL-4/IL-13, etc.)
- Show which are recommended and why
- Ask user to confirm, add, or remove compounds

**Wait for user confirmation before proceeding.**

### Step 5: Generate the ridge plot

Once the user confirms the compound list:
```bash
Rscript scripts/generate_ridge_plot.R \
  --batman_dir "<converted_path>" \
  --compounds "<compound1>,<compound2>,..." \
  --focus "<focus_compound>" \
  --indication "<indication>" \
  --output "figures/<ENDPOINT>_BNMA_ridge_<YYYY-MM-DD>.png" \
  --title "<Endpoint> Treatment Effects vs Placebo — Ridge Plot"
```

Naming convention for output: `figures/<endpoint>_BNMA_ridge_<date>.png`
- endpoint in CAPS (e.g., EASI75, PASI75, IGA01)
- date as YYYY-MM-DD

### Step 6: Show the result

1. Display the generated figure to the user
2. Report the saved file path
3. Note any warnings from the R script (e.g., compounds not found in the model)
4. Ask if the user wants to adjust compounds or regenerate with different settings

## Notes

- The R script requires: `tidyverse`, `ggridges`, `glue` packages
- If Rscript fails, check that `/Volumes/lrlhps` is mounted (Finder → Go → Connect to Server → `smb://lrlhps`)
- The `--top_n` flag limits to top N compounds by posterior median (default: all selected)
- Multiple model specs may exist in one Batman run (fixed_fixed, fixed_random, random_random) — ask user which to use if ambiguous
- The figure is saved at 300 DPI, 10×7 inches by default
