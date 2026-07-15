// Derive the question-list summary from an answer's sections: the dedicated
// `Summary` section when the author wrote one, else the first section, with
// markdown stripped to plain prose. Kept in lockstep with the app's
// `summarizeSections` (app/lib/domain/models.dart) and sql/0005's backfill so
// stored values agree whichever path wrote them.
export function summarize(sections) {
  if (!Array.isArray(sections) || sections.length === 0) return null;
  const s =
    sections.find((x) => String(x.heading ?? "").toLowerCase() === "summary") ||
    sections[0];
  return stripMarkdown(String(s.body_md ?? ""));
}

function stripMarkdown(md) {
  return md
    .replace(/^\s*[-*+>#]+\s*/gm, "")
    .replace(/[*_`#]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}
