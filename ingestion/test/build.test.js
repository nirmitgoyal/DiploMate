import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { buildChapter } from "../src/build.js";

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
