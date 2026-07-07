import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { ulid } from "ulid";
import { createHash } from "node:crypto";
import sharp from "sharp";

export const MAX_IMAGE_BYTES = 204800;
export const MAX_IMAGE_EDGE = 1600;
const WEBP_QUALITIES = [80, 60, 40];

// Speciality-level ledger (eng amendment 1): ONE ids.lock per speciality;
// chapter membership is placement only, so a question moved between chapters
// keeps its ULID. Default lock location: the chapter dir's PARENT (all of a
// speciality's chapter dirs share it); the generator passes the committed
// ledger path explicitly. After a cross-chapter move, republish BOTH affected
// chapters in one publish invocation (identity survives either order; the
// batch shrinks the transient-absence window - see publish.js).
export function defaultLockPath(chapterDir) {
  return path.join(path.dirname(path.resolve(chapterDir)), "ids.lock");
}

export async function buildChapter(
  chapterDir,
  outDir,
  lockPath = defaultLockPath(chapterDir),
) {
  const source = JSON.parse(
    await readFile(path.join(chapterDir, "chapter.json"), "utf8"),
  );
  let lock;
  try {
    lock = JSON.parse(await readFile(lockPath, "utf8"));
  } catch {
    lock = { chapters: {}, qnas: {}, images: {} };
  }
  lock.chapters ??= {};
  lock.qnas ??= {};
  lock.images ??= {};
  const mint = (map, key) => (map[key] ??= ulid());

  if (!source.chapter?.key)
    throw new Error(
      `chapter "${source.chapter?.title ?? "?"}": missing "key" (permanent identity handle, see AUTHORING.md)`,
    );
  const chapterId = mint(lock.chapters, source.chapter.key);

  const canonical = {
    schema_version: 2,
    speciality_slug: source.speciality_slug,
    chapter: {
      id: chapterId,
      title: source.chapter.title,
      slug: source.chapter.slug,
      sort_order: source.chapter.sort_order,
      exam_weight: source.chapter.exam_weight,
    },
    qnas: [],
    images: [],
  };

  for (const qna of source.qnas ?? []) {
    if (!qna.key)
      throw new Error(
        `qna "${(qna.question ?? "?").slice(0, 40)}": missing "key" (permanent identity handle, see AUTHORING.md)`,
      );
    const qnaId = mint(lock.qnas, qna.key);
    canonical.qnas.push({
      id: qnaId,
      chapter_id: chapterId,
      question: qna.question,
      years: qna.years ?? null,
      marks: qna.marks ?? null,
      earns_marks: qna.earns_marks ?? [],
      sections: qna.sections,
      sort_order: qna.sort_order,
    });
    for (const img of qna.images ?? []) {
      const imageId = mint(lock.images, `${qna.key}/${img.file}`);
      const processed = await processImage(
        path.join(chapterDir, "images", img.file),
      );
      await mkdir(path.join(outDir, "images"), { recursive: true });
      await writeFile(
        path.join(outDir, "images", `${imageId}.webp`),
        processed,
      );
      canonical.images.push({
        id: imageId,
        qna_id: qnaId,
        caption: img.caption,
        content_description: img.content_description,
        file: `images/${imageId}.webp`,
        byte_size: processed.length,
        sha256: createHash("sha256").update(processed).digest("hex"),
        sort_order: img.sort_order,
      });
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

export async function processImage(sourcePath) {
  for (const quality of WEBP_QUALITIES) {
    const buf = await sharp(sourcePath)
      .rotate()
      .resize({
        width: MAX_IMAGE_EDGE,
        height: MAX_IMAGE_EDGE,
        fit: "inside",
        withoutEnlargement: true,
      })
      .webp({ quality })
      .toBuffer();
    if (buf.length <= MAX_IMAGE_BYTES) return buf;
  }
  throw new Error(
    `image ${sourcePath} exceeds ${MAX_IMAGE_BYTES} bytes at lowest quality`,
  );
}

const sortKeys = (obj) =>
  Object.fromEntries(Object.entries(obj).sort(([a], [b]) => (a < b ? -1 : 1)));

async function writeLock(lockPath, lock) {
  const stable = {
    chapters: sortKeys(lock.chapters),
    qnas: sortKeys(lock.qnas),
    images: sortKeys(lock.images),
  };
  await writeFile(lockPath, JSON.stringify(stable, null, 2) + "\n");
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const [chapterDir, outDir, lockPath] = process.argv.slice(2);
  if (!chapterDir || !outDir) {
    console.error("usage: node src/build.js <chapterDir> <outDir> [lockPath]");
    process.exit(2);
  }
  try {
    const canonical = await buildChapter(chapterDir, outDir, lockPath);
    console.log(
      `built chapter ${canonical.chapter.id} (${canonical.qnas.length} qnas, ${canonical.images.length} images)`,
    );
  } catch (err) {
    console.error(`ERROR ${err.message}`);
    process.exit(1);
  }
}
