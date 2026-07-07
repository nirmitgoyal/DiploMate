import { pageText } from "./page_index.js";

// ponytail: fixed normalization catalog calibrated on the pilot's real
// scans (amendment 5). pdftotext-plus-plus is the named fallback ONLY if
// layout-garble flags dominate the pilot - do not add it speculatively.

const EOL_HYPHEN_RE = /-\n/g;
const SOFT_HYPHEN_RE = /\u00AD/g;
const WHITESPACE_RE = /\s+/g;

export function normalize(text) {
  return text
    .replace(EOL_HYPHEN_RE, "") // join a word split across a line break first - needs the \n still in place
    .replace(SOFT_HYPHEN_RE, "") // drop soft hyphens
    .replace(WHITESPACE_RE, " ") // collapse remaining whitespace (incl. real newlines) to single spaces
    .trim();
}

export function verifyQuote(quote, { index, map, bookPage }) {
  const nq = normalize(quote);
  const pdfPage = map.bookToPdf(bookPage);
  const pageN = pageText(index, pdfPage);
  if (normalize(pageN).includes(nq)) {
    return { ok: true, citationPage: bookPage };
  }

  const pageN1 = pageText(index, pdfPage + 1);
  if (normalize(pageN + pageN1).includes(nq)) {
    return { ok: true, citationRange: `${bookPage}-${bookPage + 1}` };
  }

  return { ok: false, reason: "quote-verification-failed" };
}
