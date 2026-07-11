const { onRequest } = require("firebase-functions/v2/https");
const functionsV1 = require("firebase-functions/v1");
const admin = require("firebase-admin");

admin.initializeApp();

const { recomputeSongInsights } = require("./repositories/insights");

exports.api = onRequest(
  {
    region: "asia-northeast1",
    cors: true,
    memory: "256MiB",
    timeoutSeconds: 60,
    minInstances: 1,
  },
  require("./app"),
);

// how-card の作成/更新/削除で該当曲の song_insights を再集計（前計算・匿名化）
// v1 Firestore トリガー（Eventarc IAM 不要。v2 は権限設定に project owner が要るため回避）
exports.onHowCardWritten = functionsV1
  .region("asia-northeast1")
  .firestore.document("how-cards/{cardId}")
  .onWrite(async (change) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    const songIds = new Set();
    if (before?.song_id) songIds.add(before.song_id);
    if (after?.song_id) songIds.add(after.song_id);
    await Promise.all([...songIds].map((id) => recomputeSongInsights(id)));
  });

// 反応セッション（moat P-a）の作成/更新/削除で該当曲の song_insights を再集計
exports.onReactionSessionWritten = functionsV1
  .region("asia-northeast1")
  .firestore.document("reaction_sessions/{sessionId}")
  .onWrite(async (change) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    const songIds = new Set();
    if (before?.song_id) songIds.add(before.song_id);
    if (after?.song_id) songIds.add(after.song_id);
    await Promise.all([...songIds].map((id) => recomputeSongInsights(id)));
  });

exports.onUserSignup = functionsV1
  .region("asia-northeast1")
  .auth.user()
  .onCreate(async (user) => {
    const userRef = admin.firestore().collection("users").doc(user.uid);
    try {
      const now = admin.firestore.FieldValue.serverTimestamp();
      await userRef.create({
        user_id: user.uid,
        email: user.email ?? null,
        display_name: user.displayName ?? null,
        created_at: now,
        updated_at: now,
      });
    } catch (err) {
      // grpc code 6 = ALREADY_EXISTS. Trigger re-fired, user doc already created.
      if (err.code !== 6) throw err;
    }
  });
