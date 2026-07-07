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
