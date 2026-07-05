import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildChapter } from "../src/build.js";
import { validateCanonical } from "../src/validate.js";

const SOURCE_DIR = fileURLToPath(
  new URL("../fixtures/sample-chapter", import.meta.url),
);
const CANONICAL_DIR = fileURLToPath(
  new URL("../fixtures/canonical/sample-chapter", import.meta.url),
);

test("committed canonical fixture passes validation", async () => {
  assert.deepEqual(await validateCanonical(CANONICAL_DIR), []);
});

test("committed canonical fixture has the shape lanes B/D rely on", async () => {
  const canonical = JSON.parse(
    await readFile(path.join(CANONICAL_DIR, "chapter.json"), "utf8"),
  );
  assert.equal(canonical.topics.length, 2);
  assert.equal(canonical.qnas.length, 3);
  assert.equal(canonical.images.length, 1);
});

test("rebuilding the fixture reuses the committed ULIDs", async () => {
  const outDir = await mkdtemp(path.join(tmpdir(), "ingest-refixture-"));
  const rebuilt = await buildChapter(SOURCE_DIR, outDir);
  const committed = JSON.parse(
    await readFile(path.join(CANONICAL_DIR, "chapter.json"), "utf8"),
  );
  assert.equal(rebuilt.chapter.id, committed.chapter.id);
  assert.deepEqual(
    rebuilt.topics.map((t) => t.id),
    committed.topics.map((t) => t.id),
  );
  assert.deepEqual(
    rebuilt.qnas.map((q) => q.id),
    committed.qnas.map((q) => q.id),
  );
  assert.deepEqual(
    rebuilt.images.map((i) => i.id),
    committed.images.map((i) => i.id),
  );
});
