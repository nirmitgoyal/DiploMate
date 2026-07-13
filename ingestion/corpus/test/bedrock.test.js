import { test } from "node:test";
import assert from "node:assert/strict";
import {
  generateAnswer,
  validateAnswer,
  parseAnswer,
  callJson,
} from "../src/bedrock.js";

const VALID = {
  chapter_title: "Airway Management",
  sections: [{ key: "definition", heading: "Definition", body_md: "..." }],
  earns_marks: [{ label: "Defines airway", section_key: "definition" }],
};

function fakeFetch(
  payloadText,
  usage = { input_tokens: 100, output_tokens: 200 },
) {
  return async () => ({
    ok: true,
    json: async () => ({
      content: [{ type: "text", text: payloadText }],
      usage,
    }),
  });
}

test("generateAnswer parses valid JSON and returns usage", async () => {
  const r = await generateAnswer(
    { speciality: "Anaesthesiology", question: "Difficult airway?", marks: 10 },
    { fetchImpl: fakeFetch(JSON.stringify(VALID)), token: "x" },
  );
  assert.equal(r.answer.chapter_title, "Airway Management");
  assert.equal(r.usage.output_tokens, 200);
  assert.equal(r.flag, undefined);
});

test("generateAnswer flags after two invalid responses and sums usage", async () => {
  const r = await generateAnswer(
    { speciality: "X", question: "?", marks: 5 },
    { fetchImpl: fakeFetch("not json at all"), token: "x" },
  );
  assert.equal(r.answer, null);
  assert.equal(r.flag, "invalid-json");
  // both failed attempts were billed; usage must be the sum of the two calls
  assert.equal(r.usage.input_tokens, 200);
  assert.equal(r.usage.output_tokens, 400);
});

test("generateAnswer retries a 429 with backoff then succeeds", async () => {
  let calls = 0;
  const fetchImpl = async () => {
    calls++;
    if (calls === 1) {
      return {
        ok: false,
        status: 429,
        headers: { get: () => null },
        text: async () => "throttled",
      };
    }
    return {
      ok: true,
      json: async () => ({
        content: [{ type: "text", text: JSON.stringify(VALID) }],
        usage: { input_tokens: 100, output_tokens: 200 },
      }),
    };
  };
  const r = await generateAnswer(
    { speciality: "X", question: "?", marks: 5 },
    { fetchImpl, token: "x", retryBaseMs: 1 },
  );
  assert.equal(calls, 2, "retried after the 429");
  assert.equal(r.answer.chapter_title, "Airway Management");
  assert.equal(r.flag, undefined);
});

test("generateAnswer gives up (throws) on a non-retryable 4xx", async () => {
  const fetchImpl = async () => ({
    ok: false,
    status: 400,
    headers: { get: () => null },
    text: async () => "bad request",
  });
  await assert.rejects(
    generateAnswer(
      { speciality: "X", question: "?", marks: 5 },
      { fetchImpl, token: "x", retryBaseMs: 1 },
    ),
    /bedrock 400/,
  );
});

test("callJson parses a bare JSON array and returns usage", async () => {
  const fetchImpl = async () => ({
    ok: true,
    json: async () => ({
      content: [{ type: "text", text: '["A","B","C"]' }],
      usage: { input_tokens: 10, output_tokens: 5 },
    }),
  });
  const r = await callJson("prompt", { fetchImpl, token: "x" });
  assert.deepEqual(r.value, ["A", "B", "C"]);
  assert.equal(r.usage.output_tokens, 5);
});

test("callJson salvages a JSON object wrapped in fences/prose", async () => {
  const fetchImpl = async () => ({
    ok: true,
    json: async () => ({
      content: [
        { type: "text", text: 'Here:\n```json\n{"t1":"Chapter A"}\n```' },
      ],
      usage: {},
    }),
  });
  const r = await callJson("p", { fetchImpl, token: "x" });
  assert.deepEqual(r.value, { t1: "Chapter A" });
});

test("callJson returns null value on unparseable text", async () => {
  const fetchImpl = async () => ({
    ok: true,
    json: async () => ({
      content: [{ type: "text", text: "no json here" }],
      usage: {},
    }),
  });
  const r = await callJson("p", { fetchImpl, token: "x" });
  assert.equal(r.value, null);
});

test("validateAnswer rejects every invalid shape", () => {
  assert.throws(() => validateAnswer({ ...VALID, chapter_title: "" }));
  assert.throws(() => validateAnswer({ ...VALID, sections: "x" }));
  assert.throws(() => validateAnswer({ ...VALID, sections: [] }));
  assert.throws(() =>
    validateAnswer({ ...VALID, sections: [{ key: "k", heading: "h" }] }),
  );
  assert.throws(() => validateAnswer({ ...VALID, earns_marks: "x" }));
  assert.throws(() =>
    validateAnswer({ ...VALID, earns_marks: [{ label: "l" }] }),
  );
});

test("parseAnswer strips markdown code fences", () => {
  const fencedJson = `\`\`\`json
${JSON.stringify(VALID)}
\`\`\``;
  const parsed = parseAnswer(fencedJson);
  assert.deepEqual(parsed, VALID);
});

test("parseAnswer recovers JSON from surrounding prose", () => {
  const proseWithJson = `Here is your answer: ${JSON.stringify(VALID)} done`;
  const parsed = parseAnswer(proseWithJson);
  assert.deepEqual(parsed, VALID);
});

test("generateAnswer retries on invalid JSON then succeeds, summing usage and sending the corrective turn", async () => {
  let callCount = 0;
  let secondBody = null;
  const statefulFetch = async (_url, opts) => {
    callCount++;
    if (callCount === 1) {
      return {
        ok: true,
        json: async () => ({
          content: [{ type: "text", text: "not valid json" }],
          usage: { input_tokens: 100, output_tokens: 50 },
        }),
      };
    } else {
      secondBody = JSON.parse(opts.body);
      return {
        ok: true,
        json: async () => ({
          content: [{ type: "text", text: JSON.stringify(VALID) }],
          usage: { input_tokens: 100, output_tokens: 200 },
        }),
      };
    }
  };

  const r = await generateAnswer(
    { speciality: "Anaesthesiology", question: "Test?", marks: 10 },
    { fetchImpl: statefulFetch, token: "x" },
  );
  assert.equal(r.answer.chapter_title, "Airway Management");
  assert.equal(r.flag, undefined);
  assert.equal(callCount, 2);
  // usage must be the SUM of both billed attempts, not just the last one
  assert.equal(r.usage.input_tokens, 200);
  assert.equal(r.usage.output_tokens, 250);
  // the corrective turn was actually sent: original user + assistant + reprompt
  assert.equal(secondBody.messages.length, 3);
});
