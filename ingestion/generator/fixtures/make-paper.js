// Regenerates sample-paper.pdf (a text PDF) and scan-paper.pdf (an
// image-only PDF derived from it): an owned synthetic exam paper - numbered
// questions with a trailing marks suffix, never Miller/reference-book text.
// Used to exercise probeTextLayer()/extractQuestions() against both a real
// text layer and a real scanned (no text layer) PDF.
//
// Run: node fixtures/make-paper.js (from ingestion/generator/)
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { writeFileSync, readdirSync, rmSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";
import path from "node:path";

const exec = promisify(execFile);

function pdfString(s) {
  return `(${s.replace(/([()\\])/g, "\\$1")})`;
}

function textPageContent(lines) {
  let body = "BT /F1 12 Tf\n";
  let y = 740;
  for (const line of lines) {
    body += `1 0 0 1 72 ${y} Tm ${pdfString(line)} Tj\n`;
    y -= 20;
  }
  body += "ET";
  return `<< /Length ${Buffer.byteLength(body, "latin1")} >>\nstream\n${body}\nendstream`;
}

function buildPdf(objects) {
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
  return pdf;
}

// Owned synthetic exam questions - numbered items with a trailing marks
// suffix, the exact shape extractQuestions() splits on. Exported so the
// test can assert against the known text without duplicating it.
export const SAMPLE_QUESTIONS = [
  "Describe the pharmacology of local anaesthetics.",
  "Discuss the management of a difficult airway in a trauma patient.",
  "Write short notes on spinal anaesthesia.",
];

const LINES = [
  "2021 Paper I",
  "",
  `1. ${SAMPLE_QUESTIONS[0]} (10 marks)`,
  `2. ${SAMPLE_QUESTIONS[1]} (10 marks)`,
  `3. ${SAMPLE_QUESTIONS[2]} (5 marks)`,
];

const textObjects = [
  "<< /Type /Catalog /Pages 2 0 R >>",
  "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  "<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 4 0 R >> >> /MediaBox [0 0 612 792] /Contents 5 0 R >>",
  "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
  textPageContent(LINES),
];

const samplePath = fileURLToPath(
  new URL("./sample-paper.pdf", import.meta.url),
);
writeFileSync(samplePath, buildPdf(textObjects), "latin1");
console.log(`wrote ${samplePath}`);

// Derive scan-paper.pdf: rasterize the text PDF to a PNG (pdftoppm, already
// a package dependency on PATH), then wrap that PNG into a fresh PDF with
// whichever image->PDF tool is available - no text layer survives the
// round trip, so probeTextLayer() must report hasText:false on it.
const rasterPrefix = path.join(tmpdir(), `diplomate-scan-${Date.now()}`);
await exec("pdftoppm", ["-png", "-r", "150", samplePath, rasterPrefix]);
const pngName = readdirSync(tmpdir()).find((f) =>
  f.startsWith(path.basename(rasterPrefix)),
);
const pngPath = path.join(tmpdir(), pngName);

const scanPath = fileURLToPath(new URL("./scan-paper.pdf", import.meta.url));
await wrapPngAsPdf(pngPath, scanPath);
rmSync(pngPath);
console.log(`wrote ${scanPath}`);

// ponytail: probe in the order the task brief specifies (img2pdf, then
// ImageMagick) and only fall back to a hand-rolled Image XObject PDF if
// neither is on PATH - this box has ImageMagick, so that fallback is
// untested dead weight until a machine without it needs the fixture
// regenerated.
async function wrapPngAsPdf(png, outPdf) {
  for (const [cmd, args] of [
    ["img2pdf", [png, "-o", outPdf]],
    ["magick", [png, outPdf]],
    ["convert", [png, outPdf]],
  ]) {
    try {
      await exec(cmd, args);
      return;
    } catch (err) {
      if (err.code !== "ENOENT") throw err;
    }
  }
  throw new Error(
    "no PNG->PDF tool found (tried img2pdf, magick, convert) - install one to regenerate scan-paper.pdf",
  );
}
