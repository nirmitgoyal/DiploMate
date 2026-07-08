# Content Pass: Book-Grounded Answer Generation + Topics Removal (Anaesthesiology)

Four-lane implementation of the eng-review-approved content pass (design doc
`~/.gstack/projects/nirmitgoyal-DiploMate/nirmit-claude-jolly-banach-f5aef8-design-20260706-134407.md`,
VERDICT: CLEARED). This README is the map; each lane is its own executable plan.

## The four plans

| Lane                 | Plan file                                                                                | Modules                                                                 | Eng-review tasks                                                        |
| -------------------- | ---------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| A: sql + server      | [2026-07-06-content-pass-sql-server.md](2026-07-06-content-pass-sql-server.md)           | `sql/`, `sql/metrics/`, `server/`, `tools/db/`                          | T4, T5, T8, T11, T6 (server half), T10 (server/sql slices)              |
| B: ingestion         | [2026-07-06-content-pass-ingestion.md](2026-07-06-content-pass-ingestion.md)             | `ingestion/src`, `ingestion/test`, `ingestion/fixtures`, `AUTHORING.md` | T1, T2, T6 (ingestion half), T10 (ingestion slices)                     |
| C: app               | [2026-07-06-content-pass-app.md](2026-07-06-content-pass-app.md)                         | `app/lib`, `app/test`, `DESIGN.md`                                      | T4 (app half), T6 (drift knob), T11 (app half), T10 (app slices)        |
| D: pilot + generator | [2026-07-06-content-pass-pilot-generator.md](2026-07-06-content-pass-pilot-generator.md) | `ingestion/generator` (new), `TODOS.md`, holding area                   | T0 pilot, T3, T7, T9, T12, T13, T14, T15, T16, T17, T18, T10 (EVAL+E2E) |

Sweep criterion T19 is enforced as a per-lane step in A/B/C (identifier-level
grep). The version-knob cutover T6 spans all three code lanes and is called out
in each.

## Execution order (worktree parallelization, design doc table)

Per superpowers:using-git-worktrees. Launch A + B + C in parallel worktrees;
merge; then D.

```
Hand pilot (Lane D Task 0) ........ runs FIRST / alongside, NO code. Gates Lane D Task 6+.
                                     License + quote-terms already answered (see below);
                                     record them here. Pilot GO is the only open gate.
   |
   +-- Lane A (sql -> server) ......\
   +-- Lane B (ingestion) ..........  parallel worktrees; land Lane A Task 1
   +-- Lane C (app) ................./  (0004 file) before B's publish tests
   |
   merge A + B + C
   |
   +-- Lane D (generator) .......... same ingestion/ package as B - NOT a
                                      parallel worktree with B. Needs Lane B
                                      merged + pilot GO (license + quote terms
                                      already cleared 2026-07-06).
```

- Lane B's publish integration tests need `sql/0004_drop_topics.sql` - land Lane A Task 1 first, or share the file into B's worktree.
- Lane C depends only on the WRITTEN v2 wire contract (in every plan's Global Constraints), not on Lane A code - fully parallel.
- Lane D extends Lane B's `ingestion/` package; do not run B and D in parallel worktrees.

## Hard constraints (carried in every plan's Global Constraints)

1. **Publish stays blocked until `LICENSE_SIGNED=true`.** `gateCheck` in [ingestion/src/publish.js](ingestion/src/publish.js) is never weakened, in Lane B or Lane D. Integration tests that set `LICENSE_SIGNED=true` in their own env EXERCISE the gate; they do not bypass it. (License SIGNED by founder 2026-07-06 - the env var is now legitimate at the real publish step; the code gate is unchanged.)
2. **Hand pilot precedes generator answer code.** Lane D Task 0 (no code) gates Lane D Task 6 (Stage 3) and Task 10 (at-scale).
3. **Quote-length written terms are a Stage-3-at-scale precondition** (amendment 12) - **RESOLVED: no cap** (founder, 2026-07-06). Lane D Task 6 still refuses `--scale` without the `QUOTE_TERMS` marker (safety interlock); set `QUOTE_TERMS=no-cap`. Per-answer verbatim word count recorded regardless.
4. **Migrations are append-only.** All schema change is in the new `sql/0004_drop_topics.sql` (Lane A Task 1); `0001`/`0002`/`0003` untouched.
5. **TDD, and the four rewrites ship WITH regression tests** (IRON RULE): `validate.js` (Lane B Task 3), `publish.js` (Lane B Task 4), app nav (Lane C Tasks 5+6), metrics/events (Lane A Tasks 4+5, Lane C Task 6). Each names its regression suite explicitly.
6. **All generated content uses `speciality_slug` `anaesthesiology`** (the `anaesthesia` bug at `AUTHORING.md:77` is fixed by Lane B Task 2).

## Amendment cross-reference (the 16 that supersede the doc body)

| #   | What it changes                                                                           | Landed in                                                 |
| --- | ----------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| 1   | Speciality-level ids.lock; moves keep ULID; batch republish                               | B Task 2, B Task 4                                        |
| 2   | Provenance-first ledger reconciliation (hash mints only)                                  | D Task 4                                                  |
| 3   | De-brand amendment + gitignored holding area + slug fix                                   | B Task 5, D Task 0/6/10                                   |
| 4   | Event renamed `chapter_opened` NOW; CHECK widened                                         | A Task 1/4/5, C Task 6                                    |
| 5   | Verifier page-boundary + fidelity rules; page-image spot-check                            | D Task 5                                                  |
| 6   | Citation chain: per-volume monotonic map, physical-page confirm                           | D Task 2, D Task 0                                        |
| 7   | Stage 1 OCR gate + per-paper QA                                                           | D Task 3                                                  |
| 8   | `exam_weight` = year-appearance count                                                     | D Task 4                                                  |
| 9   | 0004 indexes + sort_order renumber + CHECK widening                                       | A Task 1                                                  |
| 10  | Version-knob cutover table (4 knobs)                                                      | A Task 2/3 (wire), B Task 3 (canonical), C Task 2 (drift) |
| 11  | Stage 0 slug sanitize/dedupe/precheck                                                     | D Task 7                                                  |
| 12  | Quote-length terms = at-scale precondition + word-count metadata                          | D Task 6, D Task 0                                        |
| 13  | Expanded pilot scorecard (random slice, quality read, throughput, bytes, own-words hedge) | D Task 0                                                  |
| 14  | Identifier-level sweep criterion                                                          | A/B/C final steps, D content strings                      |
| 15  | Deploy choreography + drift cache semantics                                               | A Task 1 header, C Task 2                                 |
| 16  | Test pack (16 gaps + 4 regressions + 2 E2E + 1 EVAL)                                      | across all lanes; see below                               |

## Test pack (T10 / amendment 16) placement

| Test-plan item                                                                         | Landed in                                                                          |
| -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| validate v2 regression (rejects v1/topics/chapter_id mismatch/empty)                   | B Task 3                                                                           |
| publish regression (chapter_id deletes, move-batch no-orphan, authoritative republish) | B Task 4                                                                           |
| app nav regression (topics level gone, syllabus->reader)                               | C Tasks 5, 6                                                                       |
| metrics regression (valid_recall chapter grain, chapter_opened fires)                  | A Task 4, C Task 6                                                                 |
| migration 0004 correctness (backfill, renumber, indexes, NOT NULL)                     | A Task 1                                                                           |
| speciality-ledger zero-churn + cross-chapter-move identity                             | B Task 2, B Task 4                                                                 |
| verifier normalization catalog (hyphenation, soft hyphen, interleave, cross-page)      | D Task 5                                                                           |
| drift v2->v3 state survival                                                            | C Task 2                                                                           |
| empty-chapter filter                                                                   | A Task 3                                                                           |
| MIN_APP_VERSION upgrade gate                                                           | A Task 3 (wire), C Task 4 (client)                                                 |
| E2E: full study loop on generated content (signup->chapter->valid recall->metrics)     | A Task 5 (server half), C Task 6 (app half), D Task 10 (generated-content variant) |
| E2E: publish pipeline dry run (generator->build->validate->publish->serve->parse)      | D Task 10                                                                          |
| EVAL: Stage 2 classification vs pilot ground truth                                     | D Task 9                                                                           |

## Out of scope (explicitly deferred - TODOS.md 5/8/9)

Embedding retrieval index (TODOS 8, trigger: pilot retrieval-miss share);
figure-crop batch review UI (TODOS 9, trigger: pilot figure-review-time
projection); R2/S3 image migration (TODOS 5, trigger: Essential-0 1GB
projection). Lane D Task 0 MEASURES the triggers and records them in TODOS;
building any of the three is NOT in these plans.
