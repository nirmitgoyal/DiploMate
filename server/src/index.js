const { createApp } = require("./app");
const { makePool } = require("./db");
const { OAuth2Client } = require("google-auth-library");
const { makeVerifier } = require("./lib/google");

const pool = makePool();
const app = createApp({
  pool,
  verifyGoogleToken: makeVerifier(
    new OAuth2Client(),
    process.env.GOOGLE_WEB_CLIENT_ID,
  ),
  secrets: JSON.parse(process.env.SESSION_JWT_SECRET || "{}"),
});

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`diplomate-server listening on ${port}`));
