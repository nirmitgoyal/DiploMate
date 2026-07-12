import { createHash } from "node:crypto";

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

// Chapter id is deterministic from (speciality, slug) so re-runs and the
// UNIQUE(speciality_id, slug) constraint agree. content_version starts at 0.
export async function upsertChapter(client, specialityId, title, slug) {
  const id = id16(`${specialityId}|${slug}`);
  await client.query(
    `INSERT INTO chapters (id, speciality_id, title, slug, sort_order, exam_weight, content_version)
     VALUES ($1, $2, $3, $4, 0, 0, 0)
     ON CONFLICT (speciality_id, slug) DO NOTHING`,
    [id, specialityId, title, slug],
  );
  return id;
}

export async function insertQna(
  client,
  { key, chapterId, question, years, marks, earnsMarks, sections },
) {
  await client.query(
    `INSERT INTO qnas (id, chapter_id, question, years, marks, earns_marks, sections, sort_order)
     VALUES ($1, $2, $3, $4, $5, $6, $7, 0)
     ON CONFLICT (id) DO NOTHING`,
    [
      key,
      chapterId,
      question,
      years ?? null,
      marks ?? null,
      JSON.stringify(earnsMarks ?? []),
      JSON.stringify(sections),
    ],
  );
}
