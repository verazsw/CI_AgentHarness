# scripts/generate_ridge_plot.R
# ──────────────────────────────────────────────────────────────────────────────
# Generate BNMA ridge plot (posterior density) from Batman NMA output.
#
# This script reads the FullPosteriorSamples.csv from a Batman tool output
# directory, allows the user to select which compounds to include, and produces
# a publication-quality ridge plot of treatment effects vs placebo.
#
# Usage (interactive):
#   source("scripts/generate_ridge_plot.R")
#   # Then call:
#   generate_ridge_plot(batman_output_dir = "/path/to/normal_independent_fixed_random/")
#
# Usage (command line):
#   Rscript scripts/generate_ridge_plot.R \
#     --batman_dir "/path/to/normal_independent_fixed_random/" \
#     --compounds "dupilumab,lebrikizumab,zumilokibart" \
#     --output "figures/my_ridge_plot.png"
#
# Usage (suggest-only mode — outputs JSON with recommended compounds):
#   Rscript scripts/generate_ridge_plot.R \
#     --batman_dir "/path/to/normal_independent_fixed_random/" \
#     --focus "zumilokibart" --indication "AD" --suggest_only
#
# Batman output folder structure (expected):
#   smb://lrlhps/users/<user>/<project>/_output/
#     batmanNMA_<model>_<id>_<timestamp>_output/
#       normal_independent_fixed_fixed/     (or fixed_random, random_random)
#         FullPosteriorSamples.csv          <-- main input
#         treatment_names.csv               <-- treatment labels
#         model_fit.csv                     <-- DIC/pD for model selection
#         d_overall.csv                     <-- summary treatment effects
#         ...
# ──────────────────────────────────────────────────────────────────────────────

suppressPackageStartupMessages({
  library(tidyverse)
  library(ggridges)
  library(glue)
  library(jsonlite)
})

# ── Color palette ─────────────────────────────────────────────────────────────
# Distinct, colorblind-friendly palette for up to 20 treatments
RIDGE_PALETTE <- c(
  "#00BFC4", "#7CAE00", "#F8766D", "#C77CFF", "#00BA38",

"#619CFF", "#FF61CC", "#00C19F", "#CD9600", "#F564E3",
  "#00B9E3", "#93AA00", "#DB72FB", "#FF6C91", "#00C0AF",
  "#B79F00", "#00BCD8", "#F0766D", "#7CAF00", "#CC79A7"
)

# ── Compound recommendation engine ───────────────────────────────────────────
#' Suggest relevant comparators for a given compound/indication
#'
#' @param treatment_names Character vector of all treatments in the Batman output
#' @param focus_compound Character string: drug of interest (e.g., "zumilokibart")
#' @param indication Character string: indication (e.g., "AD", "Psoriasis")
#' @return Named list with $recommended, $all_available, $by_class
suggest_comparators <- function(treatment_names, focus_compound = NULL, indication = "AD") {

  # ── Define compound-to-class mapping ──
  class_map <- list(
    # IL-13
    "IL-13" = c("lebrikizumab", "tralokinumab", "zumilokibart", "apg777",
                "cendakimab", "dectrekumab"),
    # IL-4/IL-13 dual
    "IL-4/IL-13" = c("dupilumab", "cbp-201", "eblasakimab"),
    # JAK inhibitors
    "JAK" = c("upadacitinib", "abrocitinib", "baricitinib", "ivarmacitinib",
              "gusacitinib", "ritlecitinib", "zasocitinib", "envudeucitinib",
              "brepocitinib"),
    # OX40/OX40L
    "OX40/OX40L" = c("amlitelimab", "rocatinlimab", "telazorlimab"),
    # IL-31
    "IL-31" = c("nemolizumab"),
    # IL-33/TSLP
    "IL-33/TSLP" = c("tezepelumab", "astegolimab", "itepekimab"),
    # PDE4
    "PDE4" = c("apremilast", "roflumilast", "difamilast", "crisaborole"),
    # IL-17
    "IL-17" = c("secukinumab", "ixekizumab", "bimekizumab", "brodalumab",
                "sonelokimab", "izokibep"),
    # IL-23
    "IL-23" = c("guselkumab", "risankizumab", "tildrakizumab", "mirikizumab"),
    # TYK2
    "TYK2" = c("deucravacitinib", "zasocitinib", "envudeucitinib"),
    # Bispecific
    "Bispecific" = c("bbt001", "jnj-95475939", "apg279"),
    # S1P
    "S1P" = c("etrasimod", "ozanimod"),
    # Anti-IL-13 next-gen
    "IL-13 next-gen" = c("zumilokibart", "apg777", "tilrekimig")
  )

  # ── Identify class of focus compound ──
  focus_lc <- tolower(focus_compound %||% "")
  focus_classes <- character()
  for (cls in names(class_map)) {
    if (any(str_detect(focus_lc, fixed(tolower(class_map[[cls]]))))) {
      focus_classes <- c(focus_classes, cls)
    }
  }

  # ── Classify all available treatments ──
  classify_treatment <- function(treat_name) {
    treat_lc <- tolower(treat_name)
    matched_classes <- character()
    for (cls in names(class_map)) {
      if (any(sapply(class_map[[cls]], function(drug) str_detect(treat_lc, fixed(tolower(drug)))))) {
        matched_classes <- c(matched_classes, cls)
      }
    }
    if (length(matched_classes) == 0) return("Other")
    paste(matched_classes, collapse = "/")
  }

  by_class <- tibble(treatment = treatment_names) %>%
    mutate(class = map_chr(treatment, classify_treatment)) %>%
    arrange(class, treatment)

  # ── Recommend: same class + key competitors ──
  recommended <- character()

  if (!is.null(focus_compound) && nchar(focus_lc) > 0) {
    # Always include the focus compound's arms
    focus_arms <- treatment_names[str_detect(tolower(treatment_names), fixed(focus_lc))]
    recommended <- c(recommended, focus_arms)

    # Include same-class treatments
    for (cls in focus_classes) {
      same_class_drugs <- class_map[[cls]]
      for (drug in same_class_drugs) {
        matches <- treatment_names[str_detect(tolower(treatment_names), fixed(tolower(drug)))]
        recommended <- c(recommended, matches)
      }
    }

    # Always include key reference drugs by indication
    ref_drugs <- switch(tolower(indication),
      "ad" = c("dupilumab 600|300 mg wk0|q2w sc", "upadacitinib 30 mg",
               "abrocitinib 200 mg", "lebrikizumab 250 mg"),
      "psoriasis" = c("secukinumab", "ixekizumab", "guselkumab",
                      "risankizumab", "bimekizumab", "deucravacitinib"),
      "uc" = c("upadacitinib", "tofacitinib", "ozanimod",
               "etrasimod", "mirikizumab", "guselkumab"),
      "crohn" = c("upadacitinib", "risankizumab", "guselkumab",
                  "mirikizumab"),
      "crswnp" = c("dupilumab", "mepolizumab", "omalizumab"),
      # Default: include any approved standard-of-care
      c("dupilumab", "upadacitinib")
    )

    for (ref in ref_drugs) {
      matches <- treatment_names[str_detect(tolower(treatment_names), fixed(tolower(ref)))]
      if (length(matches) > 0) {
        # Take highest dose if multiple dose variants
        recommended <- c(recommended, matches[1])
      }
    }
  }

  recommended <- unique(recommended)
  # Remove placebo from recommendations (it's the reference, not plotted)
  recommended <- recommended[tolower(recommended) != "placebo"]

  list(
    recommended = recommended,
    all_available = treatment_names[tolower(treatment_names) != "placebo"],
    by_class = by_class
  )
}


# ── Main ridge plot generator ─────────────────────────────────────────────────
#' Generate a BNMA ridge plot from Batman output
#'
#' @param batman_output_dir Path to the Batman model output directory
#'   (e.g., ".../normal_independent_fixed_fixed/")
#' @param compounds Character vector of compound names to include (partial
#'   matching supported). If NULL, interactive selection is triggered.
#' @param focus_compound The compound of interest (for recommendation engine)
#' @param indication Indication code ("AD", "Psoriasis", "UC", etc.)
#' @param output_path Output file path for the plot (PNG)
#' @param title Plot title (auto-generated if NULL)
#' @param comparator Reference treatment (default "placebo")
#' @param width Plot width in inches
#' @param height Plot height in inches
#' @param dpi Resolution
#' @param alpha Transparency of ridge fills
#' @param top_n If set, only show top N treatments by posterior median
#' @return ggplot object (also saves to output_path if specified)
generate_ridge_plot <- function(
  batman_output_dir,
  compounds = NULL,
  focus_compound = NULL,
  indication = "AD",
  output_path = NULL,
  title = NULL,
  comparator = "placebo",
  width = 14,
  height = NULL,
  dpi = 300,
  alpha = 0.7,
  top_n = NULL
) {

  # ── Validate input directory ──
  batman_output_dir <- normalizePath(batman_output_dir, mustWork = FALSE)
  posterior_file <- file.path(batman_output_dir, "FullPosteriorSamples.csv")

  if (!file.exists(posterior_file)) {
    # Try common alternate file name patterns
    alt_names <- c("FullPosteriorSamples.csv",
                   "full_posterior_samples.csv",
                   "posteriorSamples.csv")
    found <- FALSE
    for (alt in alt_names) {
      alt_path <- file.path(batman_output_dir, alt)
      if (file.exists(alt_path)) {
        posterior_file <- alt_path
        found <- TRUE
        break
      }
    }
    if (!found) {
      # Maybe user passed parent dir — look for subdirectories
      subdirs <- list.dirs(batman_output_dir, recursive = TRUE)
      for (sd in subdirs) {
        fp <- file.path(sd, "FullPosteriorSamples.csv")
        if (file.exists(fp)) {
          posterior_file <- fp
          batman_output_dir <- sd
          found <- TRUE
          message(glue("Found posterior samples in: {sd}"))
          break
        }
      }
      if (!found) {
        stop(glue(
          "Cannot find FullPosteriorSamples.csv in:\n  {batman_output_dir}\n",
          "Expected Batman output structure: <dir>/FullPosteriorSamples.csv"
        ))
      }
    }
  }

  # ── Read posterior samples ──
  message(glue("Reading posterior samples from:\n  {posterior_file}"))
  posterior_raw <- read_csv(posterior_file, show_col_types = FALSE)

  # ── Read treatment names ──
  # Batman output has columns: d[1], d[2], ... or treatment-named columns
  # Also check for a separate treatment_names file
  treat_names_file <- file.path(batman_output_dir, "treatment_names.csv")
  treat_names_alt <- file.path(batman_output_dir, "TreatmentNames.csv")

  if (file.exists(treat_names_file)) {
    treat_names_df <- read_csv(treat_names_file, show_col_types = FALSE)
    treatment_names <- treat_names_df[[1]]
  } else if (file.exists(treat_names_alt)) {
    treat_names_df <- read_csv(treat_names_alt, show_col_types = FALSE)
    treatment_names <- treat_names_df[[1]]
  } else {
    # Column names ARE the treatment names (common Batman format)
    treatment_names <- colnames(posterior_raw)
  }

  # ── Parse posterior matrix ──
  # Batman FullPosteriorSamples.csv: columns = treatments, rows = MCMC samples
  # Values are treatment effect differences vs the reference (placebo)
  # Remove the reference treatment column if present
  ref_col <- which(tolower(treatment_names) == tolower(comparator))
  if (length(ref_col) > 0) {
    posterior_raw <- posterior_raw[, -ref_col]
    treatment_names <- treatment_names[-ref_col]
  }

  # Also remove iteration/chain columns if present
  meta_cols <- which(tolower(colnames(posterior_raw)) %in%
                       c("iteration", "chain", "iter", "sample", "draw"))
  if (length(meta_cols) > 0) {
    posterior_raw <- posterior_raw[, -meta_cols]
    # Sync treatment_names if they were derived from colnames
    if (length(treatment_names) > ncol(posterior_raw)) {
      treatment_names <- treatment_names[-meta_cols]
    }
  }

  # Ensure treatment_names length matches columns
  if (length(treatment_names) != ncol(posterior_raw)) {
    warning(glue(
      "Treatment names ({length(treatment_names)}) don't match columns ({ncol(posterior_raw)}). ",
      "Using column names directly."
    ))
    treatment_names <- colnames(posterior_raw)
  }

  # ── Compound selection ──
  if (is.null(compounds)) {
    # Get recommendations
    suggestions <- suggest_comparators(treatment_names, focus_compound, indication)

    if (interactive()) {
      cat("\n══════════════════════════════════════════════════════════════════\n")
      cat("  BNMA Ridge Plot — Compound Selection\n")
      cat("══════════════════════════════════════════════════════════════════\n\n")

      if (length(suggestions$recommended) > 0) {
        cat("📌 Recommended compounds (same class + key comparators):\n")
        for (i in seq_along(suggestions$recommended)) {
          cat(glue("   [{i}] {suggestions$recommended[i]}"), "\n")
        }
        cat("\n")
      }

      cat("📋 All available treatments by class:\n")
      current_class <- ""
      all_treats <- suggestions$by_class
      for (j in seq_len(nrow(all_treats))) {
        if (all_treats$class[j] != current_class) {
          current_class <- all_treats$class[j]
          cat(glue("\n  ── {current_class} ──"), "\n")
        }
        cat(glue("   • {all_treats$treatment[j]}"), "\n")
      }

      cat("\n──────────────────────────────────────────────────────────────────\n")
      cat("Options:\n")
      cat("  [R] Use recommended set (default)\n")
      cat("  [A] Use all treatments\n")
      cat("  [S] Select specific treatments (comma-separated numbers/names)\n")
      cat("  [T] Select top N by posterior median\n")
      choice <- readline("Your choice: ")

      if (toupper(choice) == "A") {
        compounds <- suggestions$all_available
      } else if (toupper(choice) == "T" || grepl("^[0-9]+$", choice)) {
        n <- if (grepl("^[0-9]+$", choice)) as.integer(choice)
             else as.integer(readline("How many top treatments? "))
        top_n <- n
        compounds <- suggestions$all_available
      } else if (toupper(choice) == "S") {
        sel <- readline("Enter treatment names or numbers (comma-separated): ")
        sel_items <- str_trim(str_split(sel, ",")[[1]])
        compounds <- character()
        for (s in sel_items) {
          if (grepl("^[0-9]+$", s)) {
            idx <- as.integer(s)
            if (idx <= length(suggestions$recommended)) {
              compounds <- c(compounds, suggestions$recommended[idx])
            }
          } else {
            # Partial match
            matches <- suggestions$all_available[
              str_detect(tolower(suggestions$all_available), fixed(tolower(s)))
            ]
            compounds <- c(compounds, matches)
          }
        }
      } else {
        # Default: use recommended
        compounds <- suggestions$recommended
      }
    } else {
      # Non-interactive: use recommendations or all
      if (length(suggestions$recommended) > 0) {
        compounds <- suggestions$recommended
        message(glue("Auto-selected {length(compounds)} recommended compounds."))
      } else {
        compounds <- suggestions$all_available
        message("No specific recommendations; using all treatments.")
      }
    }
  }

  # ── Filter posterior to selected compounds ──
  # Match by partial name (case-insensitive)
  selected_idx <- integer()
  for (cmpd in compounds) {
    matches <- which(str_detect(tolower(treatment_names), fixed(tolower(cmpd))))
    selected_idx <- c(selected_idx, matches)
  }
  selected_idx <- unique(selected_idx)

  if (length(selected_idx) == 0) {
    stop("No matching treatments found. Check compound names against available treatments.")
  }

  posterior_selected <- posterior_raw[, selected_idx, drop = FALSE]
  selected_names <- treatment_names[selected_idx]

  # ── Pivot to long format ──
  colnames(posterior_selected) <- selected_names
  posterior_long <- posterior_selected %>%
    pivot_longer(everything(), names_to = "treatment", values_to = "effect") %>%
    filter(!is.na(effect))

  # ── Compute summary statistics ──
  summaries <- posterior_long %>%
    group_by(treatment) %>%
    summarise(
      median = median(effect),
      mean = mean(effect),
      sd = sd(effect),
      q025 = quantile(effect, 0.025),
      q975 = quantile(effect, 0.975),
      .groups = "drop"
    ) %>%
    arrange(desc(median))

  # ── Apply top_n filter if specified ──
  if (!is.null(top_n) && top_n < nrow(summaries)) {
    top_treatments <- summaries$treatment[1:top_n]
    posterior_long <- posterior_long %>% filter(treatment %in% top_treatments)
    summaries <- summaries %>% filter(treatment %in% top_treatments)
    message(glue("Showing top {top_n} treatments by posterior median."))
  }

  # Order treatments by median (best at top)
  treatment_order <- summaries$treatment
  posterior_long <- posterior_long %>%
    mutate(treatment = factor(treatment, levels = rev(treatment_order)))

  n_treatments <- length(treatment_order)

  # ── Auto-generate title if not provided ──
  if (is.null(title)) {
    # Try to extract info from directory path
    dir_parts <- str_split(batman_output_dir, "/|\\\\")[[1]]
    # Look for endpoint/indication clues
    endpoint_hint <- dir_parts[str_detect(dir_parts, "(?i)EASI|PASI|IGA|ACR|MAYO|SRI")]
    indication_hint <- dir_parts[str_detect(dir_parts, "(?i)AtD|PsO|UC|RA|AD")]

    title <- paste0(
      "Multi-treatment Comparison",
      if (length(indication_hint) > 0) paste0(" in ", indication) else "",
      "\nPosterior Density for PBO-Adjusted Effect Sizes"
    )
  }

  # ── Build the ridge plot ──
  height <- height %||% max(6, 1.2 * n_treatments)

  p <- ggplot(posterior_long, aes(x = effect, y = treatment, fill = treatment)) +
    geom_density_ridges(
      alpha = alpha,
      scale = 1.5,
      rel_min_height = 0.005,
      color = "grey30",
      linewidth = 0.3
    ) +
    scale_fill_manual(values = rep(RIDGE_PALETTE, length.out = n_treatments)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "grey50", linewidth = 0.4) +
    labs(
      title = title,
      x = glue("Treatment Difference (Relative to {comparator})"),
      y = "Posterior Density",
      caption = glue(
        "Data: {posterior_file}\n",
        "Relative Effects, Comparator: {comparator}\n",
        "Date figure created: {format(Sys.Date(), '%d%b%Y')}"
      )
    ) +
    theme_minimal(base_size = 11) +
    theme(
      legend.position = "left",
      legend.title = element_blank(),
      legend.text = element_text(size = 8),
      plot.title = element_text(hjust = 0.5, face = "bold", size = 13),
      plot.caption = element_text(size = 7, color = "grey50", face = "italic"),
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_blank(),
      axis.text.y = element_text(size = 8),
      axis.text.x = element_text(size = 9),
      plot.margin = margin(10, 20, 10, 10)
    )

  # ── Save output ──
  if (!is.null(output_path)) {
    output_path <- normalizePath(output_path, mustWork = FALSE)
    dir.create(dirname(output_path), showWarnings = FALSE, recursive = TRUE)
    ggsave(output_path, p, width = width, height = height, dpi = dpi, bg = "white")
    message(glue("\n✅ Ridge plot saved to: {output_path}"))
    message(glue("   Dimensions: {width}\" × {height}\" @ {dpi} DPI"))
    message(glue("   Treatments shown: {n_treatments}"))
  }

  # ── Print summary table ──
  message("\n┌─────────────────────────────────────────────────────────────────┐")
  message("│ Treatment Effect Summary (vs placebo)                           │")
  message("├─────────────────────────────────────────────────────────────────┤")
  for (i in seq_len(nrow(summaries))) {
    s <- summaries[i, ]
    sig <- if (s$q025 > 0) " *" else ""
    message(glue("│ {str_pad(s$treatment, 45)} │ {sprintf('%5.3f', s$median)} ({sprintf('%5.3f', s$q025)}, {sprintf('%5.3f', s$q975)}){sig}"))
  }
  message("└─────────────────────────────────────────────────────────────────┘")
  message("  * 95% CrI excludes 0 (significant vs placebo)")

  invisible(p)
}


# ── Helper: List available model subdirectories in a Batman output folder ─────
#' @param batman_parent_dir The top-level output directory (contains model subfolders)
list_batman_models <- function(batman_parent_dir) {
  subdirs <- list.dirs(batman_parent_dir, recursive = FALSE)
  has_posterior <- sapply(subdirs, function(d) {
    file.exists(file.path(d, "FullPosteriorSamples.csv"))
  })
  available <- subdirs[has_posterior]
  if (length(available) == 0) {
    message("No Batman model output directories with FullPosteriorSamples.csv found.")
    return(character())
  }
  message("Available Batman model outputs:")
  for (d in available) {
    message(glue("  • {basename(d)}"))
    # Check for model_fit.csv for DIC info
    fit_file <- file.path(d, "model_fit.csv")
    if (file.exists(fit_file)) {
      fit <- read_csv(fit_file, show_col_types = FALSE)
      if ("DIC" %in% names(fit)) {
        message(glue("    DIC = {fit$DIC[1]}"))
      }
    }
  }
  available
}


# ── Command-line interface ────────────────────────────────────────────────────
if (!interactive() && length(commandArgs(trailingOnly = TRUE)) > 0) {
  args <- commandArgs(trailingOnly = TRUE)

  # Parse named arguments
  parse_args <- function(args) {
    params <- list()
    i <- 1
    while (i <= length(args)) {
      if (startsWith(args[i], "--")) {
        key <- sub("^--", "", args[i])
        if (i < length(args) && !startsWith(args[i + 1], "--")) {
          params[[key]] <- args[i + 1]
          i <- i + 2
        } else {
          params[[key]] <- TRUE
          i <- i + 1
        }
      } else {
        i <- i + 1
      }
    }
    params
  }

  params <- parse_args(args)

  # Required: batman_dir
  batman_dir <- params$batman_dir %||% params$dir %||% params$input
  if (is.null(batman_dir)) {
    stop("Required: --batman_dir <path to Batman output directory>")
  }

  # ── Suggest-only mode: output JSON recommendations without generating plot ──
  if (isTRUE(params$suggest_only)) {
    batman_dir <- normalizePath(batman_dir, mustWork = FALSE)
    posterior_file <- file.path(batman_dir, "FullPosteriorSamples.csv")

    if (!file.exists(posterior_file)) {
      # Check alternate names
      for (alt in c("full_posterior_samples.csv", "posteriorSamples.csv")) {
        alt_path <- file.path(batman_dir, alt)
        if (file.exists(alt_path)) { posterior_file <- alt_path; break }
      }
    }

    if (!file.exists(posterior_file)) {
      cat(jsonlite::toJSON(list(error = "FullPosteriorSamples.csv not found"), auto_unbox = TRUE))
      quit(status = 1)
    }

    # Read treatment names
    treat_names_file <- file.path(batman_dir, "treatment_names.csv")
    treat_names_alt <- file.path(batman_dir, "TreatmentNames.csv")
    if (file.exists(treat_names_file)) {
      treatment_names <- read_csv(treat_names_file, show_col_types = FALSE)[[1]]
    } else if (file.exists(treat_names_alt)) {
      treatment_names <- read_csv(treat_names_alt, show_col_types = FALSE)[[1]]
    } else {
      posterior_raw <- read_csv(posterior_file, show_col_types = FALSE, n_max = 1)
      treatment_names <- colnames(posterior_raw)
    }

    # Remove metadata columns
    meta_cols <- c("iteration", "chain", "iter", "sample", "draw", "lp__")
    treatment_names <- treatment_names[!tolower(treatment_names) %in% meta_cols]

    focus <- params$focus %||% params$focus_compound
    indication <- params$indication %||% "AD"

    suggestion <- suggest_comparators(
      treatment_names = treatment_names,
      focus_compound = focus,
      indication = indication
    )

    output <- list(
      focus = focus,
      indication = indication,
      recommended = suggestion$recommended,
      available = suggestion$all_available,
      by_class = setNames(
        as.list(suggestion$by_class$class),
        suggestion$by_class$treatment
      )
    )

    cat(jsonlite::toJSON(output, auto_unbox = TRUE, pretty = TRUE))
    quit(status = 0)
  }

  # ── Standard mode: generate the ridge plot ──
  # Optional parameters
  compounds <- if (!is.null(params$compounds)) {
    str_trim(str_split(params$compounds, ",")[[1]])
  } else NULL

  output_path <- params$output %||% params$out %||%
    file.path("figures", paste0("ridge_plot_", format(Sys.Date(), "%Y-%m-%d"), ".png"))

  generate_ridge_plot(
    batman_output_dir = batman_dir,
    compounds = compounds,
    focus_compound = params$focus %||% params$focus_compound,
    indication = params$indication %||% "AD",
    output_path = output_path,
    title = params$title,
    top_n = if (!is.null(params$top_n)) as.integer(params$top_n) else NULL
  )
}
