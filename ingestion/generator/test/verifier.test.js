import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { verifyQuote, normalize } from "../src/verifier.js";

const idx = (pages) => pages.map((text, i) => ({ pdf_page: i + 1, text }));
const map = { bookToPdf: (n) => n, validate: () => [] };

test("plain exact substring verifies against its page", () => {
  const index = idx(["The trachea bifurcates at the carina."]);
  const r = verifyQuote("The trachea bifurcates at the carina.", {
    index,
    map,
    bookPage: 1,
  });
  assert.equal(r.ok, true);
  assert.equal(r.citationPage, 1);
});

test("EOL hyphenation is joined before matching", () => {
  const index = idx(["The laryn-\ngoscope blade is inserted."]);
  const r = verifyQuote("The laryngoscope blade is inserted.", {
    index,
    map,
    bookPage: 1,
  });
  assert.equal(r.ok, true);
});

test("soft hyphens are stripped", () => {
  const index = idx(["Pre­oxygenation is essential."]);
  assert.equal(
    verifyQuote("Preoxygenation is essential.", { index, map, bookPage: 1 }).ok,
    true,
  );
});

// The two-column interleave / caption-injection / table-linearization rules
// are calibrated on REAL Miller scans during the pilot (Task 0 step 3), so
// their cases are data-driven from a committed fixture rather than guessed
// here. The fixture carries {pageText, quote, expectOk} triples the pilot
// recorded; it starts EMPTY (this test is skipped until the pilot populates
// it), so there is never a synthetic always-pass standing in for a real case.
test("pilot-cataloged layout cases verify as recorded", async () => {
  const cases = JSON.parse(
    await readFile(new URL("../fixtures/layout_cases.json", import.meta.url)),
  );
  if (cases.length === 0) return; // populated by Task 0 step 3; skip until then
  for (const c of cases) {
    const r = verifyQuote(c.quote, {
      index: idx([c.pageText]),
      map,
      bookPage: 1,
    });
    assert.equal(r.ok, c.expectOk, `layout case "${c.name}"`);
  }
});

test("a quote spanning a page break verifies via N||N+1 and cites a range", () => {
  const index = idx([
    "...ends at the end of page one ",
    "and continues on page two.",
  ]);
  const r = verifyQuote("end of page one and continues on page two.", {
    index,
    map,
    bookPage: 1,
  });
  assert.equal(r.ok, true);
  assert.equal(r.citationRange, "1-2");
});

test("no whitespace at the page boundary still verifies via N||N+1 (fusion guard)", () => {
  const index = idx([
    "...ends at the end of page one", // no trailing whitespace before the break
    "and continues on page two.", // no leading whitespace after the break
  ]);
  const r = verifyQuote("end of page one and continues on page two.", {
    index,
    map,
    bookPage: 1,
  });
  assert.equal(
    r.ok,
    true,
    "the page-break separator must stand in for the missing whitespace",
  );
  assert.equal(r.citationRange, "1-2");
});

test("a quote absent from the page fails with quote-verification-failed", () => {
  const index = idx(["Nothing relevant here."]);
  const r = verifyQuote("This sentence is not in the book.", {
    index,
    map,
    bookPage: 1,
  });
  assert.equal(r.ok, false);
  assert.equal(r.reason, "quote-verification-failed");
});

test("normalize joins EOL hyphenation and strips soft hyphens", () => {
  assert.equal(normalize("laryn-\ngoscope"), "laryngoscope");
  assert.equal(normalize("Pre­oxygenation"), "Preoxygenation");
});

test("an empty or whitespace-only quote never verifies", () => {
  const index = idx(["The trachea bifurcates at the carina."]);
  const empty = verifyQuote("", { index, map, bookPage: 1 });
  assert.equal(empty.ok, false);
  assert.equal(empty.reason, "quote-verification-failed");
  const ws = verifyQuote("  \n ", { index, map, bookPage: 1 });
  assert.equal(ws.ok, false);
  assert.equal(ws.reason, "quote-verification-failed");
});
