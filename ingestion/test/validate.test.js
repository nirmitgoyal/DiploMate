import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { createHash } from "node:crypto";
import { ulid } from "ulid";
import sharp from "sharp";
import { validateCanonical } from "../src/validate.js";

async function smallWebp(width = 400, height = 300) {
  return sharp({
    create: {
      width,
      height,
      channels: 3,
      background: { r: 214, g: 234, b: 236 },
    },
  })
    .webp({ quality: 80 })
    .toBuffer();
}

async function validCanonical() {
  const chapterId = ulid();
  const topicId = ulid();
  const qnaId = ulid();
  const imageId = ulid();
  const webp = await smallWebp();
  return {
    canonical: {
      schema_version: 1,
      speciality_slug: "anaesthesia",
      chapter: {
        id: chapterId,
        title: "Chapter",
        slug: "chapter",
        sort_order: 1,
        exam_weight: 10,
      },
      topics: [
        {
          id: topicId,
          chapter_id: chapterId,
          title: "Topic",
          slug: "topic",
          exam_theme: null,
          sort_order: 1,
        },
      ],
      qnas: [
        {
          id: qnaId,
          topic_id: topicId,
          question: "Q?",
          years: "2022",
          marks: 10,
          earns_marks: [{ label: "Point", section_key: "definition" }],
          sections: [
            { key: "definition", heading: "Definition", body_md: "Body." },
          ],
          sort_order: 1,
        },
      ],
      images: [
        {
          id: imageId,
          qna_id: qnaId,
          caption: "Caption",
          content_description: "Description for TalkBack.",
          file: `images/${imageId}.webp`,
          byte_size: webp.length,
          sha256: createHash("sha256").update(webp).digest("hex"),
          sort_order: 1,
        },
      ],
    },
    files: { [`images/${imageId}.webp`]: webp },
  };
}

async function writeCanonicalDir({ canonical, files }) {
  const dir = await mkdtemp(path.join(tmpdir(), "ingest-canon-"));
  await mkdir(path.join(dir, "images"), { recursive: true });
  await writeFile(
    path.join(dir, "chapter.json"),
    JSON.stringify(canonical, null, 2),
  );
  for (const [rel, bytes] of Object.entries(files)) {
    await writeFile(path.join(dir, rel), bytes);
  }
  return dir;
}

test("a valid canonical dir returns zero errors", async () => {
  const dir = await writeCanonicalDir(await validCanonical());
  assert.deepEqual(await validateCanonical(dir), []);
});

test("earns_marks pointing at a missing section key is exact-messaged", async () => {
  const c = await validCanonical();
  c.canonical.qnas[0].earns_marks[0].section_key = "technique";
  const dir = await writeCanonicalDir(c);
  assert.deepEqual(await validateCanonical(dir), [
    'qnas[0].earns_marks[0].section_key: "technique" does not match any sections[].key',
  ]);
});

test("empty sections array is rejected (D16 coupling)", async () => {
  const c = await validCanonical();
  c.canonical.qnas[0].sections = [];
  c.canonical.qnas[0].earns_marks = [];
  const dir = await writeCanonicalDir(c);
  assert.deepEqual(await validateCanonical(dir), [
    "qnas[0].sections: must be a non-empty array",
  ]);
});

test("bad slug is exact-messaged", async () => {
  const c = await validCanonical();
  c.canonical.chapter.slug = "Bad Slug";
  const dir = await writeCanonicalDir(c);
  assert.deepEqual(await validateCanonical(dir), [
    'chapter.slug: "Bad Slug" is not a valid slug',
  ]);
});

test("non-ULID id is exact-messaged", async () => {
  const c = await validCanonical();
  c.canonical.topics[0].id = "not-a-ulid";
  const dir = await writeCanonicalDir(c);
  const errors = await validateCanonical(dir);
  assert.ok(
    errors.includes('topics[0].id: "not-a-ulid" is not a ULID'),
    errors.join("\n"),
  );
});

test("missing content_description is rejected (D20)", async () => {
  const c = await validCanonical();
  c.canonical.images[0].content_description = "";
  const dir = await writeCanonicalDir(c);
  assert.deepEqual(await validateCanonical(dir), [
    "images[0].content_description: missing or empty",
  ]);
});

test("a non-WebP image file is rejected", async () => {
  const c = await validCanonical();
  const png = await sharp({
    create: {
      width: 40,
      height: 30,
      channels: 3,
      background: { r: 0, g: 0, b: 0 },
    },
  })
    .png()
    .toBuffer();
  const rel = c.canonical.images[0].file;
  c.files[rel] = png;
  c.canonical.images[0].byte_size = png.length;
  c.canonical.images[0].sha256 = createHash("sha256").update(png).digest("hex");
  const dir = await writeCanonicalDir(c);
  assert.deepEqual(await validateCanonical(dir), [
    "images[0]: not a WebP file",
  ]);
});

test("byte_size mismatch and stale sha256 are both reported", async () => {
  const c = await validCanonical();
  c.canonical.images[0].byte_size = c.canonical.images[0].byte_size + 1;
  c.canonical.images[0].sha256 = "deadbeef";
  const trueSize = c.files[c.canonical.images[0].file].length;
  const dir = await writeCanonicalDir(c);
  assert.deepEqual(await validateCanonical(dir), [
    `images[0].byte_size: ${trueSize + 1} does not match file size ${trueSize}`,
    "images[0].sha256: does not match file contents",
  ]);
});

test("missing image file is exact-messaged", async () => {
  const c = await validCanonical();
  const rel = c.canonical.images[0].file;
  delete c.files[rel];
  const dir = await writeCanonicalDir(c);
  assert.deepEqual(await validateCanonical(dir), [
    `images[0].file: ${rel} not found`,
  ]);
});

test("oversize image is rejected with the 204800 cap named", async () => {
  const c = await validCanonical();
  // 1500x1500 photographic-noise WebP at quality 95 lands well over 200KB while staying under the edge cap.
  const { randomBytes } = await import("node:crypto");
  const big = await sharp(randomBytes(1500 * 1500 * 3), {
    raw: { width: 1500, height: 1500, channels: 3 },
  })
    .webp({ quality: 95 })
    .toBuffer();
  const rel = c.canonical.images[0].file;
  c.files[rel] = big;
  c.canonical.images[0].byte_size = big.length;
  c.canonical.images[0].sha256 = createHash("sha256").update(big).digest("hex");
  const dir = await writeCanonicalDir(c);
  const errors = await validateCanonical(dir);
  assert.deepEqual(errors, [
    `images[0]: byte_size ${big.length} exceeds 204800`,
  ]);
});

test("image wider than 1600px is rejected", async () => {
  const c = await validCanonical();
  const wide = await smallWebp(1800, 400);
  const rel = c.canonical.images[0].file;
  c.files[rel] = wide;
  c.canonical.images[0].byte_size = wide.length;
  c.canonical.images[0].sha256 = createHash("sha256")
    .update(wide)
    .digest("hex");
  const dir = await writeCanonicalDir(c);
  assert.deepEqual(await validateCanonical(dir), [
    "images[0]: width 1800 exceeds 1600",
  ]);
});
