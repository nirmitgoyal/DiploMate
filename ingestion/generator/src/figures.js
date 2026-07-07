import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { readdir } from "node:fs/promises";
import path from "node:path";
import sharp from "sharp";

const exec = promisify(execFile);

// Print-scan quality: high enough that a cropped sub-region of a book page
// still holds detail once processImage (../../src/build.js) downsizes and
// re-encodes it. Not exposed as a parameter - the brief's signature takes
// exactly (pdfPath, pdfPage, outPng).
const RENDER_DPI = 300;

// ponytail: hand-verified crop boxes (pilot). The page-PNG + bbox JSON this
// emits IS the exact input the trigger-gated batch UI (TODOS 9) would take -
// build the UI only if the pilot's figure-review time projection demands it.

// Renders one PDF page to a PNG via pdftoppm and returns the path it
// actually wrote. pdftoppm never writes exactly `outPng`: given a prefix it
// appends "-<page>" (zero-padded once the document needs more digits)
// before the extension, e.g. outPng "page.png" -> "page-2.png" or
// "page-006.png". So: strip outPng's extension to get the prefix pdftoppm
// wants, run it, then find the one file in that directory matching
// "<prefix>-<digits>.png" and return ITS real path - never the unwritten
// `outPng` itself.
export async function renderPage(pdfPath, pdfPage, outPng) {
  const dir = path.dirname(outPng);
  const prefix = outPng.replace(/\.png$/i, "");
  const base = path.basename(prefix);

  await exec("pdftoppm", [
    "-png",
    "-f",
    String(pdfPage),
    "-l",
    String(pdfPage),
    "-r",
    String(RENDER_DPI),
    pdfPath,
    prefix,
  ]);

  const entries = await readdir(dir);
  const produced = entries.find((f) => {
    if (!f.startsWith(`${base}-`) || !f.endsWith(".png")) return false;
    return /^\d+$/.test(f.slice(base.length + 1, -".png".length));
  });
  if (!produced) {
    throw new Error(
      `pdftoppm did not produce a PNG for ${pdfPath} page ${pdfPage} (prefix ${prefix})`,
    );
  }
  return path.join(dir, produced);
}

// Crops a rendered page to a human-verified bounding box and writes it to
// exactly `outPng` (sharp.toFile has none of pdftoppm's naming quirk). The
// cropped PNG is the resizer's input - the caller feeds it to the UNCHANGED
// processImage (../../src/build.js) for the WebP/quality-ladder/200KB pass;
// that logic is not reimplemented here.
export async function cropFigure(pngPath, bbox, outPng) {
  await sharp(pngPath).extract(bbox).toFile(outPng);
  return outPng;
}
