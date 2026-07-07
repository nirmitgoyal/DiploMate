import { readdir, readFile } from "node:fs/promises";
import pg from "pg";

// The seeded Anaesthesiology row (sql/0002) - the beta content anchor.
export const TEST_SPECIALITY_ID = "01JZSP3C00DNB0000000000001";

// Rebuilds the disposable test database from zero with EVERY numbered
// migration, in filename order - the same contract tools/db/apply.sh
// enforces, so publish tests always run against the real current schema.
export async function testClient() {
  const client = new pg.Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  await client.query("DROP SCHEMA public CASCADE; CREATE SCHEMA public");
  const sqlDir = new URL("../../sql/", import.meta.url);
  const files = (await readdir(sqlDir))
    .filter((f) => /^\d{4}_.*\.sql$/.test(f))
    .sort();
  for (const f of files) {
    await client.query(await readFile(new URL(f, sqlDir), "utf8"));
  }
  return client;
}
