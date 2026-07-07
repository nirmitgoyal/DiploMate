import { test } from "node:test";
import assert from "node:assert/strict";
import { reconcile, dedupYears, examWeight } from "../src/ledger.js";

test("a typo-edited question reconciles to its existing ledger key (no re-key)", () => {
  const prev = [
    {
      key: "abcd1234abcd1234",
      paper: "2019-I",
      year: 2019,
      position: 3,
      text: "Define spinal anaesthesia.",
    },
  ];
  const extracted = [
    {
      paper: "2019-I",
      year: 2019,
      position: 3,
      text: "Define spinal anaesthesia",
    },
  ]; // trailing period gone
  const r = reconcile(extracted, {}, prev);
  assert.equal(
    r.matched[0].key,
    "abcd1234abcd1234",
    "provenance match wins - text edit must not re-key",
  );
  assert.equal(r.minted.length, 0);
});

test("a genuinely new question mints a fresh sha256-16 key", () => {
  const r = reconcile(
    [
      {
        paper: "2024-II",
        year: 2024,
        position: 1,
        text: "A brand new question about capnography.",
      },
    ],
    {},
    [],
  );
  assert.equal(r.matched.length, 0);
  assert.match(r.minted[0].key, /^[0-9a-f]{16}$/);
});

test("an ambiguous match (same provenance, very different text) queues for review", () => {
  const prev = [
    {
      key: "aaaa1111aaaa1111",
      paper: "2019-I",
      year: 2019,
      position: 3,
      text: "Define spinal anaesthesia.",
    },
  ];
  const extracted = [
    {
      paper: "2019-I",
      year: 2019,
      position: 3,
      text: "Describe the anatomy of the brachial plexus in full.",
    },
  ];
  const r = reconcile(extracted, {}, prev);
  assert.equal(
    r.ambiguous.length,
    1,
    "same slot, unrelated text -> human decides, never auto re-key",
  );
});

test("exam_weight sums year-appearances, not deduped count (amendment 8)", () => {
  // one question, 6 year-appearances -> contributes 6.
  assert.equal(
    examWeight([{ years: "2015, 2017, 2019, 2021, 2022, 2024" }]),
    6,
  );
  assert.equal(examWeight([{ years: "2019, 2022" }, { years: "2020" }]), 3);
});

// Not in the brief's transcribed set - dedupYears has real parsing/sort
// logic and feeds examWeight's input shape directly, so it gets one check.
test("dedupYears collapses repeated years to a sorted, unique, comma-joined string", () => {
  const clusters = [{ year: 2021 }, { year: 2019 }, { year: 2021 }];
  assert.equal(dedupYears(clusters), "2019, 2021");
});

// Fix wave 1: cross-slot (no exact provenance) is text-only, so a templated
// DNB stem must NOT auto-inherit a distinct question's key.
test("a templated cross-slot near-miss is NOT auto-reused (queues for review, never re-keys)", () => {
  const prev = [
    {
      key: "5p1na15p1na1000",
      paper: "2019-I",
      year: 2019,
      position: 3,
      text: "Define spinal anaesthesia.",
    },
  ];
  const extracted = [
    {
      paper: "2024-II",
      year: 2024,
      position: 7,
      text: "Define epidural anaesthesia.",
    }, // 0.85 similar - same template, DIFFERENT question
  ];
  const r = reconcile(extracted, {}, prev);
  assert.ok(
    r.matched.every((m) => m.key !== "5p1na15p1na1000"),
    "a distinct question must never silently absorb another's key on text alone",
  );
  assert.equal(
    r.ambiguous.length,
    1,
    "middle-band cross-slot -> human decides",
  );
  assert.equal(r.ambiguous[0].candidateKey, "5p1na15p1na1000");
});

// Proves the cross-slot branch still REUSES for a genuine verbatim repeat -
// the fix tightens the bar, it does not disable cross-slot dedup.
test("a genuine verbatim cross-slot reappearance reuses the existing key", () => {
  const prev = [
    {
      key: "abcd1234abcd1234",
      paper: "2019-I",
      year: 2019,
      position: 3,
      text: "Define spinal anaesthesia.",
    },
  ];
  const extracted = [
    {
      paper: "2022-II",
      year: 2022,
      position: 5,
      text: "Define spinal anaesthesia.",
    }, // same question, later paper -> verbatim reappearance
  ];
  const r = reconcile(extracted, {}, prev);
  assert.equal(r.matched.length, 1);
  assert.equal(r.matched[0].key, "abcd1234abcd1234");
  assert.equal(r.minted.length, 0);
  assert.equal(r.ambiguous.length, 0);
});

// Claim-tracking: two verbatim reappearances of one prev key in a single
// call - at most ONE may auto-reuse; the second collision goes to review.
test("a many-to-one key collision reuses once, routes the rest to review", () => {
  const prev = [
    {
      key: "abcd1234abcd1234",
      paper: "2019-I",
      year: 2019,
      position: 3,
      text: "Define spinal anaesthesia.",
    },
  ];
  const extracted = [
    {
      paper: "2022-II",
      year: 2022,
      position: 5,
      text: "Define spinal anaesthesia.",
    },
    {
      paper: "2023-I",
      year: 2023,
      position: 2,
      text: "Define spinal anaesthesia",
    }, // both normalize identical to prev -> both want the same key
  ];
  const r = reconcile(extracted, {}, prev);
  assert.equal(
    r.matched.filter((m) => m.key === "abcd1234abcd1234").length,
    1,
    "one key can be reused at most once per call",
  );
  assert.equal(r.ambiguous.length, 1, "the collision goes to review");
  assert.equal(r.ambiguous[0].candidateKey, "abcd1234abcd1234");
});
