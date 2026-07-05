// Stock google-auth-library verification - never hand-rolled (D5).
// Rejects wrong-aud and expired Google ID tokens by throwing.
function makeVerifier(oauthClient, audience) {
  return async function verifyGoogleToken(idToken) {
    const ticket = await oauthClient.verifyIdToken({ idToken, audience });
    const p = ticket.getPayload();
    return { sub: p.sub, email: p.email, name: p.name, picture: p.picture };
  };
}

module.exports = { makeVerifier };
