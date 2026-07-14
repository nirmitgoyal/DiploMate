const test = require("node:test");
const assert = require("node:assert");
const { makeVerifier, googleAudiences } = require("../src/lib/google");

// Fake OAuth2Client mimicking google-auth-library's aud check: a token verifies
// only if its `aud` is one of the configured audiences (string OR array), else
// it throws the same "Wrong recipient" error the real library throws.
function fakeClient() {
  return {
    async verifyIdToken({ idToken, audience }) {
      const payload = JSON.parse(idToken); // fake token = JSON with an `aud`
      const auds = Array.isArray(audience) ? audience : [audience];
      if (!auds.includes(payload.aud)) {
        throw new Error(
          "Wrong recipient, payload audience != requiredAudience",
        );
      }
      return {
        getPayload: () => ({
          sub: payload.sub,
          email: payload.email,
          name: null,
          picture: null,
        }),
      };
    },
  };
}

const WEB = "web-client.apps.googleusercontent.com";
const IOS = "ios-client.apps.googleusercontent.com";
const ANDROID = "android-client.apps.googleusercontent.com";

test("googleAudiences: collects configured client ids, drops falsy, keeps order", () => {
  assert.deepStrictEqual(
    googleAudiences({
      GOOGLE_WEB_CLIENT_ID: WEB,
      GOOGLE_IOS_CLIENT_ID: IOS,
      GOOGLE_ANDROID_CLIENT_ID: ANDROID,
    }),
    [WEB, IOS, ANDROID],
  );
  assert.deepStrictEqual(googleAudiences({ GOOGLE_WEB_CLIENT_ID: WEB }), [WEB]);
  assert.deepStrictEqual(
    googleAudiences({
      GOOGLE_WEB_CLIENT_ID: WEB,
      GOOGLE_IOS_CLIENT_ID: "",
      GOOGLE_ANDROID_CLIENT_ID: undefined,
    }),
    [WEB],
  );
});

// The exact production bug: iOS mints an ID token whose `aud` is the iOS client
// id, never the web id. Verifying against the web id alone rejects every iOS
// sign-in with "Wrong recipient".
test("iOS-aud token: rejected when only web configured, accepted once iOS is added", async () => {
  const iosToken = JSON.stringify({ aud: IOS, sub: "s-ios", email: "a@b.c" });

  const webOnly = makeVerifier(
    fakeClient(),
    googleAudiences({ GOOGLE_WEB_CLIENT_ID: WEB }),
  );
  await assert.rejects(() => webOnly(iosToken), /Wrong recipient/);

  const multi = makeVerifier(
    fakeClient(),
    googleAudiences({ GOOGLE_WEB_CLIENT_ID: WEB, GOOGLE_IOS_CLIENT_ID: IOS }),
  );
  const g = await multi(iosToken);
  assert.strictEqual(g.sub, "s-ios");
  assert.strictEqual(g.email, "a@b.c");
});

test("web-aud token still verifies under the multi-audience array", async () => {
  const webToken = JSON.stringify({ aud: WEB, sub: "s-web" });
  const v = makeVerifier(
    fakeClient(),
    googleAudiences({ GOOGLE_WEB_CLIENT_ID: WEB, GOOGLE_IOS_CLIENT_ID: IOS }),
  );
  assert.strictEqual((await v(webToken)).sub, "s-web");
});

test("token for a client id outside our project is still rejected", async () => {
  const alienToken = JSON.stringify({
    aud: "attacker.apps.googleusercontent.com",
    sub: "x",
  });
  const v = makeVerifier(
    fakeClient(),
    googleAudiences({ GOOGLE_WEB_CLIENT_ID: WEB, GOOGLE_IOS_CLIENT_ID: IOS }),
  );
  await assert.rejects(() => v(alienToken), /Wrong recipient/);
});
