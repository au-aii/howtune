const express = require("express");
const cors = require("cors");

const app = express();
app.use(cors());
app.use(express.json({ limit: "1mb" }));

app.use("/how-cards", require("./routes/how-cards"));
app.use("/reaction-sessions", require("./routes/reaction-sessions"));
app.use("/recommended-comments", require("./routes/recommended-comments"));
app.use("/users", require("./routes/users"));

app.get("/health", (_, res) => res.json({ status: "ok" }));

app.use((err, _req, res, _next) => {
  console.error(err?.message ?? err);
  res.status(500).json({ error: "サーバーエラー" });
});

module.exports = app;
