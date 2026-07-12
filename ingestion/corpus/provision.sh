#!/usr/bin/env bash
set -euo pipefail
# Heroku CLI is authed as parth.mitblr2023@learner.manipal.edu. Confirm the
# account is intended before running (the new app + Postgres bill to it).
APP="${1:-diplomate-corpus}"

# Resolve the numbered migrations relative to THIS script, not the caller's
# working directory: sql/ lives at the repo root, two levels up from
# ingestion/corpus/, so the run works regardless of where it is invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_DIR="$SCRIPT_DIR/../../sql"

heroku create "$APP"
heroku addons:create heroku-postgresql:essential-0 -a "$APP"
# Wait for the DB to provision, then apply every numbered migration in sorted
# order (same contract as tools/db/apply.sh and test/db.js testClient()). The
# glob picks up a future 000N migration automatically, so the corpus DB never
# drifts from the app schema.
for f in "$SQL_DIR"/[0-9][0-9][0-9][0-9]_*.sql; do
  echo "applying $f"
  heroku pg:psql -a "$APP" < "$f"
done
heroku config:get DATABASE_URL -a "$APP"
echo "Export this DATABASE_URL for run.js."
