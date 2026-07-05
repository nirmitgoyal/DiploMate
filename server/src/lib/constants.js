// Wire enums are OWNED by sql/0003_users_events.sql CHECK constraints -
// these mirrors exist for readability only; never validate against them.
const RATINGS = ["again", "hard", "good"];
const EVENT_TYPES = [
  "topic_opened",
  "recall_shown",
  "recall_revealed",
  "recall_rated",
  "session_start",
];
const PAGE_SIZE = 50;

module.exports = { RATINGS, EVENT_TYPES, PAGE_SIZE };
