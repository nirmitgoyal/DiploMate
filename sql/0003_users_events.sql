-- 0003: users, entitlements, event log, bookmarks, reports (lane C).
-- Wire enums live HERE as CHECK constraints (D7 addendum / Issue 5A).
-- The API maps violations to 400 {constraint}; it never re-validates.

CREATE TABLE users (
  id                      TEXT PRIMARY KEY,
  google_sub              TEXT NOT NULL UNIQUE,
  email                   TEXT NOT NULL,
  name                    TEXT,
  photo_url               TEXT,
  speciality_id           TEXT REFERENCES specialities(id),
  speciality_change_count INTEGER NOT NULL DEFAULT 0,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE entitlements (
  user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  speciality_id TEXT NOT NULL REFERENCES specialities(id),
  granted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, speciality_id)
);

CREATE TABLE review_events (
  id          UUID PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content_id  TEXT NOT NULL,
  rating      TEXT NOT NULL CONSTRAINT review_events_rating_check
              CHECK (rating IN ('again','hard','good')),
  shown_at    TIMESTAMPTZ NOT NULL,
  revealed_at TIMESTAMPTZ NOT NULL,
  rated_at    TIMESTAMPTZ NOT NULL,
  local_day   DATE NOT NULL,
  synced_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT review_events_order_check
    CHECK (shown_at <= revealed_at AND revealed_at <= rated_at)
);
CREATE INDEX review_events_user_day ON review_events (user_id, local_day);

CREATE TABLE app_events (
  id          UUID PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_type  TEXT NOT NULL CONSTRAINT app_events_event_type_check
              CHECK (event_type IN ('topic_opened','recall_shown','recall_revealed',
                                    'recall_rated','session_start')),
  content_id  TEXT,
  hidden_ms   INTEGER,
  occurred_at TIMESTAMPTZ NOT NULL,
  local_day   DATE NOT NULL,
  synced_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX app_events_user_day ON app_events (user_id, local_day);

CREATE TABLE bookmarks (
  user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content_id TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  deleted    BOOLEAN NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, content_id)
);

CREATE TABLE reports (
  id         UUID PRIMARY KEY,
  user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  qna_id     TEXT NOT NULL,
  message    TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
