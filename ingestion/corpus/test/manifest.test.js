import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, copyFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildManifest } from "../src/manifest.js";

const FIXTURE = fileURLToPath(
  new URL("../../generator/fixtures/sample-paper.pdf", import.meta.url),
);

async function seedPaper(root, slug, year) {
  const dir = path.join(root, slug, year);
  await mkdir(dir, { recursive: true });
  await copyFile(FIXTURE, path.join(dir, "paper.pdf"));
}

test("buildManifest extracts and dedups questions per speciality", async (t) => {
  const root = await mkdtemp(path.join(tmpdir(), "corpus-qs-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  await seedPaper(root, "anatomy", "2020");

  const manifest = await buildManifest(root, ["anatomy"]);
  const rows = manifest.get("anatomy");
  assert.ok(rows.length >= 1, "at least one question extracted");
  assert.match(rows[0].key, /^[0-9a-f]{16}$/);
  assert.equal(rows[0].speciality_slug, "anatomy");
  assert.ok(rows[0].question.length > 0);
});

test("dedup collapses identical papers and dedups the years Set", async (t) => {
  const single = await mkdtemp(path.join(tmpdir(), "corpus-single-"));
  const dual = await mkdtemp(path.join(tmpdir(), "corpus-dual-"));
  t.after(() =>
    Promise.all([
      rm(single, { recursive: true, force: true }),
      rm(dual, { recursive: true, force: true }),
    ]),
  );

  await seedPaper(single, "anatomy", "2019");
  await seedPaper(dual, "anatomy", "2019");
  await seedPaper(dual, "anatomy", "2021");

  const singleRows = (await buildManifest(single, ["anatomy"])).get("anatomy");
  const dualRows = (await buildManifest(dual, ["anatomy"])).get("anatomy");

  // Two byte-identical papers must collapse to the single-paper row count -
  // a regression here means double Bedrock generation downstream.
  assert.equal(dualRows.length, singleRows.length);

  // The extractor stamps year from the PDF's own provenance (2021), not the
  // directory name, so both copies carry 2021; the years Set dedups to one
  // and joins to the single stamped year.
  assert.equal(dualRows[0].years, "2021");
});

test("buildManifest tolerates a missing speciality directory", async (t) => {
  const root = await mkdtemp(path.join(tmpdir(), "corpus-empty-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const manifest = await buildManifest(root, ["nonexistent-slug"]);
  assert.deepEqual(manifest.get("nonexistent-slug"), []);
});
