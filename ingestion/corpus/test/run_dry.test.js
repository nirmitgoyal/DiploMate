import { test } from "node:test";
import assert from "node:assert/strict";
import { processSpeciality } from "../src/run.js";

test("processSpeciality generates, canonicalizes, and publishes idempotently", async () => {
  const rows = [
    {
      key: "k1",
      speciality_slug: "anatomy",
      question: "Q1?",
      years: "2020",
      marks: 10,
    },
    {
      key: "k2",
      speciality_slug: "anatomy",
      question: "Q2?",
      years: "2021",
      marks: 10,
    },
  ];
  const published = [];
  const deps = {
    specialityName: "Anatomy",
    getSpecialityId: async () => "SPEC1",
    getExistingQnaIds: async () => new Set(),
    generate: async ({ question }) => ({
      answer: {
        chapter_title: question === "Q1?" ? "Upper Limb" : "Upper limb",
        sections: [{ key: "s", heading: "S", body_md: "b" }],
        earns_marks: [{ label: "L", section_key: "s" }],
      },
      usage: { input_tokens: 50, output_tokens: 100 },
    }),
    canonicalize: async (titles) =>
      new Map(titles.map((t) => [t, "Upper Limb"])), // merge the two casings
    upsertChapter: async (_c, _s, _title, slug) => `ch-${slug}`,
    insertQna: async (_c, q) => published.push(q.key),
    meter: {
      add() {},
      wouldExceed: () => false,
      total: () => 0.001,
    },
  };
  const r = await processSpeciality(null, "anatomy", rows, deps);
  assert.equal(r.published, 2);
  assert.equal(r.flagged, 0);
  assert.deepEqual(published.sort(), ["k1", "k2"]);
});

test("processSpeciality stops publishing new work when the meter would exceed", async () => {
  const rows = [
    { key: "k1", speciality_slug: "anatomy", question: "Q1?", years: "2020" },
  ];
  const deps = {
    specialityName: "Anatomy",
    getSpecialityId: async () => "SPEC1",
    getExistingQnaIds: async () => new Set(),
    generate: async () => ({ answer: null, usage: {}, flag: "invalid-json" }),
    canonicalize: async (t) => new Map(t.map((x) => [x, x])),
    upsertChapter: async () => "ch",
    insertQna: async () => {},
    meter: { add() {}, wouldExceed: () => true, total: () => 999 },
  };
  const r = await processSpeciality(null, "anatomy", rows, deps);
  assert.equal(r.spendStopped, true);
  assert.equal(r.published, 0);
});

test("processSpeciality contains a transport-error throw from generate (does not abort the batch)", async () => {
  const rows = [
    { key: "k1", speciality_slug: "anatomy", question: "Q1?", years: "2020" },
  ];
  const deps = {
    specialityName: "Anatomy",
    getSpecialityId: async () => "SPEC1",
    getExistingQnaIds: async () => new Set(),
    generate: async () => {
      throw new Error("bedrock 429: throttled");
    },
    canonicalize: async (t) => new Map(t.map((x) => [x, x])),
    upsertChapter: async () => "ch",
    insertQna: async () => {},
    meter: { add() {}, wouldExceed: () => false, total: () => 0 },
  };
  const r = await processSpeciality(null, "anatomy", rows, deps);
  assert.equal(r.flagged, 1);
  assert.equal(r.published, 0);
});

test("processSpeciality skips generation for qnas already published (resume idempotency)", async () => {
  const rows = [
    { key: "k1", speciality_slug: "anatomy", question: "Q1?", years: "2020" },
    { key: "k2", speciality_slug: "anatomy", question: "Q2?", years: "2021" },
  ];
  const seen = [];
  const published = [];
  const deps = {
    specialityName: "Anatomy",
    getSpecialityId: async () => "SPEC1",
    getExistingQnaIds: async () => new Set(["k1"]), // k1 already done
    generate: async ({ question }) => {
      seen.push(question);
      return {
        answer: {
          chapter_title: "Upper Limb",
          sections: [{ key: "s", heading: "S", body_md: "b" }],
          earns_marks: [],
        },
        usage: { input_tokens: 10, output_tokens: 20 },
      };
    },
    canonicalize: async (t) => new Map(t.map((x) => [x, x])),
    upsertChapter: async () => "ch",
    insertQna: async (_c, q) => published.push(q.key),
    meter: { add() {}, wouldExceed: () => false, total: () => 0 },
  };
  const r = await processSpeciality(null, "anatomy", rows, deps);
  assert.ok(
    !seen.includes("Q1?"),
    "already-published k1 must NOT be generated",
  );
  assert.deepEqual(seen, ["Q2?"]);
  assert.equal(r.published, 1);
  assert.deepEqual(published, ["k2"]);
});
