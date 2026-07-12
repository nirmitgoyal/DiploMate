import { test } from "node:test";
import assert from "node:assert/strict";
import {
  slugify,
  dedupeSlugs,
  canonicalizeChapters,
} from "../src/canonicalize.js";

test("slugify makes clean slugs from messy titles", () => {
  assert.equal(slugify("Airway Management"), "airway-management");
  assert.equal(
    slugify("1. Local Anaesthetics (Part II)"),
    "local-anaesthetics-part-ii",
  );
});

test("dedupeSlugs suffixes collisions deterministically", () => {
  const out = dedupeSlugs([
    { canonical: "Airway", slug: "airway" },
    { canonical: "Air-way", slug: "airway" },
  ]);
  assert.deepEqual(
    out.map((c) => c.slug),
    ["airway", "airway-2"],
  );
});

test("canonicalizeChapters merges synonyms via the model", async () => {
  const callModel = async () => ({
    Airway: "Airway Management",
    "Difficult Airway": "Airway Management",
    "Spinal Anaesthesia": "Spinal Anaesthesia",
  });
  const map = await canonicalizeChapters(
    ["Airway", "Difficult Airway", "Spinal Anaesthesia"],
    { callModel },
  );
  assert.equal(map.get("Airway"), "Airway Management");
  assert.equal(map.get("Difficult Airway"), "Airway Management");
});

// ADDITIVE TESTS - Data integrity guarantees

test("Model miss maps to self (never drops)", async () => {
  const callModel = async () => ({
    A: "Canon",
    B: "Canon",
    // C is deliberately omitted
  });
  const map = await canonicalizeChapters(["A", "B", "C"], { callModel });
  assert.equal(map.get("C"), "C", "missing title maps to itself");
  assert.equal(map.get("A"), "Canon");
  assert.equal(map.get("B"), "Canon");
});

test("Single/zero title short-circuits without calling the model", async () => {
  const throwingCallModel = () => {
    throw new Error("should not be called");
  };
  const mapOne = await canonicalizeChapters(["Solo"], {
    callModel: throwingCallModel,
  });
  assert.equal(mapOne.get("Solo"), "Solo");

  const mapEmpty = await canonicalizeChapters([], {
    callModel: throwingCallModel,
  });
  assert.equal(mapEmpty.size, 0);
});

test("Mixed natural/suffixed collision produces all-distinct slugs", () => {
  const out = dedupeSlugs([
    { canonical: "Airway", slug: "airway" },
    { canonical: "AirWay", slug: "airway" },
    { canonical: "Airway 2", slug: "airway-2" },
  ]);
  assert.equal(
    new Set(out.map((c) => c.slug)).size,
    3,
    "all three output slugs are distinct",
  );
});

test("Two identical raw titles short-circuit without the model", async () => {
  const callModel = () => {
    throw new Error("should not be called");
  };
  const map = await canonicalizeChapters(["Airway", "Airway"], { callModel });
  assert.equal(map.get("Airway"), "Airway");
});

test("Three-way slug collision", () => {
  const out = dedupeSlugs([
    { canonical: "Airway", slug: "airway" },
    { canonical: "Air way", slug: "airway" },
    { canonical: "Air-way", slug: "airway" },
  ]);
  assert.deepEqual(
    out.map((c) => c.slug),
    ["airway", "airway-2", "airway-3"],
  );
});
