const { createApp } = require("./app");
const { makePool } = require("./db");
const { OAuth2Client } = require("google-auth-library");
const { makeVerifier, googleAudiences } = require("./lib/google");

const pool = makePool();

const realVerify = makeVerifier(
  new OAuth2Client(),
  googleAudiences(process.env),
);
// ponytail: dev-only auth bypass, gated behind DEV_FAKE_AUTH (absent in prod).
// Pairs with the app's --dart-define=DEV_FAKE_AUTH=true (FakeGoogleSignIn sends
// 'dev-fake-token'). Any other token still goes through real Google verification.
const verifyGoogleToken = process.env.DEV_FAKE_AUTH
  ? async (idToken) =>
      idToken === "dev-fake-token"
        ? {
            sub: "dev-fake-user",
            email: "dev@example.com",
            name: "Dev User",
            picture: null,
          }
        : realVerify(idToken)
  : realVerify;

const app = createApp({
  pool,
  verifyGoogleToken,
  secrets: JSON.parse(process.env.SESSION_JWT_SECRET || "{}"),
});

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`diplomate-server listening on ${port}`));
