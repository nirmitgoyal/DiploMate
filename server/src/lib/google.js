// Stock google-auth-library verification - never hand-rolled (D5).
// Rejects wrong-aud and expired Google ID tokens by throwing.
// `audience` may be a single client id or an ARRAY of them: iOS mints ID tokens
// whose `aud` is the iOS client id (never the web id), so the API must accept
// every native client id of this GCP project, not just the web one (D5).
function makeVerifier(oauthClient, audience) {
  return async function verifyGoogleToken(idToken) {
    const ticket = await oauthClient.verifyIdToken({ idToken, audience });
    const p = ticket.getPayload();
    return { sub: p.sub, email: p.email, name: p.name, picture: p.picture };
  };
}

// The set of OAuth client ids (all from this one GCP project) a Google ID token
// may legitimately be issued for: web + iOS + Android. Falsy/unset ones drop.
function googleAudiences(env) {
  return [
    env.GOOGLE_WEB_CLIENT_ID,
    env.GOOGLE_IOS_CLIENT_ID,
    env.GOOGLE_ANDROID_CLIENT_ID,
  ].filter(Boolean);
}

module.exports = { makeVerifier, googleAudiences };
