-- Migration: categories + ratings
-- Run in order

ALTER TABLE store_apps ADD COLUMN category TEXT;

CREATE TABLE IF NOT EXISTS store_ratings (
  package_name TEXT PRIMARY KEY,
  rating_sum   INTEGER NOT NULL DEFAULT 0,
  rating_count INTEGER NOT NULL DEFAULT 0,
  updated_at   INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS store_rating_tokens (
  hashed_token TEXT NOT NULL,
  package_name TEXT NOT NULL,
  rated_at     INTEGER NOT NULL,
  PRIMARY KEY (hashed_token, package_name)
);

CREATE TABLE IF NOT EXISTS store_rating_rate_limits (
  key        TEXT PRIMARY KEY,
  count      INTEGER NOT NULL DEFAULT 0,
  expires_at INTEGER NOT NULL
);
