# Competitor Database API
#
# A Plumber API deployed on Posit Connect that wraps a SQLite database.
# Provides shared read/write access for the competitor analysis agent.
# Colleagues interact ONLY through the Claude Code agent — they never see this API directly.
#
# Deploy: rsconnect::deployAPI("database/api", server = "posit-connect.am.lilly.com")
#
# Endpoints:
#   GET  /studies          - List studies (filter by indication)
#   GET  /studies/:id      - Get one study with its arms
#   GET  /arms             - Query arms (filter by indication, endpoint, timepoint)
#   POST /studies          - Insert a new study + arms
#   GET  /summary          - Database summary by indication
#   GET  /landscape        - Landscape data for charts
#   GET  /download         - Download data as Excel file
#   GET  /health           - Health check

library(plumber)
library(DBI)
library(RSQLite)
library(jsonlite)
library(dplyr)
library(glue)
library(writexl)

# ── Database connection ───────────────────────────────────────────────────
# On Posit Connect, the working directory IS the app bundle directory
# and it's writable. The SQLite file lives right there.

DB_PATH <- "competitor_db.sqlite"

get_con <- function() {
  con <- dbConnect(SQLite(), DB_PATH)
  dbExecute(con, "PRAGMA journal_mode=WAL;")
  con
}

# Initialize database with schema if it doesn't exist
init_db <- function() {
  con <- get_con()
  on.exit(dbDisconnect(con))

  dbExecute(con, "CREATE TABLE IF NOT EXISTS studies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nct_id TEXT,
    study_name TEXT,
    trial_acronym TEXT,
    indication TEXT NOT NULL,
    phase TEXT,
    sponsor TEXT,
    design TEXT,
    source TEXT,
    source_url TEXT,
    publication_year INTEGER,
    trial_start_year INTEGER,
    trial_end_year INTEGER,
    inclusion_criteria TEXT,
    exclusion_criteria TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    created_by TEXT
  )")

  dbExecute(con, "CREATE TABLE IF NOT EXISTS arms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    study_id INTEGER REFERENCES studies(id),
    treatment TEXT NOT NULL,
    dose_description TEXT,
    frequency TEXT,
    route TEXT,
    n_randomized INTEGER,
    n_analyzed INTEGER,
    endpoint TEXT NOT NULL,
    endpoint_label TEXT,
    timepoint_weeks INTEGER,
    outcome_value REAL,
    responders INTEGER,
    se REAL,
    ci_lower REAL,
    ci_upper REAL,
    p_value REAL,
    estimand TEXT,
    response_type TEXT DEFAULT 'binary',
    statistical_population TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    created_by TEXT
  )")

  dbExecute(con, "CREATE TABLE IF NOT EXISTS updates_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    study_id INTEGER REFERENCES studies(id),
    action TEXT NOT NULL,
    source_type TEXT,
    source_ref TEXT,
    details TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    created_by TEXT
  )")

  dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_arms_study ON arms(study_id)")
  dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_studies_indication ON studies(indication)")
  dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_studies_nct ON studies(nct_id)")

  message("Database initialized at: ", DB_PATH)
}

init_db()


#* @apiTitle Competitor Intelligence Database
#* @apiDescription Shared database for competitor clinical trial data (Eli Lilly Immunology)


# ── HTML View (for QC in browser) ────────────────────────────────────────

#* View data as an HTML table in the browser
#* @param indication Filter by indication code (e.g., "ad", "uc")
#* @param endpoint Filter by endpoint code (e.g., "easi75")
#* @param timepoint_weeks Filter by timepoint
#* @serializer html
#* @get /view
function(indication = NULL, endpoint = NULL, timepoint_weeks = NULL) {
  con <- get_con()
  on.exit(dbDisconnect(con))

  query <- "SELECT s.indication, s.study_name, s.nct_id, s.phase, s.sponsor,
                   a.treatment, a.dose_description, a.frequency,
                   a.n_randomized, a.endpoint, a.timepoint_weeks,
                   a.outcome_value, a.ci_lower, a.ci_upper, a.p_value,
                   a.estimand, a.response_type, a.created_by, a.created_at
            FROM arms a JOIN studies s ON a.study_id = s.id WHERE 1=1"
  params <- list()

  if (!is.null(indication) && nchar(indication) > 0) {
    query <- paste(query, "AND s.indication = ?")
    params <- c(params, list(indication))
  }
  if (!is.null(endpoint) && nchar(endpoint) > 0) {
    query <- paste(query, "AND a.endpoint = ?")
    params <- c(params, list(endpoint))
  }
  if (!is.null(timepoint_weeks) && nchar(timepoint_weeks) > 0) {
    query <- paste(query, "AND a.timepoint_weeks = ?")
    params <- c(params, list(as.integer(timepoint_weeks)))
  }

  query <- paste(query, "ORDER BY s.indication, a.endpoint, a.timepoint_weeks, a.outcome_value DESC")
  data <- dbGetQuery(con, query, params = params)

  # Summary stats
  n_studies <- length(unique(data$study_name))
  n_arms <- nrow(data)
  indications <- paste(unique(data$indication), collapse = ", ")

  # Build filter links
  all_indications <- dbGetQuery(con, "SELECT DISTINCT indication FROM studies ORDER BY indication")$indication

  filter_links <- paste(
    sapply(all_indications, function(ind) {
      selected <- if (!is.null(indication) && ind == indication) " style='font-weight:bold; color:#C8102E;'" else ""
      sprintf('<a href="?indication=%s"%s>%s</a>', ind, selected, toupper(ind))
    }),
    collapse = " | "
  )
  if (nchar(filter_links) > 0) {
    filter_links <- paste('<a href="?">ALL</a> |', filter_links)
  }

  # Build HTML table rows
  if (n_arms == 0) {
    table_html <- "<tr><td colspan='12' style='text-align:center; padding:40px; color:#666;'>No data found. Use the agent to extract and insert competitor data.</td></tr>"
  } else {
    table_html <- paste(apply(data, 1, function(row) {
      ci <- if (!is.na(row["ci_lower"]) && !is.na(row["ci_upper"])) {
        sprintf("%.1f–%.1f", as.numeric(row["ci_lower"]), as.numeric(row["ci_upper"]))
      } else { "—" }
      sprintf(
        "<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td style='font-weight:bold;'>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>",
        toupper(row["indication"] %||% ""),
        row["study_name"] %||% "—",
        row["treatment"] %||% "",
        row["dose_description"] %||% "—",
        row["n_randomized"] %||% "—",
        row["endpoint"] %||% "",
        row["timepoint_weeks"] %||% "—",
        if (!is.na(row["outcome_value"])) sprintf("%.1f%%", as.numeric(row["outcome_value"])) else "—",
        ci,
        row["estimand"] %||% "—",
        row["sponsor"] %||% "—",
        row["created_by"] %||% "—"
      )
    }), collapse = "\n")
  }

  # Full HTML page
  sprintf('<!DOCTYPE html>
<html>
<head>
  <title>Competitor Intelligence Database</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: Arial, sans-serif; padding: 24px; background: #f9f9f9; color: #333; }
    h1 { color: #C8102E; margin-bottom: 8px; font-size: 24px; }
    .subtitle { color: #666; margin-bottom: 16px; }
    .stats { background: white; padding: 12px 16px; border-radius: 6px; margin-bottom: 16px;
             border: 1px solid #e0e0e0; display: inline-block; }
    .stats span { margin-right: 24px; }
    .stats strong { color: #C8102E; }
    .filters { margin-bottom: 16px; }
    .filters a { text-decoration: none; color: #1a73e8; margin: 0 4px; }
    .filters a:hover { text-decoration: underline; }
    table { width: 100%%; border-collapse: collapse; background: white; border-radius: 6px;
            overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
    th { background: #C8102E; color: white; padding: 10px 12px; text-align: left;
         font-size: 12px; text-transform: uppercase; letter-spacing: 0.5px; }
    td { padding: 8px 12px; border-bottom: 1px solid #eee; font-size: 13px; }
    tr:hover { background: #fff8f8; }
    .footer { margin-top: 16px; font-size: 11px; color: #999; }
  </style>
</head>
<body>
  <h1>Competitor Intelligence Database</h1>
  <p class="subtitle">Eli Lilly Immunology &mdash; Shared competitor trial data</p>

  <div class="stats">
    <span><strong>%d</strong> studies</span>
    <span><strong>%d</strong> arms</span>
    <span>Indications: %s</span>
  </div>

  <div class="filters">Filter: %s</div>

  <table>
    <thead>
      <tr>
        <th>Indication</th><th>Study</th><th>Treatment</th><th>Dose</th>
        <th>N</th><th>Endpoint</th><th>Week</th><th>Result</th>
        <th>95%% CI</th><th>Estimand</th><th>Sponsor</th><th>Added by</th>
      </tr>
    </thead>
    <tbody>
      %s
    </tbody>
  </table>

  <p class="footer">Review is required before disclosure. &bull; Data sourced via Competitor Analysis Agent.</p>
</body>
</html>',
    n_studies, n_arms, indications, filter_links, table_html
  )
}


# ── Health Check ──────────────────────────────────────────────────────────

#* Health check
#* @get /health
function() {
  con <- get_con()
  on.exit(dbDisconnect(con))
  n_studies <- dbGetQuery(con, "SELECT COUNT(*) as n FROM studies")$n

  n_arms <- dbGetQuery(con, "SELECT COUNT(*) as n FROM arms")$n
  list(
    status = "ok",
    database = DB_PATH,
    studies = n_studies,
    arms = n_arms,
    timestamp = Sys.time()
  )
}


# ── GET /studies ──────────────────────────────────────────────────────────

#* List studies, optionally filtered by indication
#* @param indication Filter by indication code (e.g., "ad", "uc")
#* @param limit Max rows to return (default 100)
#* @get /studies
function(indication = NULL, limit = 100) {
  con <- get_con()
  on.exit(dbDisconnect(con))

  query <- "SELECT * FROM studies"
  params <- list()

  if (!is.null(indication) && nchar(indication) > 0) {
    query <- paste(query, "WHERE indication = ?")
    params <- list(indication)
  }

  query <- paste(query, "ORDER BY created_at DESC LIMIT ?")
  params <- c(params, list(as.integer(limit)))

  dbGetQuery(con, query, params = params)
}


# ── GET /studies/:id ──────────────────────────────────────────────────────

#* Get a single study with all its arms
#* @param id Study ID
#* @get /studies/<id:int>
function(id) {
  con <- get_con()
  on.exit(dbDisconnect(con))

  study <- dbGetQuery(con, "SELECT * FROM studies WHERE id = ?", params = list(id))
  if (nrow(study) == 0) {
    res$status <- 404
    return(list(error = "Study not found"))
  }

  arms <- dbGetQuery(con, "SELECT * FROM arms WHERE study_id = ?", params = list(id))

  list(study = study, arms = arms)
}


# ── GET /arms ─────────────────────────────────────────────────────────────

#* Query arms data with filters
#* @param indication Filter by indication code
#* @param endpoint Filter by endpoint code (e.g., "easi75")
#* @param timepoint_weeks Filter by timepoint
#* @param treatment Filter by treatment name (partial match)
#* @param limit Max rows (default 500)
#* @get /arms
function(indication = NULL, endpoint = NULL, timepoint_weeks = NULL,
         treatment = NULL, limit = 500) {
  con <- get_con()
  on.exit(dbDisconnect(con))

  query <- "SELECT a.*, s.indication, s.study_name, s.nct_id, s.phase, s.sponsor
            FROM arms a JOIN studies s ON a.study_id = s.id WHERE 1=1"
  params <- list()

  if (!is.null(indication) && nchar(indication) > 0) {
    query <- paste(query, "AND s.indication = ?")
    params <- c(params, list(indication))
  }
  if (!is.null(endpoint) && nchar(endpoint) > 0) {
    query <- paste(query, "AND a.endpoint = ?")
    params <- c(params, list(endpoint))
  }
  if (!is.null(timepoint_weeks) && nchar(timepoint_weeks) > 0) {
    query <- paste(query, "AND a.timepoint_weeks = ?")
    params <- c(params, list(as.integer(timepoint_weeks)))
  }
  if (!is.null(treatment) && nchar(treatment) > 0) {
    query <- paste(query, "AND a.treatment LIKE ?")
    params <- c(params, list(paste0("%", treatment, "%")))
  }

  query <- paste(query, "ORDER BY s.indication, a.endpoint, a.timepoint_weeks LIMIT ?")
  params <- c(params, list(as.integer(limit)))

  dbGetQuery(con, query, params = params)
}


# ── POST /studies ─────────────────────────────────────────────────────────

#* Insert a new study with its arms
#* @post /studies
function(req) {
  con <- get_con()
  on.exit(dbDisconnect(con))

  body <- fromJSON(req$postBody, simplifyDataFrame = TRUE)

  # Validate required fields
  study <- body$study
  arms <- body$arms

  if (is.null(study) || is.null(arms)) {
    res$status <- 400
    return(list(error = "Request must include 'study' and 'arms' objects"))
  }

  if (is.null(study$indication) || nchar(study$indication) == 0) {
    res$status <- 400
    return(list(error = "'study.indication' is required"))
  }

  # Check for duplicate NCT ID
  if (!is.null(study$nct_id) && nchar(study$nct_id) > 0) {
    existing <- dbGetQuery(con, "SELECT id FROM studies WHERE nct_id = ?",
                           params = list(study$nct_id))
    if (nrow(existing) > 0) {
      return(list(
        warning = "Study with this NCT ID already exists",
        existing_id = existing$id[1],
        action = "Use PUT /studies/<id> to update, or confirm duplicate is intentional"
      ))
    }
  }

  # Insert study
  dbExecute(con, glue(
    "INSERT INTO studies (nct_id, study_name, trial_acronym, indication, phase,
     sponsor, design, source, source_url, publication_year, created_by)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
  ), params = list(
    study$nct_id %||% NA,
    study$study_name %||% NA,
    study$trial_acronym %||% NA,
    study$indication,
    study$phase %||% NA,
    study$sponsor %||% NA,
    study$design %||% NA,
    study$source %||% NA,
    study$source_url %||% NA,
    study$publication_year %||% NA,
    study$created_by %||% "agent"
  ))

  study_id <- dbGetQuery(con, "SELECT last_insert_rowid() as id")$id


  # Insert arms
  n_inserted <- 0
  if (is.data.frame(arms) && nrow(arms) > 0) {
    for (i in seq_len(nrow(arms))) {
      arm <- arms[i, ]
      dbExecute(con, glue(
        "INSERT INTO arms (study_id, treatment, dose_description, frequency, route,
         n_randomized, n_analyzed, endpoint, endpoint_label, timepoint_weeks,
         outcome_value, responders, se, ci_lower, ci_upper, p_value,
         estimand, response_type, statistical_population, created_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
      ), params = list(
        study_id,
        arm$treatment %||% NA,
        arm$dose_description %||% NA,
        arm$frequency %||% NA,
        arm$route %||% NA,
        arm$n_randomized %||% NA,
        arm$n_analyzed %||% NA,
        arm$endpoint %||% NA,
        arm$endpoint_label %||% NA,
        arm$timepoint_weeks %||% NA,
        arm$outcome_value %||% NA,
        arm$responders %||% NA,
        arm$se %||% NA,
        arm$ci_lower %||% NA,
        arm$ci_upper %||% NA,
        arm$p_value %||% NA,
        arm$estimand %||% NA,
        arm$response_type %||% "binary",
        arm$statistical_population %||% NA,
        arm$created_by %||% "agent"
      ))
      n_inserted <- n_inserted + 1
    }
  }

  # Log the insert
  dbExecute(con, glue(
    "INSERT INTO updates_log (study_id, action, source_type, source_ref, created_by)
     VALUES (?, 'insert', ?, ?, ?)"
  ), params = list(
    study_id,
    study$source %||% "manual",
    study$source_url %||% NA,
    study$created_by %||% "agent"
  ))

  list(
    success = TRUE,
    study_id = study_id,
    arms_inserted = n_inserted
  )
}


# ── GET /summary ──────────────────────────────────────────────────────────

#* Database summary — counts by indication and endpoint
#* @get /summary
function() {
  con <- get_con()
  on.exit(dbDisconnect(con))

  by_indication <- dbGetQuery(con,
    "SELECT s.indication, COUNT(DISTINCT s.id) as n_studies, COUNT(a.id) as n_arms
     FROM studies s LEFT JOIN arms a ON s.id = a.study_id
     GROUP BY s.indication ORDER BY s.indication")

  by_endpoint <- dbGetQuery(con,
    "SELECT s.indication, a.endpoint, COUNT(*) as n_arms
     FROM arms a JOIN studies s ON a.study_id = s.id
     GROUP BY s.indication, a.endpoint
     ORDER BY s.indication, a.endpoint")

  list(
    total_studies = sum(by_indication$n_studies),
    total_arms = sum(by_indication$n_arms),
    by_indication = by_indication,
    by_endpoint = by_endpoint
  )
}


# ── GET /landscape ────────────────────────────────────────────────────────

#* Landscape data for a specific indication/endpoint/timepoint
#* @param indication Indication code (required)
#* @param endpoint Endpoint code (required)
#* @param timepoint_weeks Timepoint in weeks (uses indication default if omitted)
#* @get /landscape
function(indication, endpoint, timepoint_weeks = NULL) {
  con <- get_con()
  on.exit(dbDisconnect(con))

  if (missing(indication) || missing(endpoint)) {
    res$status <- 400
    return(list(error = "Both 'indication' and 'endpoint' are required"))
  }

  query <- "SELECT a.treatment, a.dose_description, a.frequency,
                   a.n_randomized, a.outcome_value, a.ci_lower, a.ci_upper,
                   a.estimand, a.timepoint_weeks,
                   s.study_name, s.nct_id, s.phase, s.sponsor
            FROM arms a JOIN studies s ON a.study_id = s.id
            WHERE s.indication = ? AND a.endpoint = ?"
  params <- list(indication, endpoint)

  if (!is.null(timepoint_weeks) && nchar(timepoint_weeks) > 0) {
    query <- paste(query, "AND a.timepoint_weeks = ?")
    params <- c(params, list(as.integer(timepoint_weeks)))
  }

  query <- paste(query, "ORDER BY a.outcome_value DESC")
  dbGetQuery(con, query, params = params)
}


# ── GET /download ─────────────────────────────────────────────────────────

#* Download data as an Excel file
#* @param indication Filter by indication code (e.g., "ad"). If omitted, downloads all.
#* @param endpoint Filter by endpoint code (e.g., "easi75")
#* @serializer contentType list(type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
#* @get /download
function(indication = NULL, endpoint = NULL, res) {
  con <- get_con()
  on.exit(dbDisconnect(con))

  query <- "SELECT s.indication, s.study_name, s.nct_id, s.trial_acronym, s.phase, s.sponsor,
                   a.treatment, a.dose_description, a.frequency, a.route,
                   a.n_randomized, a.n_analyzed, a.endpoint, a.endpoint_label,
                   a.timepoint_weeks, a.outcome_value, a.responders,
                   a.se, a.ci_lower, a.ci_upper, a.p_value,
                   a.estimand, a.response_type, a.statistical_population,
                   a.created_at, a.created_by
            FROM arms a JOIN studies s ON a.study_id = s.id WHERE 1=1"
  params <- list()

  if (!is.null(indication) && nchar(indication) > 0) {
    query <- paste(query, "AND s.indication = ?")
    params <- c(params, list(indication))
  }
  if (!is.null(endpoint) && nchar(endpoint) > 0) {
    query <- paste(query, "AND a.endpoint = ?")
    params <- c(params, list(endpoint))
  }

  query <- paste(query, "ORDER BY s.indication, a.endpoint, a.timepoint_weeks, a.outcome_value DESC")
  data <- dbGetQuery(con, query, params = params)

  # Write to temp Excel file
  fname <- if (!is.null(indication)) {
    sprintf("competitor_data_%s_%s.xlsx", indication, format(Sys.Date(), "%Y%m%d"))
  } else {
    sprintf("competitor_data_all_%s.xlsx", format(Sys.Date(), "%Y%m%d"))
  }

  tmp <- file.path(tempdir(), fname)
  writexl::write_xlsx(data, tmp)

  # Return the file
  res$setHeader("Content-Disposition", sprintf('attachment; filename="%s"', fname))
  readBin(tmp, "raw", file.info(tmp)$size)
}


# ── Null coalescing operator ──────────────────────────────────────────────
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (is.character(x) && nchar(x) == 0)) y else x


# ── Disable Swagger UI + redirect root to /view ──────────────────────────

#* @plumber
function(pr) {
  pr$setDocs(FALSE)
}
