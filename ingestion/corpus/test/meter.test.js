import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createMeter, worstCaseCall } from "../src/meter.js";

test("meter accumulates spend and halts before the ceiling", () => {
  // rateOut 5 $/1M, ceiling $0.10. Each 15k-output call costs $0.075.
  const m = createMeter({ rateIn: 1, rateOut: 5, ceiling: 0.1 });
  const worst = worstCaseCall(2000, 5); // 2000/1e6*5 = $0.01

  m.add({ input_tokens: 1000, output_tokens: 15000 }); // total ~0.076
  assert.equal(m.wouldExceed(worst), false, "0.076 + 0.01 < 0.10");

  m.add({ input_tokens: 1000, output_tokens: 15000 }); // total ~0.151
  assert.equal(m.wouldExceed(worst), true, "0.151 exceeds 0.10");
  assert.ok(m.total() > 0.15);
});

test("createMeter throws when a rate is not finite (NaN would defeat the halt)", () => {
  assert.throws(() =>
    createMeter({ rateIn: 1, rateOut: undefined, ceiling: 90 }),
  );
});

test("wouldExceed halts on the exact ceiling boundary (>=, not >)", () => {
  // rateOut 2, 1e6 output tokens -> total exactly $2.0 (integer-clean).
  const m = createMeter({ rateIn: 1, rateOut: 2, ceiling: 3 });
  m.add({ input_tokens: 0, output_tokens: 1_000_000 });
  const worst = worstCaseCall(500_000, 2); // 0.5 * 2 = $1.0
  assert.equal(m.total() + worst, 3, "check lands exactly on the ceiling");
  assert.equal(m.wouldExceed(worst), true, ">= halts at equality; > would not");
});

test("persist then load round-trips spend to a fresh meter", async (t) => {
  const dir = await mkdtemp(join(tmpdir(), "meter-"));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const statePath = join(dir, "state.json");

  const a = createMeter({ rateIn: 1, rateOut: 5, ceiling: 90, statePath });
  a.add({ input_tokens: 1234, output_tokens: 5678 });
  await a.persist();

  const b = createMeter({ rateIn: 1, rateOut: 5, ceiling: 90, statePath });
  await b.load();
  assert.equal(b.total(), a.total());
  assert.deepEqual(b.tokens(), a.tokens());
});

test("load rejects (does not silently reset to 0) on a corrupt state file", async (t) => {
  const dir = await mkdtemp(join(tmpdir(), "meter-"));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const statePath = join(dir, "state.json");
  await writeFile(statePath, "{not json");

  const m = createMeter({ rateIn: 1, rateOut: 5, ceiling: 90, statePath });
  await assert.rejects(m.load());
  assert.equal(
    m.total(),
    0,
    "spend untouched, not silently reset past real data",
  );
});
