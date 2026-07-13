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

test("canonicalizeChapters builds a taxonomy then classifies titles into it", async () => {
  const buildTaxonomy = async () => ["Airway Management", "Spinal Anaesthesia"];
  const classify = async (batch) =>
    Object.fromEntries(
      batch.map((t) => [
        t,
        /airway/i.test(t) ? "Airway Management" : "Spinal Anaesthesia",
      ]),
    );
  const map = await canonicalizeChapters(
    ["Difficult Airway", "Airway Assessment", "Spinal Block"],
    { buildTaxonomy, classify },
  );
  assert.equal(map.get("Difficult Airway"), "Airway Management");
  assert.equal(map.get("Airway Assessment"), "Airway Management");
  assert.equal(map.get("Spinal Block"), "Spinal Anaesthesia");
  assert.equal(new Set(map.values()).size, 2, "3 titles -> 2 chapters");
});

test("canonicalizeChapters classifies in output-bounded batches", async () => {
  const calls = [];
  const buildTaxonomy = async () => ["Chapter A", "Chapter B"];
  const classify = async (batch) => {
    calls.push([...batch]);
    return Object.fromEntries(batch.map((t) => [t, "Chapter A"]));
  };
  const titles = ["t1", "t2", "t3", "t4", "t5"];
  const map = await canonicalizeChapters(titles, {
    buildTaxonomy,
    classify,
    batchSize: 2,
  });
  assert.ok(calls.length >= 3, "classified in batches of <= 2");
  assert.ok(
    calls.every((b) => b.length <= 2),
    "no batch exceeds batchSize",
  );
  assert.equal(new Set(map.values()).size, 1);
});

// ADDITIVE TESTS - Data integrity guarantees

test("a title the model fails to place keeps its own title (never drops)", async () => {
  const buildTaxonomy = async () => ["Known Chapter"];
  // classify gives a bogus (non-taxonomy) chapter for B and omits C entirely
  const classify = async () => ({ A: "Known Chapter", B: "Not In Taxonomy" });
  const map = await canonicalizeChapters(["A", "B", "C"], {
    buildTaxonomy,
    classify,
  });
  assert.equal(map.get("A"), "Known Chapter");
  assert.equal(map.get("B"), "B", "bogus assignment -> keep own title");
  assert.equal(map.get("C"), "C", "unassigned -> keep own title");
});

test("empty taxonomy falls back to identity (never drops)", async () => {
  const buildTaxonomy = async () => [];
  const classify = async () => {
    throw new Error("should not classify without a taxonomy");
  };
  const map = await canonicalizeChapters(["A", "B"], {
    buildTaxonomy,
    classify,
  });
  assert.equal(map.get("A"), "A");
  assert.equal(map.get("B"), "B");
});

test("single/zero title short-circuits without calling the model", async () => {
  const boom = () => {
    throw new Error("should not be called");
  };
  const mapOne = await canonicalizeChapters(["Solo"], {
    buildTaxonomy: boom,
    classify: boom,
  });
  assert.equal(mapOne.get("Solo"), "Solo");

  const mapEmpty = await canonicalizeChapters([], {
    buildTaxonomy: boom,
    classify: boom,
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

test("two identical raw titles short-circuit without the model", async () => {
  const boom = () => {
    throw new Error("should not be called");
  };
  const map = await canonicalizeChapters(["Airway", "Airway"], {
    buildTaxonomy: boom,
    classify: boom,
  });
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
