CREATE TABLE IF NOT EXISTS store_apps (
  id TEXT PRIMARY KEY,
  developer_id TEXT NOT NULL,
  package_name TEXT NOT NULL,
  name TEXT NOT NULL,
  summary TEXT,
  description TEXT,
  repo_url TEXT NOT NULL,
  repo_token TEXT,
  repo_verified INTEGER NOT NULL DEFAULT 0,
  signing_key_hash TEXT,
  trust_level TEXT NOT NULL DEFAULT 'verified_source',
  status TEXT NOT NULL DEFAULT 'active',
  icon_key TEXT,
  screenshots_json TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  UNIQUE(package_name)
);

CREATE INDEX IF NOT EXISTS idx_store_apps_developer_id ON store_apps(developer_id);
CREATE INDEX IF NOT EXISTS idx_store_apps_status ON store_apps(status);

CREATE TABLE IF NOT EXISTS store_submissions (
  id TEXT PRIMARY KEY,
  app_id TEXT NOT NULL,
  developer_id TEXT NOT NULL,
  package_name TEXT NOT NULL,
  version_name TEXT NOT NULL,
  version_code INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending_upload',
  staging_key TEXT,
  apk_key TEXT,
  apk_size INTEGER,
  apk_sha256 TEXT,
  scan_result TEXT,
  scan_passed INTEGER,
  scanned_at INTEGER,
  review_after INTEGER,
  reviewed_by TEXT,
  rejection_reason TEXT,
  submitted_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  UNIQUE(app_id, version_code),
  FOREIGN KEY (app_id) REFERENCES store_apps(id)
);

CREATE INDEX IF NOT EXISTS idx_store_submissions_app_id ON store_submissions(app_id);
CREATE INDEX IF NOT EXISTS idx_store_submissions_developer_id ON store_submissions(developer_id);
CREATE INDEX IF NOT EXISTS idx_store_submissions_status ON store_submissions(status);
CREATE INDEX IF NOT EXISTS idx_store_submissions_review_after ON store_submissions(review_after);