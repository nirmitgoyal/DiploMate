import { test } from "node:test";
import assert from "node:assert/strict";
import { buildPageIndex, pageText } from "../src/page_index.js";
import { fileURLToPath } from "node:url";

const SAMPLE = fileURLToPath(
  new URL("../fixtures/sample-2page.pdf", import.meta.url),
);

test("page index has one entry per page and returns page text", async () => {
  const index = await buildPageIndex(SAMPLE);
  assert.equal(index.length, 2);
  assert.match(pageText(index, 1), /owned sample page one/i);
  assert.match(pageText(index, 2), /owned sample page two/i);
});
