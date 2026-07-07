import { test } from "node:test";
import assert from "node:assert/strict";
import { buildPageMap } from "../src/page_map.js";

// Synthetic index: printed labels that rise monotonically, then one volume
// boundary reset (front matter -> page 1 again), then a planted inversion.
const good = [
  { pdf_page: 1, text: "front matter ii" },
  { pdf_page: 2, text: "1\nchapter one" },
  { pdf_page: 3, text: "2\nchapter one cont" },
];
const inverted = [
  { pdf_page: 1, text: "1\na" },
  { pdf_page: 2, text: "5\nb" },
  { pdf_page: 3, text: "3\nc" }, // goes backwards -> flagged
];

test("monotonic map resolves book page to pdf page", () => {
  const map = buildPageMap(good, { volumes: [{ startPdfPage: 2 }] });
  assert.deepEqual(map.validate(), []);
  assert.equal(map.bookToPdf(1), 2);
  assert.equal(map.bookToPdf(2), 3);
});

test("a non-monotonic run is flagged, not silently mapped", () => {
  const map = buildPageMap(inverted, { volumes: [{ startPdfPage: 1 }] });
  assert.ok(map.validate().some((e) => /non-monotonic|decreas/i.test(e)));
});
