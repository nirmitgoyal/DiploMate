import { readFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

export const MAX_IMAGE_BYTES = 204800;
export const MAX_IMAGE_EDGE = 1600;
const ULID_RE = /^[0-9A-HJKMNP-TV-Z]{26}$/;
const SLUG_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

export async function validateCanonical(dir) {
  const errors = [];
  let canonical;
  try {
    canonical = JSON.parse(
      await readFile(path.join(dir, "chapter.json"), "utf8"),
    );
  } catch (err) {
    return [`chapter.json: unreadable or not valid JSON (${err.message})`];
  }

  const isInt = (v) => Number.isInteger(v);
  const nonEmpty = (v) => typeof v === "string" && v.trim().length > 0;
  const seenIds = new Set();
  const checkId = (label, id) => {
    if (!ULID_RE.test(id ?? ""))
      errors.push(`${label}.id: ${JSON.stringify(id ?? null)} is not a ULID`);
    else if (seenIds.has(id))
      errors.push(`${label}.id: duplicate id ${JSON.stringify(id)}`);
    seenIds.add(id);
  };

  if (canonical.schema_version !== 1) {
    errors.push(
      `schema_version: expected 1, got ${JSON.stringify(canonical.schema_version ?? null)}`,
    );
  }
  if (
    !nonEmpty(canonical.speciality_slug) ||
    !SLUG_RE.test(canonical.speciality_slug)
  ) {
    errors.push(
      `speciality_slug: ${JSON.stringify(canonical.speciality_slug ?? null)} is not a valid slug`,
    );
  }

  const ch = canonical.chapter ?? {};
  checkId("chapter", ch.id);
  if (!nonEmpty(ch.title)) errors.push("chapter.title: missing or empty");
  if (!SLUG_RE.test(ch.slug ?? ""))
    errors.push(
      `chapter.slug: ${JSON.stringify(ch.slug ?? null)} is not a valid slug`,
    );
  if (!isInt(ch.sort_order)) errors.push("chapter.sort_order: not an integer");
  if (!isInt(ch.exam_weight))
    errors.push("chapter.exam_weight: not an integer");

  const topics = Array.isArray(canonical.topics) ? canonical.topics : [];
  if (topics.length === 0) errors.push("topics: must be a non-empty array");
  const topicIds = new Set();
  const topicSlugs = new Set();
  topics.forEach((t, i) => {
    checkId(`topics[${i}]`, t.id);
    if (t.chapter_id !== ch.id)
      errors.push(`topics[${i}].chapter_id: does not match chapter.id`);
    if (!nonEmpty(t.title)) errors.push(`topics[${i}].title: missing or empty`);
    if (!SLUG_RE.test(t.slug ?? ""))
      errors.push(
        `topics[${i}].slug: ${JSON.stringify(t.slug ?? null)} is not a valid slug`,
      );
    else if (topicSlugs.has(t.slug))
      errors.push(`topics: duplicate slug ${JSON.stringify(t.slug)}`);
    topicSlugs.add(t.slug);
    if (t.exam_theme != null && !nonEmpty(t.exam_theme))
      errors.push(
        `topics[${i}].exam_theme: must be a non-empty string or null`,
      );
    if (!isInt(t.sort_order))
      errors.push(`topics[${i}].sort_order: not an integer`);
    topicIds.add(t.id);
  });

  const qnas = Array.isArray(canonical.qnas) ? canonical.qnas : [];
  if (qnas.length === 0) errors.push("qnas: must be a non-empty array");
  const qnaIds = new Set();
  qnas.forEach((q, i) => {
    checkId(`qnas[${i}]`, q.id);
    if (!topicIds.has(q.topic_id))
      errors.push(
        `qnas[${i}].topic_id: ${JSON.stringify(q.topic_id ?? null)} does not match any topics[].id`,
      );
    if (!nonEmpty(q.question))
      errors.push(`qnas[${i}].question: missing or empty`);
    if (q.years != null && !nonEmpty(q.years))
      errors.push(`qnas[${i}].years: must be a non-empty string or null`);
    if (q.marks != null && !isInt(q.marks))
      errors.push(`qnas[${i}].marks: must be an integer or null`);
    if (!isInt(q.sort_order))
      errors.push(`qnas[${i}].sort_order: not an integer`);

    const sections = Array.isArray(q.sections) ? q.sections : [];
    if (sections.length === 0)
      errors.push(`qnas[${i}].sections: must be a non-empty array`);
    const sectionKeys = new Set();
    sections.forEach((s, j) => {
      if (!nonEmpty(s.key))
        errors.push(`qnas[${i}].sections[${j}].key: missing or empty`);
      else if (sectionKeys.has(s.key))
        errors.push(
          `qnas[${i}].sections: duplicate key ${JSON.stringify(s.key)}`,
        );
      sectionKeys.add(s.key);
      if (!nonEmpty(s.heading))
        errors.push(`qnas[${i}].sections[${j}].heading: missing or empty`);
      if (!nonEmpty(s.body_md))
        errors.push(`qnas[${i}].sections[${j}].body_md: missing or empty`);
    });

    if (!Array.isArray(q.earns_marks))
      errors.push(`qnas[${i}].earns_marks: must be an array`);
    (Array.isArray(q.earns_marks) ? q.earns_marks : []).forEach((e, j) => {
      if (!nonEmpty(e.label))
        errors.push(`qnas[${i}].earns_marks[${j}].label: missing or empty`);
      if (!sectionKeys.has(e.section_key))
        errors.push(
          `qnas[${i}].earns_marks[${j}].section_key: ${JSON.stringify(e.section_key ?? null)} does not match any sections[].key`,
        );
    });
    qnaIds.add(q.id);
  });

  if (!Array.isArray(canonical.images)) errors.push("images: must be an array");
  const images = Array.isArray(canonical.images) ? canonical.images : [];
  for (const [i, img] of images.entries()) {
    checkId(`images[${i}]`, img.id);
    if (!qnaIds.has(img.qna_id))
      errors.push(
        `images[${i}].qna_id: ${JSON.stringify(img.qna_id ?? null)} does not match any qnas[].id`,
      );
    if (!nonEmpty(img.caption))
      errors.push(`images[${i}].caption: missing or empty`);
    if (!nonEmpty(img.content_description))
      errors.push(`images[${i}].content_description: missing or empty`);
    if (!isInt(img.sort_order))
      errors.push(`images[${i}].sort_order: not an integer`);
    if (!nonEmpty(img.file)) {
      errors.push(`images[${i}].file: missing or empty`);
      continue;
    }
    let bytes;
    try {
      bytes = await readFile(path.join(dir, img.file));
    } catch {
      errors.push(`images[${i}].file: ${img.file} not found`);
      continue;
    }
    const isWebp =
      bytes.length >= 12 &&
      bytes.toString("ascii", 0, 4) === "RIFF" &&
      bytes.toString("ascii", 8, 12) === "WEBP";
    if (!isWebp) {
      errors.push(`images[${i}]: not a WebP file`);
      continue;
    }
    if (img.byte_size !== bytes.length)
      errors.push(
        `images[${i}].byte_size: ${img.byte_size} does not match file size ${bytes.length}`,
      );
    if (bytes.length > MAX_IMAGE_BYTES)
      errors.push(
        `images[${i}]: byte_size ${bytes.length} exceeds ${MAX_IMAGE_BYTES}`,
      );
    const sha = createHash("sha256").update(bytes).digest("hex");
    if (img.sha256 !== sha)
      errors.push(`images[${i}].sha256: does not match file contents`);
    try {
      const meta = await sharp(bytes).metadata();
      if ((meta.width ?? 0) > MAX_IMAGE_EDGE)
        errors.push(
          `images[${i}]: width ${meta.width} exceeds ${MAX_IMAGE_EDGE}`,
        );
      if ((meta.height ?? 0) > MAX_IMAGE_EDGE)
        errors.push(
          `images[${i}]: height ${meta.height} exceeds ${MAX_IMAGE_EDGE}`,
        );
    } catch {
      errors.push(`images[${i}]: unreadable image data`);
    }
  }

  return errors;
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const dir = process.argv[2];
  if (!dir) {
    console.error("usage: node src/validate.js <canonicalDir>");
    process.exit(2);
  }
  const errors = await validateCanonical(dir);
  if (errors.length > 0) {
    for (const e of errors) console.error(`ERROR ${e}`);
    process.exit(1);
  }
  const canonical = JSON.parse(
    await readFile(path.join(dir, "chapter.json"), "utf8"),
  );
  console.log(
    `OK ${dir}: ${canonical.qnas.length} qnas, ${canonical.images.length} images validated`,
  );
}
