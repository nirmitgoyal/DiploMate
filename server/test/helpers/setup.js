const { makePool } = require("../../src/db");

let pool;
function testPool() {
  pool ??= makePool(process.env.TEST_DATABASE_URL);
  return pool;
}

// Wipe mutable data between tests; content + specialities are seed-stable.
async function resetUserData(p = testPool()) {
  await p.query(
    `TRUNCATE users, entitlements, review_events, app_events, bookmarks, reports CASCADE`,
  );
  await p.query(
    `UPDATE app_config SET value = 'true' WHERE key = 'beta_active'`,
  );
}

module.exports = { testPool, resetUserData };
