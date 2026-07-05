# sql/ - schema migrations

- Numbered files (0001*..., 0002*...) are the single schema truth.
- Append-only: NEVER edit a shipped migration; amend with a NEW numbered
  file. The T2 ingestion spike AMENDS via new migrations, never redefines.
- Prod apply: `heroku pg:psql < sql/NNNN_name.sql`, in filename order.
- Local/CI apply from zero: `tools/db/apply.sh` (reads `$DATABASE_URL`).
- Wire enums are owned here as named CHECK constraints (D7/5A). The API maps
  a CHECK violation to HTTP 400 `{error: 'constraint_violation',
constraint: '<name>'}` and never re-validates enum membership. Renaming a
  constraint is a wire-contract change.
- Contract tests: `cd tools/db && npm test` (needs a disposable Postgres in
  `$DATABASE_URL` with the migrations applied).
