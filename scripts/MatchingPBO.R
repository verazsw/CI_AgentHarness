## ============================================================================
## Predicted placebo EASI-75 (Week 4) for BBT001-001 (NCT06808477)
##
## Purpose: BBT001's placebo arm is 0/5. In the Batman logit run that leaves
## d[13] non-identified (posterior mean 57.1, SD 41.8, 95% CrI 4.2-159.1;
## nat_d[13] = 1.000 in 89% of draws). A non-zero placebo rate bounds the
## contrast and makes the parameter estimable.
##
## Donor data: ADvocate 1 + 2 placebo arms, Week 4 (kgabc_wk4.sas7bdat)
## Method:     tboot mean-matching, adapted from the KT621 / BROADEN script
##
## Targets:    Bambusa press release Table 1, 27-Jul-2026
## https://www.prnewswire.com/news-releases/bambusa-therapeutics-reports-
##   potentially-transformative-preliminary-proof-of-concept-results-for-bbt001
##   -in-atopic-dermatitis-reinforcing-its-best-in-disease-potential-302834893.html
##
## KEY DIFFERENCE FROM THE KT621 SCRIPT
## Bambusa reports only FOUR baseline variables: EASI, BSA, PP-NRS, vIGA.
## No age, sex, ethnicity, BMI, SCORAD or race. The KT621 script matched on
## twelve, and race was doing much of the work there (main vs sensitivity moved
## the Wk4 estimate 12.4% -> 10.9%). There is no such lever here. Everything
## outside those four variables is UNMATCHED and uncontrolled - state this in
## the SAP rather than leaving it implicit.
## ============================================================================

library(tboot)
library(tidyverse)

MATCH_VARS <- c("EASIBL", "BSABL", "PNRSBL", "IGABL")
OUT_VARS   <- c("EASI75_wk4", "IGA01_wk4")

## ---- 1. Donor data ---------------------------------------------------------
## NOTE vs the KT621 script: select() BEFORE na.omit(). The original dropped any
## patient missing RACE / SCORADBL / BASBMIIP - variables we can no longer match
## on - which cost donors for nothing. The KT621 run had 273 donors; ADvocate 1+2
## randomised 287 to placebo, so ~14 were being discarded.

lebri_data2 <- haven::read_sas("/Users/L099645/Library/CloudStorage/OneDrive-EliLillyandCompany/Documents/development/CI_test/bambusa/kgabc_wk4.sas7bdat") %>%
    mutate(IGABL = ifelse(IGABL == 4, 1, 0)) %>%   # 1 = severe (vIGA 4)
    select(all_of(c(MATCH_VARS, OUT_VARS))) %>%
    na.omit() %>%
    as.matrix()

nrow(lebri_data2)      # compare to 273 under the old na.omit() ordering
colMeans(lebri_data2)

## Donor profile under the old ordering, for reference:
##      EASIBL      BSABL     PNRSBL      IGABL EASI75_wk4  IGA01_wk4
##   30.4287546 47.0476190  7.1892726  0.3736264  0.0549451  0.0109890

## ---- 2. Targets ------------------------------------------------------------
## vIGA is reported as a mean on a 0-4 scale. Entry required IGA >= 3, so scores
## are 3 or 4 only, and the severe proportion is recoverable exactly from the
## reported mean and SD:
##   placebo n=5,  mean 3.20, SD 0.44 (0.4472 truncated) -> 1 of 5  = 0.2000
##   BBT001  n=12, mean 3.42, SD 0.51 (0.5149)           -> 5 of 12 = 0.4167

## PRIMARY - the PLACEBO arm (n=5). This is the arm being imputed, so the
## prediction inherits the same baseline imbalance the trial actually had.
target_pbo <- c(EASIBL = 29.06,
                BSABL  = 47.60,
                PNRSBL =  6.33,
                IGABL  =  0.2000)

## SENSITIVITY 1 - the POOLED randomised population (n=17). More stable, since
## the n=5 placebo means are extremely noisy, but it estimates a study-level
## placebo rather than the placebo arm as randomised.
target_pooled <- c(EASIBL = 33.00,
                   BSABL  = 58.17,
                   PNRSBL =  7.04,
                   IGABL  =  0.3529)

## SENSITIVITY 2 - EASI and BSA only, the two variables with the least
## cross-trial measurement ambiguity.
target_min <- c(EASIBL = 29.06,
                BSABL  = 47.60)

## ---- 3. Feasibility check (BEFORE tweights) --------------------------------
## With 12 constraints you could skip this. With 4 it is cheap and catches the
## failure mode early: tweights fails, or returns a near-degenerate weight
## vector, when a target sits outside the convex hull of the donor data.

check_target <- function(dat, target) {
    v <- names(target)
    tibble(var        = v,
           target     = as.numeric(target),
           donor_mean = colMeans(dat)[v],
           donor_sd   = apply(dat, 2, sd)[v],
           donor_min  = apply(dat, 2, min)[v],
           donor_max  = apply(dat, 2, max)[v]) %>%
        mutate(inside   = target > donor_min & target < donor_max,
               shift_sd = (target - donor_mean) / donor_sd)
}

check_target(lebri_data2, target_pbo)

## Expect: EASI and BSA sit almost on top of the donor means; PP-NRS and the
## severe-vIGA proportion are both shifted DOWN (6.33 vs 7.19; 0.20 vs 0.37).
## The Bambusa placebo arm is a milder population than ADvocate placebo.

## ---- 4. Weight, resample, extract ------------------------------------------

run_tboot <- function(dat, target, seed = 3284789, nrow = 1e5) {
    w <- tweights(dataset = dat, target = target)
    set.seed(seed)
    list(weights = w, means = colMeans(tboot(weights = w, nrow = nrow)))
}

fit_pbo    <- run_tboot(lebri_data2, target_pbo)
fit_pooled <- run_tboot(lebri_data2, target_pooled)
fit_min    <- run_tboot(lebri_data2, target_min)

## Always inspect the weights, not just the predicted mean. A prediction driven
## by a handful of donors is not usable. Rule of thumb: ESS below ~30 is fragile.
ess <- function(w) 1 / sum(w$weights^2)
map_dbl(list(placebo = fit_pbo, pooled = fit_pooled, minimal = fit_min),
        ~ ess(.x$weights))

## Confirm the match actually landed on target before trusting the outcome
fit_pbo$means[names(target_pbo)]

## ---- 5. Results ------------------------------------------------------------

getSE <- function(pe_p, n) sqrt(pe_p * (1 - pe_p) / n)

N_PBO <- 5   # BBT001 placebo arm as randomised (KT621/BROADEN used 10)

results <- tibble(
    analysis   = c("Primary (placebo arm, n=5)",
                   "Sens 1 (pooled n=17)",
                   "Sens 2 (EASI + BSA only)"),
    p_easi75   = c(fit_pbo$means[["EASI75_wk4"]],
                   fit_pooled$means[["EASI75_wk4"]],
                   fit_min$means[["EASI75_wk4"]]),
    p_iga01    = c(fit_pbo$means[["IGA01_wk4"]],
                   fit_pooled$means[["IGA01_wk4"]],
                   fit_min$means[["IGA01_wk4"]])
) %>%
    mutate(n_pbo = N_PBO,
           se    = getSE(p_easi75, n_pbo))

results

## ---- 6. Sanity anchors -----------------------------------------------------
## Three independent reference points for the Wk4 placebo EASI-75 rate. A tboot
## prediction far outside this band means the weights are doing something odd -
## go back and look at the ESS before using it.
##
##   Donor rate, unweighted (ADvocate 1+2 placebo)      5.5%
##   Pooled Wk4 monotherapy placebo across the 5
##     studies already in the Batman file (61/923)      6.6%
##   Batman's OWN common baseline m from the logit run  6.5%
##     (median; 95% CrI 5.05% - 8.20%)
##
## The third is the strongest anchor: the model has already estimated this
## quantity from the network. If the tboot prediction lands inside that CrI,
## the two approaches agree and the choice barely matters.

anchors <- tibble(
    source = c("ADvocate placebo, unweighted",
               "Pooled Wk4 monotherapy placebo (61/923)",
               "Batman common baseline m (median)"),
    p      = c(mean(lebri_data2[, "EASI75_wk4"]), 61/923, 0.0650)
)
anchors

## ---- 7. Rows for the Batman input ------------------------------------------
## Follow the BROADEN/KT621 placebo-row convention: write y and se DIRECTLY.
## Do not derive them from r/n - at n=5 any rate below 10% rounds to 0
## responders, which reproduces the zero cell you are trying to remove.
##
##   study = "BBT001-001", study_ind = 9, treat = "placebo", arm_ind = 1
##   n  = 5
##   r  = <leave blank, or round(p*5) knowing it will not reproduce y>
##   y  = <p_easi75 from the primary analysis>
##   se = <se from the primary analysis>
##   Outcome_Value   = 100 * p_easi75
##   Imputation_Method = "Predicted (tboot matching to ADvocate placebo)"
##   Location          = "Predicted - see MatchingPBO.R"
##
## The BBT001 ACTIVE row does not change: n = 11, r = 5, y = 0.454545.

## ---- 8. Before you rerun Batman --------------------------------------------
## Worth checking whether this prediction is needed at all. meta.csv from the
## logit run records "Baseline: independent". With independent per-study
## baselines, BBT001's 0/5 drives its own baseline to -Inf and d[13] to +Inf.
## If Batman can fit an EXCHANGEABLE (random) baseline instead, the BBT001
## baseline is borrowed from the other 8 studies, the zero cell stops being
## fatal, and no predicted placebo is required.
##
## That is the cleaner fix if the option exists: it uses the network's own
## information rather than importing an external assumption from ADvocate.
## Ask Michael Sonksen (BATMAN+ contact) whether the baseline model can be
## switched. Run this script either way - if both routes are available, they
## make a good cross-check on each other.