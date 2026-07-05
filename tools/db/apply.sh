#!/usr/bin/env bash
# Applies sql/*.sql to $DATABASE_URL in filename order.
# Migrations are append-only; prod uses `heroku pg:psql < sql/NNNN_*.sql`.
set -euo pipefail
: "${DATABASE_URL:?DATABASE_URL must be set}"
SQL_DIR="$(cd "$(dirname "$0")/../../sql" && pwd)"
for f in "$SQL_DIR"/[0-9]*.sql; do
  echo "applying $(basename "$f")"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$f"
done
