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
    speciality_slug: "anaesthesiology",
    chapter: {
      key: "sample-chapter",
      title: "Sample Chapter",
      slug: "sample-chapter",
      sort_order: 1,
      exam_weight: 10,
    },
    qnas: [
      {
        key: "q-one",
        question: "Question one?",
        years: "2022",
        marks: 10,
        sort_order: 1,
        earns_marks: [{ label: "Definition point", section_key: "definition" }],
        sections: [
          { key: "definition", heading: "Definition", body_md: "Body one." },
        ],
        images: [],
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

async function makeSpecialityDir(...sources) {
  const parent = await mkdtemp(path.join(tmpdir(), "ingest-spec-"));
  const dirs = [];
  for (const [i, source] of sources.entries()) {
    const dir = path.join(parent, `ch${i}`);
    await mkdir(path.join(dir, "images"), { recursive: true });
    await writeFile(
      path.join(dir, "chapter.json"),
      JSON.stringify(source, null, 2),
    );
    dirs.push(dir);
  }
  return { parent, dirs };
}

async function makeOutDir() {
  return mkdtemp(path.join(tmpdir(), "ingest-out-"));
}

test("build mints ULIDs into a speciality-level lock beside the chapter dirs", async () => {
  const { parent, dirs } = await makeSpecialityDir(sourceChapter());
  const out = await mkdtemp(path.join(tmpdir(), "ingest-out-"));
  const canonical = await buildChapter(dirs[0], out);
  assert.equal(canonical.schema_version, 2);
  assert.match(canonical.chapter.id, ULID_RE);
  assert.equal(canonical.qnas[0].chapter_id, canonical.chapter.id);
  assert.equal("topics" in canonical, false);
  const lock = JSON.parse(
    await readFile(path.join(parent, "ids.lock"), "utf8"),
  );
  assert.equal(lock.chapters["sample-chapter"], canonical.chapter.id);
  assert.equal(lock.qnas["q-one"], canonical.qnas[0].id);
  assert.equal("topics" in lock, false);
});

test("re-run produces zero key churn (ledger stability)", async () => {
  const { parent, dirs } = await makeSpecialityDir(sourceChapter());
  const out = await mkdtemp(path.join(tmpdir(), "ingest-out-"));
  await buildChapter(dirs[0], out);
  const first = await readFile(path.join(parent, "ids.lock"), "utf8");
  await buildChapter(dirs[0], out);
  const second = await readFile(path.join(parent, "ids.lock"), "utf8");
  assert.equal(
    second,
    first,
    "second build must not re-mint or reorder anything",
  );
});

test("a qna moved between chapters keeps its ULID (speciality ledger, amendment 1)", async () => {
  const chapterA = sourceChapter();
  const chapterB = {
    ...sourceChapter(),
    chapter: {
      key: "other-chapter",
      title: "Other",
      slug: "other-chapter",
      sort_order: 2,
      exam_weight: 5,
    },
    qnas: [],
  };
  const { dirs } = await makeSpecialityDir(chapterA, chapterB);
  const out1 = await mkdtemp(path.join(tmpdir(), "ingest-out-"));
  const builtA = await buildChapter(dirs[0], out1);
  const movedId = builtA.qnas[0].id;

  // Move q-one: gone from A, present in B. Same speciality lock -> same ULID.
  const aWithout = { ...chapterA, qnas: [] };
  const bWith = { ...chapterB, qnas: chapterA.qnas };
  await writeFile(
    path.join(dirs[0], "chapter.json"),
    JSON.stringify(aWithout, null, 2),
  );
  await writeFile(
    path.join(dirs[1], "chapter.json"),
    JSON.stringify(bWith, null, 2),
  );
  const out2 = await mkdtemp(path.join(tmpdir(), "ingest-out-"));
  const builtB = await buildChapter(dirs[1], out2);
  assert.equal(
    builtB.qnas[0].id,
    movedId,
    "reclassification must not re-mint identity",
  );
  assert.equal(builtB.qnas[0].chapter_id, builtB.chapter.id);
});

test("missing chapter.key or qna.key fails loudly", async () => {
  const noChapterKey = sourceChapter();
  delete noChapterKey.chapter.key;
  const dir1 = await makeChapterDir(noChapterKey);
  await assert.rejects(
    () => buildChapter(dir1, dir1 + "-out"),
    /chapter .*missing "key"/,
  );
  const noQnaKey = sourceChapter();
  delete noQnaKey.qnas[0].key;
  const dir2 = await makeChapterDir(noQnaKey);
  await assert.rejects(
    () => buildChapter(dir2, dir2 + "-out"),
    /qna .*missing "key"/,
  );
});

test("an explicit lockPath overrides the default (generator hands the committed ledger in)", async () => {
  const dir = await makeChapterDir(sourceChapter());
  const out = await mkdtemp(path.join(tmpdir(), "ingest-out-"));
  const lockPath = path.join(
    await mkdtemp(path.join(tmpdir(), "ledger-")),
    "anaesthesiology.ids.lock",
  );
  const canonical = await buildChapter(dir, out, lockPath);
  const lock = JSON.parse(await readFile(lockPath, "utf8"));
  assert.equal(lock.chapters["sample-chapter"], canonical.chapter.id);
});

function sourceChapterWithImage(fileName) {
  const source = sourceChapter();
  source.qnas[0].images = [
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
