const SYSTEM =
  "You are a senior DNB examiner writing concise, high-yield model answers " +
  "for postgraduate medical exam preparation. Answer only from established " +
  "medical knowledge. Be structured and exam-oriented.";

// Ask for STRICT JSON in the exact serve shape. We do not rely on Bedrock
// structured-output betas; we parse and validate the text ourselves.
export function buildPrompt({ speciality, question, marks }) {
  return [
    `Speciality: ${speciality}`,
    marks ? `Marks: ${marks}` : "",
    `Question: ${question}`,
    "",
    "Write a DNB model answer. Return ONLY a JSON object, no prose, no code",
    "fences, matching exactly:",
    "{",
    '  "chapter_title": "the single best chapter/topic this question belongs to",',
    '  "sections": [{ "key": "kebab-case", "heading": "Heading", "body_md": "markdown" }],',
    '  "earns_marks": [{ "label": "scoring point", "section_key": "matching section key" }]',
    "}",
    "Keep it concise enough to fit a 2000-token budget.",
  ]
    .filter(Boolean)
    .join("\n");
}

export function parseAnswer(text) {
  const cleaned = text
    .replace(/```json/gi, "")
    .replace(/```/g, "")
    .trim();
  try {
    return JSON.parse(cleaned);
  } catch {
    const s = cleaned.indexOf("{");
    const e = cleaned.lastIndexOf("}");
    if (s === -1 || e === -1) throw new Error("no JSON object found");
    return JSON.parse(cleaned.slice(s, e + 1));
  }
}

export function validateAnswer(obj) {
  const ok =
    obj &&
    typeof obj.chapter_title === "string" &&
    obj.chapter_title.trim() &&
    Array.isArray(obj.sections) &&
    obj.sections.length > 0 &&
    obj.sections.every(
      (s) =>
        s &&
        typeof s.key === "string" &&
        typeof s.heading === "string" &&
        typeof s.body_md === "string",
    ) &&
    Array.isArray(obj.earns_marks) &&
    obj.earns_marks.every(
      (m) =>
        m && typeof m.label === "string" && typeof m.section_key === "string",
    );
  if (!ok) throw new Error("answer failed schema validation");
  return obj;
}

export async function generateAnswer(
  { speciality, question, marks },
  {
    fetchImpl = fetch,
    token = process.env.AWS_BEARER_TOKEN_BEDROCK,
    region = process.env.AWS_REGION || "us-east-1",
    model = process.env.BEDROCK_MODEL_ID ||
      "us.anthropic.claude-haiku-4-5-20251001-v1:0",
    maxTokens = 2000,
  } = {},
) {
  const url = `https://bedrock-runtime.${region}.amazonaws.com/model/${encodeURIComponent(
    model,
  )}/invoke`;
  const messages = [
    { role: "user", content: buildPrompt({ speciality, question, marks }) },
  ];
  let usage = { input_tokens: 0, output_tokens: 0 };
  for (let attempt = 0; attempt < 2; attempt++) {
    const res = await fetchImpl(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        anthropic_version: "bedrock-2023-05-31",
        max_tokens: maxTokens,
        system: SYSTEM,
        messages,
      }),
    });
    if (!res.ok) throw new Error(`bedrock ${res.status}: ${await res.text()}`);
    const data = await res.json();
    const u = data.usage || {};
    usage = {
      input_tokens: usage.input_tokens + (u.input_tokens || 0),
      output_tokens: usage.output_tokens + (u.output_tokens || 0),
    };
    const text = (data.content || []).map((b) => b.text || "").join("");
    try {
      return { answer: validateAnswer(parseAnswer(text)), usage };
    } catch {
      if (attempt === 1) return { answer: null, usage, flag: "invalid-json" };
      // one corrective turn (regular multi-turn, not a prefill)
      messages.push({ role: "assistant", content: text });
      messages.push({
        role: "user",
        content: "That was not valid JSON. Return ONLY the JSON object.",
      });
    }
  }
}
