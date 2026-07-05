const express = require("express");
const path = require("node:path");

const router = express.Router();
const staticDir = path.join(__dirname, "..", "..", "static");

router.get("/legal/privacy", (req, res) =>
  res.sendFile(path.join(staticDir, "privacy.html")),
);
router.get("/legal/terms", (req, res) =>
  res.sendFile(path.join(staticDir, "terms.html")),
);
router.get("/account/delete", (req, res) =>
  res.sendFile(path.join(staticDir, "account-delete.html")),
);

module.exports = router;
