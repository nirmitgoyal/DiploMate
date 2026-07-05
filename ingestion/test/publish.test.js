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
              (SELECT count(*) FROM topics)::int AS topics,
              (SELECT count(*) FROM qnas)::int AS qnas,
              (SELECT count(*) FROM images)::int AS images`,
          )
        ).rows[0];
      assert.deepEqual(await counts(), {
        chapters: 1,
        topics: 2,
        qnas: 3,
        images: 1,
      });

      const spec = await client.query("SELECT speciality_id FROM chapters");
      assert.equal(spec.rows[0].speciality_id, TEST_SPECIALITY_ID);

      const second = await publishChapter(client, FIXTURE);
      assert.equal(second.contentVersion, 2);
      assert.deepEqual(await counts(), {
        chapters: 1,
        topics: 2,
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
