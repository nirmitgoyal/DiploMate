const jwt = require("jsonwebtoken");

const NINETY_DAYS_S = 90 * 24 * 3600;

// SESSION_JWT_SECRET is a JSON object {kid: secret,...}; FIRST key = active
// signing kid; every listed kid verifies (rotate = add new first, drop old).
function activeKid(secrets) {
  return Object.keys(secrets)[0];
}

function signSession(userId, { secrets, now = () => new Date() }) {
  const kid = activeKid(secrets);
  const iat = Math.floor(now().getTime() / 1000);
  return jwt.sign(
    { sub: userId, iat, exp: iat + NINETY_DAYS_S },
    secrets[kid],
    {
      algorithm: "HS256",
      keyid: kid,
    },
  );
}

function verifySession(token, { secrets, now = () => new Date() }) {
  const { header } = jwt.decode(token, { complete: true }) || {};
  const secret = header && secrets[header.kid];
  if (!secret) throw new Error("unknown kid");
  return jwt.verify(token, secret, {
    algorithms: ["HS256"],
    clockTimestamp: Math.floor(now().getTime() / 1000),
  });
}

module.exports = { signSession, verifySession, NINETY_DAYS_S };
