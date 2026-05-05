ALTER TABLE users ADD COLUMN developer_enabled INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN developer_terms_accepted_at INTEGER;
ALTER TABLE store_apps ADD COLUMN claimed         INTEGER NOT NULL DEFAULT 0;
ALTER TABLE store_apps ADD COLUMN auto_tracked    INTEGER NOT NULL DEFAULT 0;
ALTER TABLE store_apps ADD COLUMN last_repo_check INTEGER;
ALTER TABLE store_apps ADD COLUMN signing_flag    TEXT;
ALTER TABLE store_submissions ADD COLUMN signing_key_hash TEXT;
ALTER TABLE store_submissions ADD COLUMN engine_result    TEXT;

INSERT OR IGNORE INTO users (
  id,
  email,
  plan,
  unlimited,
  simultaneous_limit,
  cap_gb,
  active,
  created_at,
  developer_enabled,
  developer_terms_accepted_at
) VALUES (
  'safehaven-community',
  'safehaven-community@colourswift.local',
  'system',
  0,
  1,
  0,
  1,
  unixepoch(),
  0,
  NULL
);