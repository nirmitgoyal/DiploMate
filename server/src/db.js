const { Pool } = require("pg");

// Pool max 5: Essential-0 has ~20 connections; a release briefly runs
// old+new dynos, plus psql/ingestion/CI need headroom (D3 ops appendix).
function makePool(connectionString = process.env.DATABASE_URL) {
  return new Pool({
    connectionString,
    max: 5,
    ssl: connectionString?.includes("localhost")
      ? false
      : { rejectUnauthorized: false },
  });
}

module.exports = { makePool };
