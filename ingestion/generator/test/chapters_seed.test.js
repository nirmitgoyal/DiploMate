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

test("parseToc reads title + book page from TOC lines", () => {
  const toc =
    "1. The Scope of Modern Anesthetic Practice ..... 3\n19. Pulmonary Pharmacology ..... 512";
  const rows = parseToc(toc);
  assert.equal(rows[0].title, "The Scope of Modern Anesthetic Practice");
  assert.equal(rows[0].sort_order, 1);
  assert.equal(rows[0].book_page_start, 3);
});
