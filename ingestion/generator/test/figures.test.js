import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import path from "node:path";
import sharp from "sharp";
import { renderPage, cropFigure } from "../src/figures.js";
import { processImage } from "../../src/build.js";

// Reuses the Task 1 fixture (owned synthetic 2-page PDF) rather than adding
// a new committed binary just for a render-page smoke test.
const SAMPLE_PDF = fileURLToPath(
  new URL("../fixtures/sample-2page.pdf", import.meta.url),
);

// Owned synthetic ~1000x1400 raster (solid fill, never Miller content).
// Generated inline with sharp - same idiom ../../test/build.test.js already
// uses for processImage fixtures - so no new binary PNG needs to be
// committed just for this test.
async function makeSamplePng(dir) {
  const png = await sharp({
    create: {
      width: 1000,
      height: 1400,
      channels: 3,
      background: { r: 180, g: 200, b: 210 },
    },
  })
    .png()
    .toBuffer();
  const out = path.join(dir, "sample-page.png");
  await writeFile(out, png);
  return out;
}

test("cropFigure extracts the bbox region and processImage takes it to WebP <=200KB", async () => {
  const dir = await mkdtemp(path.join(tmpdir(), "figures-"));
  const SAMPLE_PNG = await makeSamplePng(dir);
  const tmpOut = path.join(dir, "cropped.png");

  const cropped = await cropFigure(
    SAMPLE_PNG,
    { left: 100, top: 200, width: 400, height: 300 },
    tmpOut,
  );
  assert.equal(cropped, tmpOut);
  const meta = await sharp(cropped).metadata();
  assert.equal(meta.width, 400);
  assert.equal(meta.height, 300);
  const webp = await processImage(cropped); // reused from ../../src/build.js
  assert.ok(webp.length <= 204800);
});

test("renderPage renders one PDF page and returns the real (suffixed) path pdftoppm wrote, not the bare prefix", async () => {
  const dir = await mkdtemp(path.join(tmpdir(), "figures-render-"));
  const outPng = path.join(dir, "page.png");

  const rendered = await renderPage(SAMPLE_PDF, 2, outPng);

  assert.notEqual(
    rendered,
    outPng,
    "pdftoppm appends a page suffix - it never writes the bare prefix path",
  );
  assert.match(path.basename(rendered), /^page-0*2\.png$/);
  const meta = await sharp(rendered).metadata();
  assert.equal(meta.format, "png");
});
