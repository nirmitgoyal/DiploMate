import { test } from "node:test";
import assert from "node:assert/strict";
import { testClient, TEST_SPECIALITY_ID } from "../../test/db.js";
import {
  id16,
  getSpecialityId,
  getExistingQnaIds,
  upsertChapter,
  insertQna,
} from "../src/publish.js";

const skip =
  !process.env.DATABASE_URL &&
  "set DATABASE_URL (disposable) for publish tests";

test("chapter + qna writes are idempotent", { skip }, async () => {
  const client = await testClient(); // applies sql/0001..0004, seeds specialities
  try {
    const specId = await getSpecialityId(client, "anaesthesiology");
    assert.equal(specId, TEST_SPECIALITY_ID);

    const chId = await upsertChapter(
      client,
      specId,
      "Airway Management",
      "airway-management",
    );
    const chId2 = await upsertChapter(
      client,
      specId,
      "Airway Management",
      "airway-management",
    );
    assert.equal(
      chId,
      chId2,
      "same (speciality, slug) -> same deterministic id",
    );

    const qna = {
      key: id16("q|airway"),
      chapterId: chId,
      question: "Discuss difficult airway.",
      years: "2019, 2022",
      marks: 10,
      earnsMarks: [{ label: "Plan", section_key: "plan" }],
      sections: [{ key: "plan", heading: "Plan", body_md: "..." }],
    };
    await insertQna(client, qna);
    await insertQna(client, qna); // second insert must not duplicate

    const chapters = await client.query(
      "SELECT count(*)::int n FROM chapters WHERE id = $1",
      [chId],
    );
    const qnas = await client.query(
      "SELECT count(*)::int n FROM qnas WHERE id = $1",
      [qna.key],
    );
    assert.equal(chapters.rows[0].n, 1);
    assert.equal(qnas.rows[0].n, 1);
  } finally {
    await client.end();
  }
});

test(
  "getExistingQnaIds returns published qna keys for a speciality",
  { skip },
  async () => {
    const client = await testClient();
    try {
      const specId = await getSpecialityId(client, "anaesthesiology");
      const chId = await upsertChapter(
        client,
        specId,
        "Airway Management",
        "airway-management",
      );
      const key = id16("q|existing-ids-test");
      await insertQna(client, {
        key,
        chapterId: chId,
        question: "Existing ids question.",
        years: "2023",
        marks: 5,
        earnsMarks: [],
        sections: [{ key: "s", heading: "S", body_md: "b" }],
      });
      const ids = await getExistingQnaIds(client, specId);
      assert.ok(ids instanceof Set);
      assert.ok(ids.has(key), "published qna key must be reported as existing");
    } finally {
      await client.end();
    }
  },
);

test("unknown speciality returns null", { skip }, async () => {
  const client = await testClient();
  try {
    const specId = await getSpecialityId(client, "no-such-slug");
    assert.equal(specId, null);
  } finally {
    await client.end();
  }
});

test("JSONB round-trip", { skip }, async () => {
  const client = await testClient();
  try {
    const specId = await getSpecialityId(client, "anaesthesiology");
    const chId = await upsertChapter(
      client,
      specId,
      "Airway Management",
      "airway-management",
    );

    const qna = {
      key: id16("q|jsonb-test"),
      chapterId: chId,
      question: "Test question.",
      years: "2024",
      marks: 5,
      earnsMarks: [{ label: "Plan", section_key: "plan" }],
      sections: [{ key: "plan", heading: "Plan", body_md: "Test body" }],
    };
    await insertQna(client, qna);

    const result = await client.query(
      "SELECT sections->0->>'heading' AS h, earns_marks->0->>'label' AS l FROM qnas WHERE id=$1",
      [qna.key],
    );
    assert.equal(result.rows[0].h, "Plan");
    assert.equal(result.rows[0].l, "Plan");
  } finally {
    await client.end();
  }
});
