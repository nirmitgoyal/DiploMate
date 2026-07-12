// Bounded-concurrency map. Before starting each item, shouldStop() is checked
// so the cost meter can halt scheduling; in-flight workers always finish.
export async function mapPool(
  items,
  concurrency,
  worker,
  shouldStop = () => false,
) {
  const results = new Array(items.length);
  let next = 0;
  async function run() {
    while (next < items.length) {
      if (shouldStop()) return;
      const i = next++;
      results[i] = await worker(items[i], i);
    }
  }
  await Promise.all(
    Array.from({ length: Math.min(concurrency, items.length) }, run),
  );
  return results;
}
