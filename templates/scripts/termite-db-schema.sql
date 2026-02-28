-- Termite Protocol v3.4 SQLite Schema
-- All shared state in a single WAL-mode database.
-- YAML files become export-only (audit, human reading).

PRAGMA journal_mode=WAL;
PRAGMA busy_timeout=5000;
PRAGMA foreign_keys=ON;

CREATE TABLE IF NOT EXISTS schema_version (
  version INTEGER PRIMARY KEY,
  applied_at TEXT DEFAULT (datetime('now'))
);
INSERT OR IGNORE INTO schema_version(version) VALUES (1);

-- Signals (replaces signals/active/*.yaml)
CREATE TABLE IF NOT EXISTS signals (
  id TEXT PRIMARY KEY,           -- S-001, S-002, ...
  type TEXT NOT NULL,            -- HOLE|EXPLORE|PHEROMONE|PROBE|FEEDBACK|BLOCKED
  title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open',  -- open|claimed|done|stale|archived|parked
  weight INTEGER NOT NULL DEFAULT 30,
  ttl_days INTEGER DEFAULT 14,
  created TEXT NOT NULL,
  last_touched TEXT NOT NULL,
  owner TEXT DEFAULT 'unassigned',
  module TEXT DEFAULT '',
  tags TEXT DEFAULT '[]',        -- JSON array
  next_hint TEXT DEFAULT '',
  touch_count INTEGER DEFAULT 0,
  source TEXT DEFAULT 'autonomous',  -- autonomous|directive|emergent
  parked_reason TEXT,
  parked_conditions TEXT,
  parked_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_signals_status ON signals(status);
CREATE INDEX IF NOT EXISTS idx_signals_type_weight ON signals(type, weight);

-- Observations (replaces signals/observations/*.yaml)
CREATE TABLE IF NOT EXISTS observations (
  id TEXT PRIMARY KEY,           -- O-20260228120000
  pattern TEXT NOT NULL,
  context TEXT DEFAULT 'unknown',
  reporter TEXT NOT NULL,
  confidence TEXT DEFAULT 'medium',
  created TEXT NOT NULL,
  source TEXT DEFAULT 'autonomous',
  detail TEXT,
  merged_count INTEGER DEFAULT 0,
  merged_from TEXT               -- JSON array of original IDs
);
CREATE INDEX IF NOT EXISTS idx_obs_pattern ON observations(pattern);
CREATE INDEX IF NOT EXISTS idx_obs_created ON observations(created);

-- Rules (replaces signals/rules/*.yaml)
CREATE TABLE IF NOT EXISTS rules (
  id TEXT PRIMARY KEY,           -- R-001
  trigger_text TEXT NOT NULL,
  action_text TEXT NOT NULL,
  source_observations TEXT,      -- JSON array
  hit_count INTEGER DEFAULT 0,
  disputed_count INTEGER DEFAULT 0,
  last_triggered TEXT,
  created TEXT NOT NULL,
  tags TEXT DEFAULT '[]'
);

-- Claims (replaces signals/claims/*.lock)
CREATE TABLE IF NOT EXISTS claims (
  signal_id TEXT NOT NULL,
  operation TEXT NOT NULL,       -- work|audit|review
  owner TEXT NOT NULL,
  base_commit TEXT,
  claimed_at TEXT NOT NULL,
  ttl_hours INTEGER DEFAULT 24,
  PRIMARY KEY (signal_id, operation)
);

-- Pheromone history (replaces .pheromone last-writer-wins)
CREATE TABLE IF NOT EXISTS pheromone_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  agent_id TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  caste TEXT NOT NULL,
  branch TEXT,
  commit_hash TEXT,
  completed TEXT,
  unresolved TEXT,
  predecessor_useful INTEGER,   -- 0=false, 1=true, NULL=not evaluated
  wip_status TEXT,
  active_signal_count INTEGER
);
CREATE INDEX IF NOT EXISTS idx_ph_timestamp ON pheromone_history(timestamp DESC);

-- Agent registry (new -- per-agent tracking)
CREATE TABLE IF NOT EXISTS agents (
  agent_id TEXT PRIMARY KEY,     -- termite-{epoch}-{pid}
  caste TEXT,
  registered_at TEXT NOT NULL,
  last_heartbeat TEXT,
  session_status TEXT DEFAULT 'active'  -- active|completed|abandoned
);

-- Colony state (replaces .field-breath single-writer)
CREATE TABLE IF NOT EXISTS colony_state (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- Archive (replaces signals/archive/ directory tree)
CREATE TABLE IF NOT EXISTS archive (
  original_id TEXT NOT NULL,
  original_table TEXT NOT NULL,  -- signals|observations|rules
  data TEXT NOT NULL,            -- JSON blob of original row
  archived_at TEXT NOT NULL,
  archive_reason TEXT            -- done|decayed|promoted|merged|rule_expired
);
CREATE INDEX IF NOT EXISTS idx_archive_table ON archive(original_table);
