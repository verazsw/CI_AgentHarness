-- Competitor Database Schema
-- SQLite database served via Plumber API on Posit Connect

-- Studies table: one row per clinical trial
CREATE TABLE IF NOT EXISTS studies (
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
);

-- Arms table: one row per treatment arm per endpoint per timepoint
CREATE TABLE IF NOT EXISTS arms (
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
);

-- Updates log: audit trail of all changes
CREATE TABLE IF NOT EXISTS updates_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    study_id INTEGER REFERENCES studies(id),
    action TEXT NOT NULL,
    source_type TEXT,
    source_ref TEXT,
    details TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    created_by TEXT
);

-- Index for common queries
CREATE INDEX IF NOT EXISTS idx_arms_indication ON arms(study_id);
CREATE INDEX IF NOT EXISTS idx_studies_indication ON studies(indication);
CREATE INDEX IF NOT EXISTS idx_studies_nct ON studies(nct_id);
