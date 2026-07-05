import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { ulid } from "ulid";

export async function buildChapter(chapterDir, outDir) {
  const source = JSON.parse(
    await readFile(path.join(chapterDir, "chapter.json"), "utf8"),
  );
  const lockPath = path.join(chapterDir, "ids.lock");
  let lock;
  try {
    lock = JSON.parse(await readFile(lockPath, "utf8"));
  } catch {
    lock = { chapter: null, topics: {}, qnas: {}, images: {} };
  }
  lock.topics ??= {};
  lock.qnas ??= {};
  lock.images ??= {};
  lock.chapter ??= ulid();
  const mint = (map, key) => (map[key] ??= ulid());

  const canonical = {
    schema_version: 1,
    speciality_slug: source.speciality_slug,
    chapter: {
      id: lock.chapter,
      title: source.chapter.title,
      slug: source.chapter.slug,
      sort_order: source.chapter.sort_order,
      exam_weight: source.chapter.exam_weight,
    },
    topics: [],
    qnas: [],
    images: [],
  };

  for (const topic of source.topics ?? []) {
    if (!topic.key)
      throw new Error(
        `topic "${topic.title ?? "?"}": missing "key" (permanent identity handle, see AUTHORING.md)`,
      );
    const topicId = mint(lock.topics, topic.key);
    canonical.topics.push({
      id: topicId,
      chapter_id: lock.chapter,
      title: topic.title,
      slug: topic.slug,
      exam_theme: topic.exam_theme ?? null,
      sort_order: topic.sort_order,
    });
    for (const qna of topic.qnas ?? []) {
      if (!qna.key)
        throw new Error(
          `qna "${(qna.question ?? "?").slice(0, 40)}": missing "key" (permanent identity handle, see AUTHORING.md)`,
        );
      const qnaId = mint(lock.qnas, qna.key);
      canonical.qnas.push({
        id: qnaId,
        topic_id: topicId,
        question: qna.question,
        years: qna.years ?? null,
        marks: qna.marks ?? null,
        earns_marks: qna.earns_marks ?? [],
        sections: qna.sections,
        sort_order: qna.sort_order,
      });
      // Task 3 wires image processing into this loop.
    }
  }

  await writeLock(lockPath, lock);
  await mkdir(outDir, { recursive: true });
  await writeFile(
    path.join(outDir, "chapter.json"),
    JSON.stringify(canonical, null, 2) + "\n",
  );
  return canonical;
}

const sortKeys = (obj) =>
  Object.fromEntries(Object.entries(obj).sort(([a], [b]) => (a < b ? -1 : 1)));

async function writeLock(lockPath, lock) {
  const stable = {
    chapter: lock.chapter,
    topics: sortKeys(lock.topics),
    qnas: sortKeys(lock.qnas),
    images: sortKeys(lock.images),
  };
  await writeFile(lockPath, JSON.stringify(stable, null, 2) + "\n");
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const [chapterDir, outDir] = process.argv.slice(2);
  if (!chapterDir || !outDir) {
    console.error("usage: node src/build.js <chapterDir> <outDir>");
    process.exit(2);
  }
  try {
    const canonical = await buildChapter(chapterDir, outDir);
    console.log(
      `built chapter ${canonical.chapter.id} (${canonical.qnas.length} qnas, ${canonical.images.length} images)`,
    );
  } catch (err) {
    console.error(`ERROR ${err.message}`);
    process.exit(1);
  }
}
