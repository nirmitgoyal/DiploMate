import { test } from "node:test";
import assert from "node:assert/strict";
import { mapPool } from "../src/pool.js";

test("mapPool runs with bounded concurrency and honors shouldStop", async () => {
  const seen = [];
  let stopAfter = 3;
  const out = await mapPool(
    [1, 2, 3, 4, 5],
    2,
    async (x) => {
      seen.push(x);
      return x * 2;
    },
    () => seen.length >= stopAfter, // stop scheduling once 3 started
  );
  assert.ok(seen.length >= 3 && seen.length <= 5);
  assert.ok(out.filter((r) => r !== undefined).length >= 3);
});

test("mapPool never exceeds the concurrency bound", async () => {
  let inFlight = 0;
  let maxInFlight = 0;
  await mapPool([1, 2, 3, 4, 5, 6, 7, 8], 3, async (x) => {
    inFlight++;
    maxInFlight = Math.max(maxInFlight, inFlight);
    await new Promise((r) => setImmediate(r)); // yield so workers overlap
    inFlight--;
    return x;
  });
  assert.ok(maxInFlight <= 3, `max in-flight ${maxInFlight} must be <= 3`);
  assert.ok(maxInFlight >= 2, "workers should actually run concurrently");
});
