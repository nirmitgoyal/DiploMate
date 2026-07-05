import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { buildChapter } from "../src/build.js";
import sharp from "sharp";
import { randomBytes, createHash } from "node:crypto";

const ULID_RE = /^[0-9A-HJKMNP-TV-Z]{26}$/;

function sourceChapter() {
  return {
    speciality_slug: "anaesthesia",
    chapter: {
      title: "Sample Chapter",
      slug: "sample-chapter",
      sort_order: 1,
      exam_weight: 10,
    },
    topics: [
      {
        key: "topic-one",
        title: "Topic One",
        slug: "topic-one",
        exam_theme: "Theme one",
        sort_order: 1,
        qnas: [
          {
            key: "q-one",
            question: "Question one?",
            years: "2022",
            marks: 10,
            sort_order: 1,
            earns_marks: [
              { label: "Definition point", section_key: "definition" },
            ],
            sections: [
              {
                key: "definition",
                heading: "Definition",
                body_md: "Body one.",
              },
            ],
            images: [],
          },
        ],
      },
    ],
  };
}

async function makeChapterDir(source) {
  const dir = await mkdtemp(path.join(tmpdir(), "ingest-src-"));
  await mkdir(path.join(dir, "images"), { recursive: true });
  await writeFile(
    path.join(dir, "chapter.json"),
    JSON.stringify(source, null, 2),
  );
  return dir;
}

async function makeOutDir() {
  return mkdtemp(path.join(tmpdir(), "ingest-out-"));
}

test("build mints ULIDs and writes ids.lock", async () => {
  const dir = await makeChapterDir(sourceChapter());
  const canonical = await buildChapter(dir, await makeOutDir());
  assert.match(canonical.chapter.id, ULID_RE);
  assert.match(canonical.topics[0].id, ULID_RE);
  assert.match(canonical.qnas[0].id, ULID_RE);
  assert.equal(canonical.topics[0].chapter_id, canonical.chapter.id);
  assert.equal(canonical.qnas[0].topic_id, canonical.topics[0].id);
  const lock = JSON.parse(await readFile(path.join(dir, "ids.lock"), "utf8"));
  assert.equal(lock.chapter, canonical.chapter.id);
  assert.equal(lock.topics["topic-one"], canonical.topics[0].id);
  assert.equal(lock.qnas["q-one"], canonical.qnas[0].id);
});

test("rebuild reuses locked ids (stable across rebuilds)", async () => {
  const dir = await makeChapterDir(sourceChapter());
  const first = await buildChapter(dir, await makeOutDir());
  const second = await buildChapter(dir, await makeOutDir());
  assert.equal(second.chapter.id, first.chapter.id);
  assert.deepEqual(
    second.topics.map((t) => t.id),
    first.topics.map((t) => t.id),
  );
  assert.deepEqual(
    second.qnas.map((q) => q.id),
    first.qnas.map((q) => q.id),
  );
});

test("adding a qna preserves existing ids and mints only the new one", async () => {
  const source = sourceChapter();
  const dir = await makeChapterDir(source);
  const first = await buildChapter(dir, await makeOutDir());
  source.topics[0].qnas.push({
    key: "q-two",
    question: "Question two?",
    years: null,
    marks: 5,
    sort_order: 2,
    earns_marks: [],
    sections: [{ key: "summary", heading: "Summary", body_md: "Body two." }],
    images: [],
  });
  await writeFile(
    path.join(dir, "chapter.json"),
    JSON.stringify(source, null, 2),
  );
  const second = await buildChapter(dir, await makeOutDir());
  assert.equal(second.qnas[0].id, first.qnas[0].id);
  assert.match(second.qnas[1].id, ULID_RE);
  assert.notEqual(second.qnas[1].id, second.qnas[0].id);
});

test("canonical text row shape matches the DB columns", async () => {
  const dir = await makeChapterDir(sourceChapter());
  const canonical = await buildChapter(dir, await makeOutDir());
  assert.equal(canonical.schema_version, 1);
  assert.equal(canonical.speciality_slug, "anaesthesia");
  assert.deepEqual(Object.keys(canonical.chapter).sort(), [
    "exam_weight",
    "id",
    "slug",
    "sort_order",
    "title",
  ]);
  assert.deepEqual(Object.keys(canonical.topics[0]).sort(), [
    "chapter_id",
    "exam_theme",
    "id",
    "slug",
    "sort_order",
    "title",
  ]);
  assert.deepEqual(Object.keys(canonical.qnas[0]).sort(), [
    "earns_marks",
    "id",
    "marks",
    "question",
    "sections",
    "sort_order",
    "topic_id",
    "years",
  ]);
  const out = JSON.parse(
    await readFile(path.join(await (async () => dir)(), "ids.lock"), "utf8"),
  );
  assert.ok(out.images);
});

test("a qna without a key fails the build", async () => {
  const source = sourceChapter();
  delete source.topics[0].qnas[0].key;
  const dir = await makeChapterDir(source);
  await assert.rejects(() => buildChapter(dir, ""), /missing "key"/);
});

function sourceChapterWithImage(fileName) {
  const source = sourceChapter();
  source.topics[0].qnas[0].images = [
    {
      file: fileName,
      caption: "Sample diagram",
      content_description:
        "A plain sample panel used as a placeholder diagram.",
      sort_order: 1,
    },
  ];
  return source;
}

test("images are converted to capped WebP with sha256 and byte_size", async () => {
  const dir = await makeChapterDir(sourceChapterWithImage("big.png"));
  const png = await sharp({
    create: {
      width: 2400,
      height: 1800,
      channels: 3,
      background: { r: 200, g: 220, b: 230 },
    },
  })
    .png()
    .toBuffer();
  await writeFile(path.join(dir, "images", "big.png"), png);
  const outDir = await makeOutDir();
  const canonical = await buildChapter(dir, outDir);

  assert.equal(canonical.images.length, 1);
  const img = canonical.images[0];
  assert.match(img.id, ULID_RE);
  assert.equal(img.qna_id, canonical.qnas[0].id);
  assert.equal(img.file, `images/${img.id}.webp`);
  const bytes = await readFile(path.join(outDir, img.file));
  assert.equal(bytes.toString("ascii", 0, 4), "RIFF");
  assert.equal(bytes.toString("ascii", 8, 12), "WEBP");
  assert.equal(img.byte_size, bytes.length);
  assert.ok(bytes.length <= 204800, `image is ${bytes.length} bytes`);
  assert.equal(img.sha256, createHash("sha256").update(bytes).digest("hex"));
  const meta = await sharp(bytes).metadata();
  assert.ok(
    meta.width <= 1600 && meta.height <= 1600,
    `resized to ${meta.width}x${meta.height}`,
  );
});

test("image ULID is stable across rebuilds", async () => {
  const dir = await makeChapterDir(sourceChapterWithImage("big.png"));
  const png = await sharp({
    create: {
      width: 800,
      height: 600,
      channels: 3,
      background: { r: 210, g: 210, b: 210 },
    },
  })
    .png()
    .toBuffer();
  await writeFile(path.join(dir, "images", "big.png"), png);
  const first = await buildChapter(dir, await makeOutDir());
  const second = await buildChapter(dir, await makeOutDir());
  assert.equal(second.images[0].id, first.images[0].id);
});

test("an incompressible image over the cap fails the build", async () => {
  const dir = await makeChapterDir(sourceChapterWithImage("noise.png"));
  // Random noise is incompressible; at 1600x1600 even quality 40 WebP stays over 200KB.
  const noise = await sharp(randomBytes(1600 * 1600 * 3), {
    raw: { width: 1600, height: 1600, channels: 3 },
  })
    .png()
    .toBuffer();
  await writeFile(path.join(dir, "images", "noise.png"), noise);
  await assert.rejects(
    async () => buildChapter(dir, await makeOutDir()),
    /exceeds 204800 bytes at lowest quality/,
  );
});
