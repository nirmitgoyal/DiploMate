// Wire enums are OWNED by sql/0003 + sql/0004 CHECK constraints - these
// mirrors exist for readability only; never validate against them.
// topic_opened stays in the CHECK for back-compat; the app emits
// chapter_opened from schema v2 on (0004, amendment 4).
const RATINGS = ["again", "hard", "good"];
const EVENT_TYPES = [
  "chapter_opened",
  "topic_opened",
  "recall_shown",
  "recall_revealed",
  "recall_rated",
  "session_start",
];
const PAGE_SIZE = 50;
// Version-knob cutover (amendment 10): wire schema v2 = topics-less shape;
// min_app_version 2 sends stale clients to the upgrade gate, never a parse error.
const SCHEMA_VERSION = 2;
const MIN_APP_VERSION = 2;

module.exports = {
  RATINGS,
  EVENT_TYPES,
  PAGE_SIZE,
  SCHEMA_VERSION,
  MIN_APP_VERSION,
};
