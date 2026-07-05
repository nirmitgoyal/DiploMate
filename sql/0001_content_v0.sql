-- 0001_content_v0.sql - day-1 v0 content DDL, the A/B/C lane contract (T20).
-- Append-only: never edit this file after it ships; amend via a NEW numbered
-- migration. Wire enums live here as named CHECK constraints (D7/5A); the API
-- maps violations to HTTP 400 with the constraint name.
-- IDs are ULIDs (26-char Crockford base32 TEXT) minted by the ingestion
-- pipeline - opaque identity; slugs/titles are mutable path metadata (A4).

CREATE TABLE app_config (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
INSERT INTO app_config (key, value) VALUES ('beta_active', 'true');

CREATE TABLE specialities (
  id         TEXT PRIMARY KEY,
  name       TEXT NOT NULL,
  exam_type  TEXT NOT NULL CONSTRAINT specialities_exam_type_check
             CHECK (exam_type IN ('DNB','DrNB')),
  slug       TEXT NOT NULL UNIQUE,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE chapters (
  id              TEXT PRIMARY KEY,
  speciality_id   TEXT NOT NULL REFERENCES specialities(id),
  title           TEXT NOT NULL,
  slug            TEXT NOT NULL,
  sort_order      INTEGER NOT NULL DEFAULT 0,
  exam_weight     INTEGER NOT NULL DEFAULT 0,
  content_version INTEGER NOT NULL DEFAULT 0,   -- bumped by publisher; cache invalidation
  UNIQUE (speciality_id, slug)
);

CREATE TABLE topics (
  id         TEXT PRIMARY KEY,
  chapter_id TEXT NOT NULL REFERENCES chapters(id),
  title      TEXT NOT NULL,
  slug       TEXT NOT NULL,
  exam_theme TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  UNIQUE (chapter_id, slug)
);

CREATE TABLE qnas (
  id          TEXT PRIMARY KEY,
  topic_id    TEXT NOT NULL REFERENCES topics(id),
  question    TEXT NOT NULL,
  years       TEXT,                -- e.g. '2019, 2022' (PYQ appearances)
  marks       INTEGER,
  earns_marks JSONB NOT NULL DEFAULT '[]',
    -- [{"label": "...", "section_key": "definition"}] - anchor links to sections
  sections    JSONB NOT NULL,
    -- [{"key": "definition", "heading": "Definition", "body_md": "..."}]
    -- D16 schema coupling: section structure encoded from the first spike
  sort_order  INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE images (
  id                  TEXT PRIMARY KEY,
  qna_id              TEXT NOT NULL REFERENCES qnas(id),
  caption             TEXT NOT NULL,
  content_description TEXT NOT NULL,   -- TalkBack description (D20)
  webp                BYTEA NOT NULL,
  byte_size           INTEGER NOT NULL CONSTRAINT images_byte_size_check
                      CHECK (byte_size <= 204800),
  sha256              TEXT NOT NULL,   -- ETag for HTTP caching
  sort_order          INTEGER NOT NULL DEFAULT 0
);
