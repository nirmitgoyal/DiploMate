import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";
import { validateCanonical } from "./validate.js";
import { summarize } from "./summarize.js";

export function gateCheck(args, env) {
  if (!args.includes("--allow-publish")) {
    return "publish refused: pass --allow-publish (publishing is PG1-gated)";
  }
  if (env.LICENSE_SIGNED !== "true") {
    return "publish refused: set LICENSE_SIGNED=true (content term sheet unsigned - publishing stays PG1-gated)";
  }
  return null;
}

export async function publishChapter(client, canonicalDir) {
  const errors = await validateCanonical(canonicalDir);
  if (errors.length > 0) {
    throw new Error(
      `validation failed: ${errors[0]} (${errors.length} error(s) - run node src/validate.js ${canonicalDir})`,
    );
  }
  const canonical = JSON.parse(
    await readFile(path.join(canonicalDir, "chapter.json"), "utf8"),
  );
  const ch = canonical.chapter;

  await client.query("BEGIN");
  try {
    const spec = await client.query(
      "SELECT id FROM specialities WHERE slug = $1",
      [canonical.speciality_slug],
    );
    if (spec.rowCount === 0) {
      throw new Error(
        `unknown speciality slug "${canonical.speciality_slug}" - specialities are seeded by sql/0002, never created by publish`,
      );
    }
    const specialityId = spec.rows[0].id;

    await client.query(
      `INSERT INTO chapters (id, speciality_id, title, slug, sort_order, exam_weight)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (id) DO UPDATE SET
         speciality_id = EXCLUDED.speciality_id, title = EXCLUDED.title, slug = EXCLUDED.slug,
         sort_order = EXCLUDED.sort_order, exam_weight = EXCLUDED.exam_weight`,
      [ch.id, specialityId, ch.title, ch.slug, ch.sort_order, ch.exam_weight],
    );

    for (const q of canonical.qnas) {
      await client.query(
        `INSERT INTO qnas (id, chapter_id, question, years, marks, earns_marks, sections, summary, sort_order)
         VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb, $8, $9)
         ON CONFLICT (id) DO UPDATE SET
           chapter_id = EXCLUDED.chapter_id, question = EXCLUDED.question, years = EXCLUDED.years,
           marks = EXCLUDED.marks, earns_marks = EXCLUDED.earns_marks, sections = EXCLUDED.sections,
           summary = EXCLUDED.summary,
           sort_order = EXCLUDED.sort_order`,
        [
          q.id,
          q.chapter_id,
          q.question,
          q.years,
          q.marks,
          JSON.stringify(q.earns_marks),
          JSON.stringify(q.sections),
          q.summary ?? summarize(q.sections),
          q.sort_order,
        ],
      );
    }

    for (const img of canonical.images) {
      const bytes = await readFile(path.join(canonicalDir, img.file));
      await client.query(
        `INSERT INTO images (id, qna_id, caption, content_description, webp, byte_size, sha256, sort_order)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         ON CONFLICT (id) DO UPDATE SET
           qna_id = EXCLUDED.qna_id, caption = EXCLUDED.caption,
           content_description = EXCLUDED.content_description, webp = EXCLUDED.webp,
           byte_size = EXCLUDED.byte_size, sha256 = EXCLUDED.sha256, sort_order = EXCLUDED.sort_order`,
        [
          img.id,
          img.qna_id,
          img.caption,
          img.content_description,
          bytes,
          img.byte_size,
          img.sha256,
          img.sort_order,
        ],
      );
    }

    // A republish is authoritative for its chapter: rows dropped from the
    // canonical set are deleted (FK-safe order: images -> qnas). Under the
    // speciality ledger a qna moved to ANOTHER chapter keeps its ULID across the
    // batch. Target-first: the target's upsert has already re-homed the qna
    // (chapter_id no longer matches $1), so the source delete skips it. Source-
    // first: the source delete removes the moved qna and its images, and the
    // target's upsert re-creates them under the new chapter_id - identity is
    // preserved either way, at the cost of a transient absence inside the batch
    // window (each chapter is its own transaction, by design; publish target-
    // first to avoid the window).
    await client.query(
      `DELETE FROM images WHERE qna_id IN (
         SELECT id FROM qnas WHERE chapter_id = $1
       ) AND id <> ALL($2::text[])`,
      [ch.id, canonical.images.map((i) => i.id)],
    );
    await client.query(
      `DELETE FROM qnas WHERE chapter_id = $1 AND id <> ALL($2::text[])`,
      [ch.id, canonical.qnas.map((q) => q.id)],
    );

    // ponytail: content_version bumps on EVERY publish, including a no-change
    // republish - clients just refetch one chapter; diffing rows to skip the
    // bump is complexity the beta does not need.
    const bumped = await client.query(
      "UPDATE chapters SET content_version = content_version + 1 WHERE id = $1 RETURNING content_version",
      [ch.id],
    );
    await client.query("COMMIT");
    return { chapterId: ch.id, contentVersion: bumped.rows[0].content_version };
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  }
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const args = process.argv.slice(2);
  const dirs = args.filter((a) => !a.startsWith("--"));
  if (dirs.length === 0) {
    console.error(
      "usage: LICENSE_SIGNED=true node src/publish.js <canonicalDir> [more dirs...] --allow-publish",
    );
    process.exit(2);
  }
  const refusal = gateCheck(args, process.env);
  if (refusal) {
    console.error(refusal);
    process.exit(1);
  }
  if (!process.env.DATABASE_URL) {
    console.error("DATABASE_URL not set");
    process.exit(2);
  }
  const client = new pg.Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  try {
    for (const dir of dirs) {
      const { chapterId, contentVersion } = await publishChapter(client, dir);
      console.log(
        `published chapter ${chapterId} at content_version ${contentVersion}`,
      );
    }
  } catch (err) {
    console.error(`ERROR ${err.message}`);
    process.exitCode = 1;
  } finally {
    await client.end();
  }
}
