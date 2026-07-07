import { execFile } from "node:child_process";
import { promisify } from "node:util";
const exec = promisify(execFile);

// One entry per PDF page from the text layer. -layout preserves column
// geometry so the verifier's two-column normalization has something to work
// with; the page delimiter is the form feed pdftotext emits between pages.
// pdftotext also emits a form feed after the LAST page, not just between
// pages, so splitting on "\f" always leaves one trailing empty element -
// drop it, or a P-page PDF reports P+1 pages (verified against poppler
// 26.03.0: a 1-page PDF yields ["text", ""], not ["text"]).
export async function buildPageIndex(pdfPath) {
  const { stdout } = await exec("pdftotext", ["-layout", pdfPath, "-"], {
    maxBuffer: 512 * 1024 * 1024,
  });
  const pages = stdout.split("\f");
  if (pages.at(-1) === "") pages.pop();
  return pages.map((text, i) => ({ pdf_page: i + 1, text }));
}

export function pageText(index, pdfPage) {
  return index.find((p) => p.pdf_page === pdfPage)?.text ?? "";
}
