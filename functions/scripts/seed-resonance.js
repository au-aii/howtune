/**
 * 共鳴マッチングのデモ用 seed（FR-RES-04 / ADR-0006）。
 *
 * 実機1台でもリアルタイム共鳴を再現するため、デモ曲(song_id=howtune-demo-song)に
 * 複数地点の how-cards と mock users を投入する。実機が ResonanceMatchService で
 * この song_id を購読すると、投稿した反応区間に応じて同地点(🔥)/別地点が現れる。
 *
 * 使い方:
 *   cd functions
 *   GOOGLE_APPLICATION_CREDENTIALS=serviceAccountKey.json node scripts/seed-resonance.js --write
 *   (--write 無しは dry-run)
 */
const admin = require("firebase-admin");

process.env.FIRESTORE_PREFER_REST = "1";

const SONG_ID = "howtune-demo-song";

const USERS = [
  { uid: "demo-resonance-aoi", name: "あおい" },
  { uid: "demo-resonance-ren", name: "れん" },
  { uid: "demo-resonance-mio", name: "みお" },
];

// 複数地点に散らすことで、実機がどこで反応しても同地点/別地点の両方が出る。
const CARDS = [
  {
    user: 0,
    start: 20,
    end: 26,
    comment: "イントロのベースで一気に持っていかれた",
  },
  { user: 1, start: 44, end: 50, comment: "このサビ前の溜めで鳥肌が立った" },
  {
    user: 2,
    start: 77,
    end: 84,
    comment: "歌詞のこの一節、自分の生活と重なる",
  },
  {
    user: 0,
    start: 116,
    end: 122,
    comment: "二番のリズムチェンジで体が勝手に動いた",
  },
  {
    user: 1,
    start: 158,
    end: 165,
    comment: "アウトロの余韻がずっと残っている",
  },
];

async function main() {
  const shouldWrite = process.argv.includes("--write");
  if (!admin.apps.length) admin.initializeApp();
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();

  console.log(`[seed-resonance] song_id=${SONG_ID} write=${shouldWrite}`);

  // users
  for (const u of USERS) {
    const ref = db.collection("users").doc(u.uid);
    const data = {
      user_id: u.uid,
      email: null,
      display_name: u.name,
      created_at: now,
      updated_at: now,
    };
    console.log(`  user ${u.uid} (${u.name})`);
    if (shouldWrite) await ref.set(data, { merge: true });
  }

  // how-cards
  let i = 0;
  for (const c of CARDS) {
    const user = USERS[c.user];
    const id = `demo-resonance-card-${i++}`;
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
      created_at: now,
      updated_at: now,
    };
    console.log(`  card ${id} ${c.start}-${c.end}s by ${user.name}`);
    if (shouldWrite) await ref.set(data, { merge: true });
  }

  console.log(
    shouldWrite
      ? "[seed-resonance] done (written)"
      : "[seed-resonance] dry-run only (pass --write)",
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
