ALTER TABLE store_apps ADD COLUMN upstream TEXT DEFAULT NULL;

CREATE TABLE IF NOT EXISTS sync_state (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS store_hash_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    app_id TEXT NOT NULL,
    old_hash TEXT,
    new_hash TEXT NOT NULL,
    reason TEXT,
    updated_by TEXT,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY (app_id) REFERENCES store_apps(id)
);

CREATE INDEX IF NOT EXISTS idx_hash_history_app ON store_hash_history(app_id);