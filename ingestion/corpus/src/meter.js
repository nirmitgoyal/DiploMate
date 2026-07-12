import { readFile, writeFile, rename } from "node:fs/promises";

// Token accounting is exact; the $ rate is configurable because the real
// Bedrock Haiku price is masked. wouldExceed is checked BEFORE every dispatch
// so the run stops with margin, never overshooting the ceiling.
export function createMeter({ rateIn, rateOut, ceiling, statePath }) {
  if (![rateIn, rateOut, ceiling].every(Number.isFinite))
    throw new Error(
      "createMeter: rateIn, rateOut, ceiling must all be finite numbers",
    );
  let inTok = 0;
  let outTok = 0;
  const api = {
    add(usage) {
      const { input_tokens = 0, output_tokens = 0 } = usage ?? {};
      inTok += input_tokens;
      outTok += output_tokens;
    },
    total() {
      return (inTok / 1e6) * rateIn + (outTok / 1e6) * rateOut;
    },
    tokens() {
      return { inTok, outTok };
    },
    wouldExceed(worstCaseNextUsd) {
      return api.total() + worstCaseNextUsd >= ceiling;
    },
    async persist() {
      if (!statePath) return;
      const tmp = `${statePath}.tmp`;
      await writeFile(tmp, JSON.stringify({ inTok, outTok, usd: api.total() }));
      await rename(tmp, statePath);
    },
    async load() {
      if (!statePath) return;
      let raw;
      try {
        raw = await readFile(statePath, "utf8");
      } catch (e) {
        if (e.code === "ENOENT") return; // no prior state - fresh run
        throw e;
      }
      let s;
      try {
        s = JSON.parse(raw);
      } catch {
        throw new Error(
          `meter state file ${statePath} is corrupt; refusing to reset spend to 0. Inspect or delete it before re-running.`,
        );
      }
      inTok = s.inTok || 0;
      outTok = s.outTok || 0;
    },
  };
  return api;
}

export function worstCaseCall(maxTokens, rateOut) {
  return (maxTokens / 1e6) * rateOut;
}
