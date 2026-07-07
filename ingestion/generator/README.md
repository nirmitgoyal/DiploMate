# ingestion/generator

Offline content generator (Stage 0-4): turns exam PDFs + Miller's Anesthesia
into a graded, verbatim-cited answer corpus. Dev/offline-only - it is never
imported by `build.js`, `validate.js`, or `publish.js`, and this package
NEVER commits reference-book (Miller) text. Miller-derived output, once
later stages produce it, lives only in the gitignored `ingestion/holding/`.

This package currently provides Stage 0's page index: one entry per PDF
page, read from the PDF's text layer via `pdftotext` (poppler-utils - must
be on PATH). No new runtime dependency; only `node:child_process`.

## Run the tests

From `ingestion/`:

    node --test generator/test/page_index.test.js

## Fixtures

`fixtures/sample-2page.pdf` is synthetic, owned text ("owned sample page
one" / "owned sample page two") - never Miller content. Regenerate it with:

    node generator/fixtures/make-sample.js
