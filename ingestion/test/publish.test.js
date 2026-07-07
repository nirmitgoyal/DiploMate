import { test } from "node:test";
import assert from "node:assert/strict";
import {
  mkdtemp,
  mkdir,
  readFile,
  writeFile,
  copyFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { gateCheck, publishChapter } from "../src/publish.js";
import { testClient, TEST_SPECIALITY_ID } from "./db.js";

const FIXTURE = fileURLToPath(
  new URL("../fixtures/canonical/sample-chapter", import.meta.url),
);
const DB = process.env.DATABASE_URL;
const skipDb = !DB && "set DATABASE_URL to run publish integration tests";

test("gate refuses without --allow-publish", () => {
  assert.equal(
    gateCheck([], { LICENSE_SIGNED: "true" }),
    "publish refused: pass --allow-publish (publishing is PG1-gated)",
  );
});

test("gate refuses without LICENSE_SIGNED=true even with the flag", () => {
  assert.equal(
    gateCheck(["--allow-publish"], {}),
    "publish refused: set LICENSE_SIGNED=true (content term sheet unsigned - publishing stays PG1-gated)",
  );
});

test("gate passes with flag and env together", () => {
  assert.equal(
    gateCheck(["--allow-publish"], { LICENSE_SIGNED: "true" }),
    null,
  );
});

test("publish rejects an invalid canonical dir before touching the database", async () => {
  const dir = await mkdtemp(path.join(tmpdir(), "ingest-bad-"));
  await writeFile(path.join(dir, "chapter.json"), "{not json");
  // client = null proves validation runs before any query is issued.
  await assert.rejects(() => publishChapter(null, dir), /validation failed/);
});

async function copyCanonical(mutate) {
  const dir = await mkdtemp(path.join(tmpdir(), "ingest-pub-"));
  await mkdir(path.join(dir, "images"), { recursive: true });
  const canonical = JSON.parse(
    await readFile(path.join(FIXTURE, "chapter.json"), "utf8"),
  );
  const result = mutate ? mutate(canonical) : undefined;
  await writeFile(
    path.join(dir, "chapter.json"),
    JSON.stringify(canonical, null, 2),
  );
  for (const img of canonical.images) {
    await copyFile(path.join(FIXTURE, img.file), path.join(dir, img.file));
  }
  return { dir, canonical, result };
}

test(
  "publish inserts the fixture and bumps content_version; republish is idempotent",
  { skip: skipDb },
  async () => {
    const client = await testClient();
    try {
      const first = await publishChapter(client, FIXTURE);
      assert.equal(first.contentVersion, 1);

      const counts = async () =>
        (
          await client.query(
            `SELECT (SELECT count(*) FROM chapters)::int AS chapters,
              (SELECT count(*) FROM qnas)::int AS qnas,
              (SELECT count(*) FROM images)::int AS images`,
          )
        ).rows[0];
      assert.deepEqual(await counts(), {
        chapters: 1,
        qnas: 3,
        images: 1,
      });

      const spec = await client.query("SELECT speciality_id FROM chapters");
      assert.equal(spec.rows[0].speciality_id, TEST_SPECIALITY_ID);

      const second = await publishChapter(client, FIXTURE);
      assert.equal(second.contentVersion, 2);
      assert.deepEqual(await counts(), {
        chapters: 1,
        qnas: 3,
        images: 1,
      });

      const img = await client.query(
        "SELECT octet_length(webp) AS len, byte_size, sha256 FROM images",
      );
      assert.equal(img.rows[0].len, img.rows[0].byte_size);
      assert.match(img.rows[0].sha256, /^[0-9a-f]{64}$/);
    } finally {
      await client.end();
    }
  },
);

test(
  "republish removes rows dropped from the canonical set",
  { skip: skipDb },
  async () => {
    const client = await testClient();
    try {
      await publishChapter(client, FIXTURE);
      const { dir, result: droppedId } = await copyCanonical((canonical) => {
        const dropped = canonical.qnas.pop(); // pdph qna - has no images
        return dropped.id;
      });
      await publishChapter(client, dir);
      const n = await client.query("SELECT count(*)::int AS n FROM qnas");
      assert.equal(n.rows[0].n, 2);
      const gone = await client.query(
        "SELECT count(*)::int AS n FROM qnas WHERE id = $1",
        [droppedId],
      );
      assert.equal(gone.rows[0].n, 0);
    } finally {
      await client.end();
    }
  },
);

test(
  "publish refuses an unknown speciality slug (specialities are seed-owned)",
  { skip: skipDb },
  async () => {
    const client = await testClient();
    try {
      const { dir } = await copyCanonical((canonical) => {
        canonical.speciality_slug = "cardiology";
      });
      await assert.rejects(
        () => publishChapter(client, dir),
        /unknown speciality slug "cardiology" - specialities are seeded by sql\/0002, never created by publish/,
      );
      const n = await client.query("SELECT count(*)::int AS n FROM chapters");
      assert.equal(n.rows[0].n, 0);
    } finally {
      await client.end();
    }
  },
);

function canonicalV2({ chapterKeyId, qnas }) {
  return {
    schema_version: 2,
    speciality_slug: "anaesthesiology",
    chapter: {
      id: chapterKeyId,
      title: `Chapter ${chapterKeyId.slice(-2)}`,
      slug: `chapter-${chapterKeyId.slice(-2).toLowerCase()}`,
      sort_order: 1,
      exam_weight: 1,
    },
    qnas: qnas.map((q, i) => ({
      id: q.id,
      chapter_id: chapterKeyId,
      question: q.question,
      years: null,
      marks: null,
      earns_marks: [],
      sections: [
        { key: "summary", heading: "Summary", body_md: "Owned sample text." },
      ],
      sort_order: i + 1,
    })),
    images: [],
  };
}

async function writeCanonical(canonical) {
  const dir = await mkdtemp(path.join(tmpdir(), "ingest-pub-"));
  await writeFile(
    path.join(dir, "chapter.json"),
    JSON.stringify(canonical, null, 2),
  );
  return dir;
}

const CH_A = "01ARZ3NDEKTSV4RRFFQ69G5CHA";
const CH_B = "01ARZ3NDEKTSV4RRFFQ69G5CHB";
const Q_MOVED = "01ARZ3NDEKTSV4RRFFQ69G5QMV";
const Q_STAYS = "01ARZ3NDEKTSV4RRFFQ69G5QST";

test(
  "REGRESSION: authoritative republish deletes dropped qnas + their images by chapter_id",
  { skip: skipDb },
  async () => {
    const client = await testClient();
    try {
      const two = canonicalV2({
        chapterKeyId: CH_A,
        qnas: [
          { id: Q_STAYS, question: "stays" },
          { id: Q_MOVED, question: "dropped" },
        ],
      });
      await publishChapter(client, await writeCanonical(two));
      await client.query(
        `INSERT INTO images (id, qna_id, caption, content_description, webp, byte_size, sha256, sort_order)
       VALUES ('01ARZ3NDEKTSV4RRFFQ69G5IMG', $1, 'c', 'd', decode('52494646','hex'), 4, 'x', 1)`,
        [Q_MOVED],
      );
      const one = canonicalV2({
        chapterKeyId: CH_A,
        qnas: [{ id: Q_STAYS, question: "stays" }],
      });
      await publishChapter(client, await writeCanonical(one));
      const qnas = await client.query(
        `SELECT id FROM qnas WHERE chapter_id = $1`,
        [CH_A],
      );
      assert.deepEqual(
        qnas.rows.map((r) => r.id),
        [Q_STAYS],
      );
      const images = await client.query(
        `SELECT id FROM images WHERE qna_id = $1`,
        [Q_MOVED],
      );
      assert.equal(
        images.rowCount,
        0,
        "orphaned image must be deleted with its qna",
      );
    } finally {
      await client.end();
    }
  },
);

test(
  "a cross-chapter move keeps the qna ULID in EITHER republish order (amendment 1)",
  { skip: skipDb },
  async () => {
    for (const order of ["source-first", "target-first"]) {
      const client = await testClient(); // fresh schema per order
      try {
        const aWith = canonicalV2({
          chapterKeyId: CH_A,
          qnas: [{ id: Q_MOVED, question: "moving" }],
        });
        const bEmptyPlaceholder = canonicalV2({
          chapterKeyId: CH_B,
          qnas: [{ id: Q_STAYS, question: "anchor" }],
        });
        await publishChapter(client, await writeCanonical(aWith));
        await publishChapter(client, await writeCanonical(bEmptyPlaceholder));

        // The move: q leaves A, joins B - same ULID. A' must still validate, so
        // it keeps a replacement qna (empty chapters never publish).
        const aAfter = canonicalV2({
          chapterKeyId: CH_A,
          qnas: [{ id: "01ARZ3NDEKTSV4RRFFQ69G5QNW", question: "replacement" }],
        });
        const bAfter = canonicalV2({
          chapterKeyId: CH_B,
          qnas: [
            { id: Q_STAYS, question: "anchor" },
            { id: Q_MOVED, question: "moving" },
          ],
        });
        const batch =
          order === "source-first" ? [aAfter, bAfter] : [bAfter, aAfter];
        for (const canonical of batch) {
          await publishChapter(client, await writeCanonical(canonical));
        }
        const moved = await client.query(
          `SELECT chapter_id FROM qnas WHERE id = $1`,
          [Q_MOVED],
        );
        assert.equal(moved.rowCount, 1, `qna row survives the move (${order})`);
        assert.equal(
          moved.rows[0].chapter_id,
          CH_B,
          `qna belongs to the target (${order})`,
        );
      } finally {
        await client.end();
      }
    }
  },
);
