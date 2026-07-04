/**
 * Web ダッシュボード Phase 2（song_insights）のデモ用 seed。
 * k=5 匿名性を満たすため 6 ユーザー分の how-cards を投入し、
 * 密度ヒートマップに山ができるよう時間帯をクラスタさせる。
 * コメントに keyword を仕込み、推定タグ（chill/groove/neutral）が分散するようにする。
 *
 * 使い方（ADC 認証・howtune-74252 に書く）:
 *   cd functions
 *   GOOGLE_CLOUD_PROJECT=howtune-74252 node scripts/seed-insights.js --write
 *   (--write 無しは dry-run)
 *
 * how-card 書き込みで onHowCardWritten トリガーが発火し song_insights/{SONG_ID} が生成される。
 */
const admin = require("firebase-admin");

process.env.FIRESTORE_PREFER_REST = "1";

const SONG_ID = "howtune-demo-song";

const USERS = [
  { uid: "demo-insights-u1", name: "ユーザー1" },
  { uid: "demo-insights-u2", name: "ユーザー2" },
  { uid: "demo-insights-u3", name: "ユーザー3" },
  { uid: "demo-insights-u4", name: "ユーザー4" },
  { uid: "demo-insights-u5", name: "ユーザー5" },
  { uid: "demo-insights-u6", name: "ユーザー6" },
];

// 山A(≈44-52s): 6人 / 山B(≈116-124s): 5人 / 散発: 1人（k=5未満で伏せられる）
const CARDS = [
  { user: 0, start: 44, end: 50, comment: "このリズムで一気に持っていかれた" }, // groove
  { user: 1, start: 45, end: 51, comment: "ビートが最高" }, // groove
  { user: 2, start: 44, end: 52, comment: "ここのサビで鳥肌が立った" }, // neutral
  { user: 3, start: 46, end: 52, comment: "歌詞が沁みる" }, // chill
  { user: 4, start: 44, end: 49, comment: "テンション上がる" }, // groove
  { user: 5, start: 45, end: 50, comment: "この瞬間の余韻がすごい" }, // chill

  { user: 0, start: 116, end: 122, comment: "二番のドライブ感がいい" }, // groove
  { user: 1, start: 117, end: 123, comment: "ここ好き" }, // neutral
  { user: 2, start: 116, end: 124, comment: "落ち着く展開" }, // chill
  { user: 3, start: 118, end: 124, comment: "アウトロの余韻がずっと残る" }, // chill
  { user: 4, start: 116, end: 121, comment: "ビートが心地よい" }, // groove

  { user: 5, start: 20, end: 26, comment: "イントロ好き" }, // 散発（伏せられる想定）
];

async function main() {
  const shouldWrite = process.argv.includes("--write");
  if (!admin.apps.length) admin.initializeApp();
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();

  console.log(
    `[seed-insights] song_id=${SONG_ID} users=${USERS.length} cards=${CARDS.length} write=${shouldWrite}`,
  );

  for (const u of USERS) {
    const ref = db.collection("users").doc(u.uid);
    if (shouldWrite) {
      await ref.set(
        {
          user_id: u.uid,
          email: null,
          display_name: u.name,
          created_at: now,
          updated_at: now,
        },
        { merge: true },
      );
    }
  }

  let i = 0;
  for (const c of CARDS) {
    const user = USERS[c.user];
    const id = `demo-insights-card-${i++}`;
    const ref = db.collection("how-cards").doc(id);
    const data = {
      comment: c.comment,
      song_start: c.start,
      song_end: c.end,
      song_id: SONG_ID,
      itunes_id: SONG_ID,
      song_slug: SONG_ID,
      song_title: "HowTune Demo",
      artist_id: "howtune",
      artist_name: "HowTune",
      user_id: user.uid,
      user_name: user.name,
      likes: 0,
      tags: [],
      created_at: now,
      updated_at: now,
    };
    console.log(`  card ${id} ${c.start}-${c.end}s by ${user.name}`);
    if (shouldWrite) await ref.set(data, { merge: true });
  }

  // 自分のアカウント(SEED_MY_EMAIL)も反応者として追加＝Web ダッシュボードに出すため
  const myEmail = process.env.SEED_MY_EMAIL;
  if (shouldWrite && myEmail) {
    try {
      const me = await admin.auth().getUserByEmail(myEmail);
      await db
        .collection("how-cards")
        .doc("demo-insights-card-me")
        .set(
          {
            comment: "自分もここで反応した",
            song_start: 45,
            song_end: 51,
            song_id: SONG_ID,
            itunes_id: SONG_ID,
            song_slug: SONG_ID,
            song_title: "HowTune Demo",
            artist_id: "howtune",
            artist_name: "HowTune",
            user_id: me.uid,
            user_name: me.displayName ?? "あなた",
            likes: 0,
            tags: [],
            created_at: now,
            updated_at: now,
          },
          { merge: true },
        );
      console.log(
        `[seed-insights] added your card (email=${myEmail} uid=${me.uid})`,
      );
    } catch (e) {
      console.log(`[seed-insights] SEED_MY_EMAIL lookup failed: ${e.message}`);
    }
  }

  // 集計トリガーが未デプロイでも動くよう、seed 後に集計も実行する
  if (shouldWrite) {
    const { recomputeSongInsights } = require("../repositories/insights");
    await recomputeSongInsights(SONG_ID);
    const snap = await db.collection("song_insights").doc(SONG_ID).get();
    console.log(
      `[seed-insights] song_insights exists=${snap.exists} reactor_count=${snap.data()?.reactor_count}`,
    );
  }

  console.log(
    shouldWrite
      ? "[seed-insights] done (written)"
      : "[seed-insights] dry-run only (pass --write)",
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
