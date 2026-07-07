// Regenerates sample-2page.pdf: a minimal, dependency-free 2-page PDF built
// from owned synthetic text (never Miller/reference-book text). Used only to
// exercise buildPageIndex() against a real pdftotext page split.
//
// Run: node fixtures/make-sample.js (from ingestion/generator/)
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

function pdfString(s) {
  return `(${s.replace(/([()\\])/g, "\\$1")})`;
}

function contentObject(text) {
  const body = `BT /F1 24 Tf 72 700 Td ${pdfString(text)} Tj ET`;
  return `<< /Length ${Buffer.byteLength(body, "latin1")} >>\nstream\n${body}\nendstream`;
}

const objects = [
  "<< /Type /Catalog /Pages 2 0 R >>",
  "<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>",
  "<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 5 0 R >> >> /MediaBox [0 0 612 792] /Contents 6 0 R >>",
  "<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 5 0 R >> >> /MediaBox [0 0 612 792] /Contents 7 0 R >>",
  "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
  contentObject("owned sample page one"),
  contentObject("owned sample page two"),
];

let pdf = "%PDF-1.4\n";
const offsets = [0]; // object 0 is the free-list head, never emitted
for (let i = 0; i < objects.length; i++) {
  offsets.push(Buffer.byteLength(pdf, "latin1"));
  pdf += `${i + 1} 0 obj\n${objects[i]}\nendobj\n`;
}

const xrefOffset = Buffer.byteLength(pdf, "latin1");
let xref = `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
for (let i = 1; i <= objects.length; i++) {
  xref += `${String(offsets[i]).padStart(10, "0")} 00000 n \n`;
}

pdf += xref;
pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF`;

const dest = fileURLToPath(new URL("./sample-2page.pdf", import.meta.url));
writeFileSync(dest, pdf, "latin1");
console.log(`wrote ${dest} (${Buffer.byteLength(pdf, "latin1")} bytes)`);
