# scripts/append_batman_input.R
# ──────────────────────────────────────────────────────────────────────────────
# Append newly extracted competitor data to an existing Batman BNMA input Excel.
#
# Reads a JSON file containing extracted arms + study metadata, maps to the
# 37-column Batman schema, and either previews or appends the rows to an
# existing Batman input Excel file.
#
# Ported from competitor_app_v1/helpers/batman_schema.R::append_to_batman()
# and competitor_app_v1/helpers/derivation.R::derive_arm().
#
# Usage:
#   # Preview mode (mandatory before write — outputs proposed rows as JSON):
#   Rscript scripts/append_batman_input.R \
#     --excel_path "/Volumes/lrlhps/.../BatmanInput.xlsx" \
#     --data_json "/tmp/batman_append.json" \
#     --preview_only
#
#   # Write mode (append and save, with backup):
#   Rscript scripts/append_batman_input.R \
#     --excel_path "/Volumes/lrlhps/.../BatmanInput.xlsx" \
#     --data_json "/tmp/batman_append.json" \
#     --backup
#
#   # Write to a different output path (does not overwrite original):
#   Rscript scripts/append_batman_input.R \
#     --excel_path "/Volumes/lrlhps/.../BatmanInput.xlsx" \
#     --data_json "/tmp/batman_append.json" \
#     --output "/tmp/BatmanInput_updated.xlsx"
#
# JSON input schema:
#   {
#     "arms": [
#       { "treat": "drug 300mg Q2W SC", "n_pts": 80, "endpoint": "easi75",
#         "measurement_time": 16, "outcome_value": 72.5, "n_events": null,
#         "se": null, "sd": null, "source": "Press release",
#         "stat_pop": "ITT", "estimand": "NRI",
#         "dose_description": "300mg Q2W" }
#     ],
#     "meta": {
#       "acronym": "APEX", "nct_id": "NCT12345678", "sponsor": "Apogee",
#       "phase": "Phase 2", "start_year": 2024, "end_year": 2026,
#       "results_posted_year": null, "n_arms": 3,
#       "primary_treatment": "zumilokibart",
#       "inclusion_criteria": "...", "exclusion_criteria": null,
#       "min_age": 18, "max_age": null, "eligibility_criteria": "..."
#     },
#     "target_endpoints": ["easi75", "iga01"],
#     "response_type": "binary"
#   }
# ──────────────────────────────────────────────────────────────────────────────

suppressPackageStartupMessages({
  library(tidyverse)
  library(readxl)
  library(writexl)
  library(jsonlite)
  library(glue)
})

# ── Batman column definitions ────────────────────────────────────────────────

BATMAN_COLS <- c(
  "study", "study_ind", "treat", "arm_ind", "n", "r", "y", "se",
  "Link_to_Article", "Location", "Publication_Year",
  "Number_of_Treatment_Arms", "Sponsor", "Source", "Trial_Acronym",
  "Trial_Registry_Number", "Trial_Start_Year", "Trial_End_Year",
  "Primary_Study_Treatment", "Clinical_Phase", "Inclusion_Criteria",
  "Exclusion_Criteria", "Treatment_Arm", "Dose_Description",
  "Treatmen_1_Frequency", "Treatment_1_ROA", "Outcome_Short_Form",
  "Outcome_Measurement_Time", "Outcome_Measurement_Time_Unit",
  "Outcome_Value", "N_pts_in_Analysis", "N_Events_in_Analysis",
  "Statistical_Population", "Minimum_age", "Imputation_Method",
  "Maximum_age", "Minimum_Age"
)

# ── Derivation chain ─────────────────────────────────────────────────────────
# Binary: n_events = round(outcome_value/100 * n_pts), r = n_events,
#         n = n_pts, y = r/n, se = sqrt(y*(1-y)/n)
# Continuous: y = outcome_value, se = SE or SD/sqrt(n), r = NA, n_events = NA

derive_arm <- function(outcome_value = NA, n_pts = NA, n_events = NA) {
  ov <- suppressWarnings(as.numeric(outcome_value))
  np <- suppressWarnings(as.integer(n_pts))
  ne <- suppressWarnings(as.integer(n_events))

  if (is.na(ne) && !is.na(ov) && !is.na(np) && np > 0) {
    ne <- as.integer(round(ov / 100 * np))
  }

  r  <- ne
  n  <- np
  y  <- if (!is.na(r) && !is.na(n) && n > 0) r / n else NA_real_
  se <- if (!is.na(y) && !is.na(n) && n > 0) sqrt(y * (1 - y) / n) else NA_real_

  tibble(n_events = ne, r = r, n = n, y = y, se = se)
}

derive_arm_continuous <- function(outcome_value = NA, n_pts = NA,
                                  se = NA, sd = NA) {
  ov     <- suppressWarnings(as.numeric(outcome_value))
  np     <- suppressWarnings(as.integer(n_pts))
  se_val <- suppressWarnings(as.numeric(se))
  sd_val <- suppressWarnings(as.numeric(sd))

  if (is.na(se_val) && !is.na(sd_val) && !is.na(np) && np > 0) {
    se_val <- sd_val / sqrt(np)
  }

  tibble(n_events = NA_integer_, r = NA_integer_, n = np, y = ov, se = se_val)
}

derive_all <- function(arms_df, response_type = "binary") {
  if (response_type == "continuous") {
    derived <- pmap_dfr(
      list(
        arms_df$outcome_value,
        arms_df$n_pts,
        if ("se" %in% names(arms_df)) arms_df$se else rep(NA_real_, nrow(arms_df)),
        if ("sd" %in% names(arms_df)) arms_df$sd else rep(NA_real_, nrow(arms_df))
      ),
      ~ derive_arm_continuous(..1, ..2, ..3, ..4)
    )
  } else {
    derived <- pmap_dfr(
      list(
        arms_df$outcome_value,
        arms_df$n_pts,
        if ("n_events" %in% names(arms_df)) arms_df$n_events
        else rep(NA_integer_, nrow(arms_df))
      ),
      ~ derive_arm(..1, ..2, ..3)
    )
  }
  arms_df |>
    mutate(
      n_events = derived$n_events,
      r = derived$r,
      n = derived$n,
      y = derived$y,
      se = derived$se
    )
}

# ── Map extracted arms to Batman schema ──────────────────────────────────────
# Ported from batman_schema.R::append_to_batman() lines 40-124

build_batman_rows <- function(arms_df, meta, max_study_ind = 0L) {
  study_name <- meta$acronym

  arms_df |>
    mutate(
      study     = study_name,
      study_ind = max_study_ind + 1L,
      # arm_ind: placebo = 1, active arms numbered sequentially
      arm_ind   = row_number(),
      Link_to_Article = if (!is.null(meta$nct_id) && !is.na(meta$nct_id)) {
        paste0("https://clinicaltrials.gov/study/", meta$nct_id)
      } else {
        NA_character_
      },
      Location  = "ClinicalTrials.gov Results",
      Publication_Year = {
        rpy <- meta$results_posted_year
        ey  <- meta$end_year
        yr <- if (!is.null(rpy) && !is.na(rpy) && nchar(as.character(rpy)) == 4) rpy else ey
        as.integer(yr)
      },
      Number_of_Treatment_Arms = as.numeric(meta$n_arms),
      Sponsor   = meta$sponsor %||% NA_character_,
      Source     = if ("source" %in% names(arms_df)) source else NA_character_,
      Trial_Acronym = study_name,
      Trial_Registry_Number = meta$nct_id %||% NA_character_,
      Trial_Start_Year = as.integer(meta$start_year %||% NA),
      Trial_End_Year   = as.numeric(meta$end_year %||% NA),
      Primary_Study_Treatment = meta$primary_treatment %||% NA_character_,
      Clinical_Phase = meta$phase %||% NA_character_,
      Inclusion_Criteria = {
        ic <- meta$inclusion_criteria
        if (is.null(ic) || is.na(ic)) meta$eligibility_criteria %||% NA_character_
        else ic
      },
      Exclusion_Criteria = meta$exclusion_criteria %||% NA_character_,
      Treatment_Arm = treat,
      Dose_Description = if ("dose_description" %in% names(arms_df)) {
        ifelse(!is.na(dose_description), dose_description, treat)
      } else {
        treat
      },
      # Infer dosing frequency from treatment name
      Treatmen_1_Frequency = {
        t_lc <- str_to_lower(treat)
        case_when(
          str_detect(t_lc, "q2w|every\\s*2\\s*week|biweekly|every\\s*other\\s*week") ~ "Q2W",
          str_detect(t_lc, "q4w|every\\s*4\\s*week|monthly") ~ "Q4W",
          str_detect(t_lc, "q8w|every\\s*8\\s*week") ~ "Q8W",
          str_detect(t_lc, "q12w|every\\s*12\\s*week") ~ "Q12W",
          str_detect(t_lc, "qw|every\\s*week|weekly") ~ "QW",
          str_detect(t_lc, "qd|once\\s*daily|daily") ~ "QD",
          str_detect(t_lc, "bid|twice\\s*daily") ~ "BID",
          TRUE ~ NA_character_
        )
      },
      # Infer route of administration from treatment name
      Treatment_1_ROA = {
        t_lc <- str_to_lower(treat)
        case_when(
          str_detect(t_lc, "\\bsc\\b|subcutaneous") ~ "SC",
          str_detect(t_lc, "\\biv\\b|intravenous") ~ "IV",
          str_detect(t_lc, "\\boral\\b|\\bpo\\b|tablet|capsule") ~ "Oral",
          str_detect(t_lc, "topical|cream|ointment") ~ "Topical",
          str_detect(t_lc, "\\bim\\b|intramuscular") ~ "IM",
          TRUE ~ NA_character_
        )
      },
      Outcome_Short_Form = if ("endpoint" %in% names(arms_df)) {
        ifelse(!is.na(endpoint), toupper(endpoint), "UNKNOWN")
      } else {
        "UNKNOWN"
      },
      Outcome_Measurement_Time = as.numeric(
        if ("measurement_time" %in% names(arms_df)) measurement_time else NA
      ),
      Outcome_Measurement_Time_Unit = "Week",
      Outcome_Value = as.numeric(outcome_value),
      N_pts_in_Analysis = as.numeric(n_pts),
      N_Events_in_Analysis = as.numeric(n_events),
      Statistical_Population = if ("stat_pop" %in% names(arms_df)) stat_pop else NA_character_,
      Minimum_age = as.character(meta$min_age %||% NA),
      Imputation_Method = if ("estimand" %in% names(arms_df)) estimand else NA_character_,
      Maximum_age = as.character(meta$max_age %||% NA),
      Minimum_Age = as.character(meta$min_age %||% NA)
    )
}

# ── Column matching & type coercion ──────────────────────────────────────────
# Ported from batman_schema.R lines 130-200

align_columns <- function(new_rows, existing_df) {
  # Alias map: canonical name → possible alternate names in existing files
  col_aliases <- c(
    "Trial_Registry_Number"    = "NCT_ID",
    "Trial_Acronym"            = "Study_Name",
    "Primary_Study_Treatment"  = "Study_Treatment",
    "Treatment_Arm"            = "original_treat",
    "Sponsor"                  = "Sponsor"
  )

  # First pass: rename via alias map
  for (canonical in names(col_aliases)) {
    alias <- col_aliases[canonical]
    if (canonical %in% names(new_rows) && alias %in% names(existing_df) &&
        !canonical %in% names(existing_df)) {
      idx <- which(names(new_rows) == canonical)
      if (length(idx) == 1) names(new_rows)[idx] <- alias
    }
  }

  # Second pass: case-insensitive matching
  existing_names_lc <- tolower(names(existing_df))

  rename_map <- character()
  for (i in seq_along(names(new_rows))) {
    new_col <- names(new_rows)[i]
    match_idx <- match(tolower(new_col), existing_names_lc)
    if (!is.na(match_idx)) {
      existing_col <- names(existing_df)[match_idx]
      if (new_col != existing_col) {
        rename_map[new_col] <- existing_col
      }
    }
  }

  if (length(rename_map) > 0) {
    for (old_name in names(rename_map)) {
      idx <- which(names(new_rows) == old_name)
      if (length(idx) == 1) names(new_rows)[idx] <- rename_map[old_name]
    }
  }

  # Fill missing columns with NA
  for (col in names(existing_df)) {
    if (!col %in% names(new_rows)) new_rows[[col]] <- NA
  }

  new_rows <- new_rows |> select(all_of(names(existing_df)))

  # Type coercion to match existing file
  numeric_patterns <- c(
    "study_ind", "arm_ind", "n", "r", "y", "se",
    "publication_year", "number_of_treatment_arms",
    "trial_start_year", "trial_end_year",
    "outcome_measurement_time", "outcome_value",
    "n_pts_in_analysis", "n_events_in_analysis",
    "randomized_n"
  )

  for (col in intersect(names(existing_df), names(new_rows))) {
    if (tolower(col) %in% numeric_patterns) {
      existing_df[[col]] <- suppressWarnings(as.numeric(existing_df[[col]]))
      new_rows[[col]]    <- suppressWarnings(as.numeric(new_rows[[col]]))
    } else {
      existing_df[[col]] <- as.character(existing_df[[col]])
      new_rows[[col]]    <- as.character(new_rows[[col]])
    }
  }

  list(new_rows = new_rows, existing_df = existing_df)
}


# ── CLI argument parser ──────────────────────────────────────────────────────
# Same pattern as generate_ridge_plot.R

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


# ── Main entry point ─────────────────────────────────────────────────────────

if (!interactive() && length(commandArgs(trailingOnly = TRUE)) > 0) {
  params <- parse_args(commandArgs(trailingOnly = TRUE))

  # Validate required arguments
  excel_path <- params$excel_path
  data_json  <- params$data_json

  if (is.null(excel_path)) stop("Required: --excel_path <path to Batman input Excel>")
  if (is.null(data_json))  stop("Required: --data_json <path to JSON data file>")

  preview_only <- isTRUE(params$preview_only)
  do_backup    <- isTRUE(params$backup)
  output_path  <- params$output %||% NULL

  # ── Read existing Excel ──
  excel_path <- normalizePath(excel_path, mustWork = FALSE)
  if (!file.exists(excel_path)) {
    stop(glue("Cannot access Batman input file: {excel_path}\nIs the network drive mounted?"))
  }

  message(glue("Reading existing Batman input: {excel_path}"))
  existing_df <- read_excel(excel_path)
  message(glue("  Existing rows: {nrow(existing_df)}, columns: {ncol(existing_df)}"))

  max_study_ind <- if (nrow(existing_df) > 0 && "study_ind" %in% names(existing_df)) {
    max(suppressWarnings(as.numeric(existing_df$study_ind)), na.rm = TRUE)
  } else if (nrow(existing_df) > 0) {
    # Try case-insensitive match
    si_col <- names(existing_df)[tolower(names(existing_df)) == "study_ind"]
    if (length(si_col) > 0) max(suppressWarnings(as.numeric(existing_df[[si_col[1]]])), na.rm = TRUE)
    else 0L
  } else {
    0L
  }

  # ── Read JSON data ──
  data_json_path <- normalizePath(data_json, mustWork = FALSE)
  if (!file.exists(data_json_path)) {
    stop(glue("Cannot find JSON data file: {data_json_path}"))
  }

  input_data <- fromJSON(data_json_path, simplifyVector = TRUE)
  arms_df    <- as_tibble(input_data$arms)
  meta       <- input_data$meta
  target_endpoints <- input_data$target_endpoints
  response_type    <- input_data$response_type %||% "binary"

  # ── Filter to target endpoints ──
  if (!is.null(target_endpoints) && "endpoint" %in% names(arms_df)) {
    arms_df <- arms_df |> filter(tolower(endpoint) %in% tolower(target_endpoints))
  }

  if (nrow(arms_df) == 0) {
    message("No arms match the target endpoints. Nothing to append.")
    cat(toJSON(list(status = "empty", rows_added = 0), auto_unbox = TRUE))
    quit(status = 0)
  }

  # ── Run derivation chain ──
  arms_df <- derive_all(arms_df, response_type = response_type)

  # ── Build Batman-schema rows ──
  new_rows <- build_batman_rows(arms_df, meta, max_study_ind = max_study_ind)

  # ── Align columns with existing file ──
  aligned <- align_columns(new_rows, existing_df)
  new_rows    <- aligned$new_rows
  existing_df <- aligned$existing_df

  # ── Preview mode ──
  if (preview_only) {
    # Select key columns for display
    display_cols <- c("study", "study_ind", "treat", "arm_ind", "n", "r", "y", "se",
                      "Outcome_Short_Form", "Outcome_Measurement_Time", "Outcome_Value",
                      "N_pts_in_Analysis", "N_Events_in_Analysis", "Imputation_Method",
                      "Treatmen_1_Frequency", "Treatment_1_ROA")
    # Use actual column names from new_rows (may have been renamed)
    avail_display <- intersect(display_cols, names(new_rows))
    # Also try case-insensitive
    for (dc in display_cols) {
      match_col <- names(new_rows)[tolower(names(new_rows)) == tolower(dc)]
      if (length(match_col) > 0) avail_display <- unique(c(avail_display, match_col))
    }

    preview_data <- new_rows |> select(any_of(avail_display))

    result <- list(
      status = "preview",
      rows_to_add = nrow(new_rows),
      new_study_ind = max_study_ind + 1L,
      existing_rows = nrow(existing_df),
      total_after = nrow(existing_df) + nrow(new_rows),
      rows = preview_data
    )

    cat(toJSON(result, auto_unbox = TRUE, pretty = TRUE, na = "null"))
    quit(status = 0)
  }

  # ── Write mode ──
  combined_df <- bind_rows(existing_df, new_rows)

  # Backup if requested
  if (do_backup) {
    backup_name <- sub(
      "\\.xlsx$",
      paste0("_backup_", format(Sys.time(), "%Y%m%d_%H%M"), ".xlsx"),
      excel_path
    )
    file.copy(excel_path, backup_name)
    message(glue("  Backup created: {backup_name}"))
  }

  # Write to output or original
  write_path <- output_path %||% excel_path
  write_xlsx(combined_df, write_path)

  result <- list(
    status = "success",
    rows_added = nrow(new_rows),
    new_study_ind = max_study_ind + 1L,
    total_rows = nrow(combined_df),
    output_path = write_path,
    backup_path = if (do_backup) backup_name else NULL
  )

  message(glue("\n✅ Appended {nrow(new_rows)} rows to Batman input file."))
  message(glue("   study_ind = {max_study_ind + 1L}"))
  message(glue("   Total rows: {nrow(combined_df)}"))
  message(glue("   Written to: {write_path}"))

  cat(toJSON(result, auto_unbox = TRUE, pretty = TRUE, na = "null"))
}
