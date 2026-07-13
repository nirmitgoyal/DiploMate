# corpus - Bedrock answer generation for 26 DNB specialities

Reads PYQ PDFs from Qs/, generates Haiku 4.5 answers on Bedrock, publishes to
a new Heroku Postgres. Idempotent, resumable, hard cost cap.

## Env

- AWS_BEARER_TOKEN_BEDROCK (required; from ~/.zshrc, never committed)
- AWS_REGION (default us-east-1)
- BEDROCK_MODEL_ID (default us.anthropic.claude-haiku-4-5-20251001-v1:0)
- DATABASE_URL (the new Heroku Postgres)
- RATE_IN / RATE_OUT ($/1M tokens; default 1 / 5)

## Run

node src/run.js --canary-paper "<path-to-one.pdf>" # prove the Bedrock path
node src/run.js --speciality anaesthesiology # one speciality
node src/run.js --all --ceiling 90 # remaining, meter-gated

## Throughput

Default `--concurrency 1` (serial). The Bedrock on-demand Haiku tokens/min cap
throttles hard above it - a run at 4 lost ~25-30% of calls to 429 and starved
chapter grouping; serial stays under the cap (651 published / 13 flagged, 60
chapters, ~$6 for anaesthesiology). The full 26 specialities run ~8-9 hours at
concurrency 1, but the run is resumable + idempotent - re-run the same command to
continue after a stop and to retry any flagged questions. Raise `--concurrency`
only after obtaining a higher Bedrock Haiku quota.
