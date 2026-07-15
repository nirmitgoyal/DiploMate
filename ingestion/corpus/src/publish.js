import { createHash } from "node:crypto";
import { summarize } from "../../src/summarize.js";

export function id16(s) {
  return createHash("sha256").update(s).digest("hex").slice(0, 16);
}

export async function getSpecialityId(client, slug) {
  const { rows } = await client.query(
    "SELECT id FROM specialities WHERE slug = $1",
    [slug],
  );
  return rows[0]?.id ?? null;
}

// Every qna id already published for a speciality, so a resumed run skips
// generation (not just insertion) and never re-pays Bedrock for done rows.
export async function getExistingQnaIds(client, specialityId) {
  const { rows } = await client.query(
    `SELECT q.id FROM qnas q
       JOIN chapters c ON q.chapter_id = c.id
      WHERE c.speciality_id = $1`,
    [specialityId],
  );
  return new Set(rows.map((r) => r.id));
}

// Chapter id is deterministic from (speciality, slug) so re-runs and the
// UNIQUE(speciality_id, slug) constraint agree. A chapter is only ever upserted
// right before a qna is inserted into it, so content_version must land >0 -
// the manifest gates `has_content` on content_version > 0, and 0 hides the
// whole chapter from the app. Fresh insert = 1; each later qna in the same
// chapter increments it, so a resumed run bumps the version and invalidates
// the app's cached copy.
export async function upsertChapter(client, specialityId, title, slug) {
  const id = id16(`${specialityId}|${slug}`);
  await client.query(
    `INSERT INTO chapters (id, speciality_id, title, slug, sort_order, exam_weight, content_version)
     VALUES ($1, $2, $3, $4, 0, 0, 1)
     ON CONFLICT (speciality_id, slug)
     DO UPDATE SET content_version = chapters.content_version + 1`,
    [id, specialityId, title, slug],
  );
  return id;
}

export async function insertQna(
  client,
  { key, chapterId, question, years, marks, earnsMarks, sections, summary },
) {
  await client.query(
    `INSERT INTO qnas (id, chapter_id, question, years, marks, earns_marks, sections, summary, sort_order)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 0)
     ON CONFLICT (id) DO UPDATE SET
       chapter_id = EXCLUDED.chapter_id, question = EXCLUDED.question,
       years = EXCLUDED.years, marks = EXCLUDED.marks,
       earns_marks = EXCLUDED.earns_marks, sections = EXCLUDED.sections,
       summary = EXCLUDED.summary`,
    [
      key,
      chapterId,
      question,
      years ?? null,
      marks ?? null,
      JSON.stringify(earnsMarks ?? []),
      JSON.stringify(sections),
      summary ?? summarize(sections),
    ],
  );
}
