import { test } from "node:test";
import assert from "node:assert/strict";
import {
  parseToc,
  slugify,
  dedupeSlugs,
  precheckUnique,
} from "../src/chapters_seed.js";

test("slugify produces SLUG_RE-valid slugs from messy titles", () => {
  assert.equal(
    slugify("1. The Scope of Modern Anesthetic Practice"),
    "the-scope-of-modern-anesthetic-practice",
  );
  assert.equal(
    slugify("Pharmacology of Local Anaesthetics (Part II)"),
    "pharmacology-of-local-anaesthetics-part-ii",
  );
  assert.match(
    slugify("Cardiovascular Physiology & Anaesthesia"),
    /^[a-z0-9]+(-[a-z0-9]+)*$/,
  );
});

test("two titles slugifying identically get a deterministic -2 suffix", () => {
  const out = dedupeSlugs([
    { title: "Airway Management", slug: "airway-management" },
    { title: "Airway Management", slug: "airway-management" },
  ]);
  assert.deepEqual(
    out.map((c) => c.slug),
    ["airway-management", "airway-management-2"],
  );
});

test("precheck catches a collision before emit (not at publish)", () => {
  assert.deepEqual(precheckUnique(["a", "b", "a"]), ["a"]);
});

// Fix wave 1: a punctuation-only / N.-only OCR-garbled TOC title slugifies
// to "" (SLUG_RE-invalid). dedupe/precheck compare equality, never format,
// so an empty slug would sail through to emit - surface it loudly at Stage 0.
test("slugify throws on a title with no slug-able characters (not a silent empty)", () => {
  assert.throws(() => slugify("&&&"), /&&&/);
  assert.throws(() => slugify(""));
  assert.throws(() => slugify("5.")); // leading-N. strip leaves nothing
});

// Fix wave 1: dedupe must skip PAST a pre-existing literal, not blindly
// append the running count - otherwise the deduper itself emits a duplicate.
test("dedupe skips a pre-existing literal instead of colliding with it", () => {
  const out = dedupeSlugs([{ slug: "x" }, { slug: "x-2" }, { slug: "x" }]);
  const slugs = out.map((c) => c.slug);
  assert.deepEqual(slugs, ["x", "x-2", "x-3"]);
  assert.equal(new Set(slugs).size, slugs.length, "no duplicate slug emitted");
});

test("parseToc reads title + book page from TOC lines", () => {
  const toc =
    "1. The Scope of Modern Anesthetic Practice ..... 3\n19. Pulmonary Pharmacology ..... 512";
  const rows = parseToc(toc);
  assert.equal(rows[0].title, "The Scope of Modern Anesthetic Practice");
  assert.equal(rows[0].sort_order, 1);
  assert.equal(rows[0].book_page_start, 3);
});
