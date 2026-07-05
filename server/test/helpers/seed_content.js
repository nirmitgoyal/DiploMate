// Minimal content tree for endpoint tests - shaped exactly like the
// ingestion publisher's output. Safe to call repeatedly.
async function seedContent(pool) {
  const { rows } = await pool.query(
    `SELECT id FROM specialities WHERE slug = 'anaesthesiology'`,
  );
  const spec = rows[0].id;
  await pool.query(
    `
    INSERT INTO chapters (id, speciality_id, title, slug, sort_order, exam_weight, content_version)
    VALUES ('CH1', $1, 'Airway Management', 'airway-management', 1, 100, 1)
    ON CONFLICT (id) DO NOTHING`,
    [spec],
  );
  await pool.query(`
    INSERT INTO topics (id, chapter_id, title, slug, exam_theme, sort_order)
    VALUES ('TP1', 'CH1', 'Difficult airway', 'difficult-airway', 'Emergencies', 1)
    ON CONFLICT (id) DO NOTHING`);
  await pool.query(`
    INSERT INTO qnas (id, topic_id, question, years, marks, earns_marks, sections, sort_order)
    VALUES
      ('QN1', 'TP1', 'Outline the difficult airway algorithm.', '2021 Paper I', 10,
       '[{"label":"Definition","section_key":"definition"}]',
       '[{"key":"definition","heading":"Definition","body_md":"A clinical situation...","marks":2}]', 1),
      ('QN2', 'TP1', 'Describe rapid sequence induction.', '2019', 5,
       '[]', '[{"key":"summary","heading":"Summary","body_md":"Speed matters.","marks":null}]', 2)
    ON CONFLICT (id) DO NOTHING`);
  await pool.query(`
    INSERT INTO images (id, qna_id, caption, content_description, webp, byte_size, sha256, sort_order)
    VALUES ('IM1', 'QN1', 'Fig 1 - algorithm', 'Flowchart of the difficult airway algorithm',
            decode('52494646', 'hex'), 4, 'abc123', 1)
    ON CONFLICT (id) DO NOTHING`);
  return { spec };
}

module.exports = { seedContent };
