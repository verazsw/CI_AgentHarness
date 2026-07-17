# Competitor Analysis Agent

This agent helps you extract, store, summarize, and conduct BNMA for competitor clinical trial data.

## What you can ask

- "Extract efficacy data from this press release: [paste URL]" and the output is formatted
- "I've QC'd and please add new competitor data into our database"
- "Look up NCT04314817 on ClinicalTrials.gov"
- "Summarize this competitor readout for AD"
- "Generate a slide deck for the new dupilumab Phase 3 data"

## Supported indications

AD, Psoriasis, UC, RA, CRSwNP, PsA, Crohn's, SLE, Asthma, COPD, IPF, Allergic Rhinitis

## Notes

- Public resource for competitor is always limited, this agent will send warning if the inference is highly uncertain
- The agent will always show you extracted data before saving anything
- All outputs include: "Review is required before disclosure"
- If something looks wrong, just tell the agent to fix it
