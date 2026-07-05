import { readFile } from "node:fs/promises";
import pg from "pg";

// Applies the repo's real DDL to the disposable test database and seeds one
// speciality row (speciality ULIDs are owned by sql/0002 in prod; tests pin
// their own so this suite depends only on 0001).
export const TEST_SPECIALITY_ID = "01ARZ3NDEKTSV4RRFFQ69G5FAV";

export async function testClient() {
  const client = new pg.Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  await client.query(
    "DROP TABLE IF EXISTS images, qnas, topics, chapters, specialities, app_config CASCADE",
  );
  const ddl = await readFile(
    new URL("../../sql/0001_content_v0.sql", import.meta.url),
    "utf8",
  );
  await client.query(ddl);
  await client.query(
    `INSERT INTO specialities (id, name, exam_type, slug, sort_order)
     VALUES ($1, 'Anaesthesia', 'DNB', 'anaesthesia', 1)`,
    [TEST_SPECIALITY_ID],
  );
  return client;
}
