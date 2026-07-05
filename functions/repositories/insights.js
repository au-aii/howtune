const admin = require("firebase-admin");

const db = () => admin.firestore();
const { FieldValue } = admin.firestore;

// k-匿名性: 反応者がこれ未満の曲・区間は非表示（集計に出さない）
const MIN_REACTORS = 5;
// 密度ヒートマップの時間バケット（秒）
const BUCKET_SEC = 5;
// バケット数の上限（≈6時間相当）。異常な区間長による Array.from({length: 巨大}) の OOM を防ぐ防御的キャップ。
const MAX_BUCKETS = 4320;

// コメント推測タグのフォールバック（iOS CommunityViewModel.tag(for:) の JS 移植）
const CHILL_KEYWORDS = ["雨", "沁み", "泣", "余韻", "落ち着く", "孤独"];
const GROOVE_KEYWORDS = [
  "リズム",
  "ビート",
  "ドライブ",
  "テンション",
  "BGM",
  "頭",
  "反則",
];

function heuristicTag(comment) {
  const c = typeof comment === "string" ? comment : "";
  if (CHILL_KEYWORDS.some((k) => c.includes(k))) return "chill";
  if (GROOVE_KEYWORDS.some((k) => c.includes(k))) return "groove";
  return "neutral";
}

// how-card のタグ（本物があればそれ、無ければコメント推測）
function tagsForCard(data) {
  const tags = Array.isArray(data.tags)
    ? data.tags.filter((t) => typeof t === "string" && t)
    : [];
  if (tags.length > 0) return [...new Set(tags)];
  return [heuristicTag(data.comment)];
}

/**
 * 指定曲の反応を集計して song_insights/{songId} に前計算・保存する。
 * ソースは how-cards（コメント区間）と reaction_sessions（実反応イベント・moat P-a）の両方。
 * - 匿名化: user_id は保存しない。反応者/区間が 5 人未満なら伏せる（k-匿名性）。
 */
async function recomputeSongInsights(songId) {
  if (!songId || typeof songId !== "string") return;
  const insightRef = db().collection("song_insights").doc(songId);

  // 反応区間を how-cards と reaction_sessions の両方から集める。
  // interval = { user_id, start, end, tags[] }
  const intervals = [];
  let artistId = null;
  let artistName = null;
  let songTitle = null;
  const remember = (src) => {
    if (!artistId && typeof src.artist_id === "string")
      artistId = src.artist_id;
    if (!artistName && typeof src.artist_name === "string")
      artistName = src.artist_name;
    if (!songTitle && typeof src.song_title === "string")
      songTitle = src.song_title;
  };

  const cardSnap = await db()
    .collection("how-cards")
    .where("song_id", "==", songId)
    .get();
  for (const doc of cardSnap.docs) {
    const c = doc.data();
    if (!c || typeof c.user_id !== "string") continue;
    if (!Number.isFinite(c.song_start) || !Number.isFinite(c.song_end))
      continue;
    intervals.push({
      user_id: c.user_id,
      start: c.song_start,
      end: c.song_end,
      tags: tagsForCard(c),
    });
    remember(c);
  }

  const sessionSnap = await db()
    .collection("reaction_sessions")
    .where("song_id", "==", songId)
    .get();
  for (const doc of sessionSnap.docs) {
    const s = doc.data();
    if (!s || typeof s.user_id !== "string" || !Array.isArray(s.events))
      continue;
    for (const e of s.events) {
      if (!e || !Number.isFinite(e.start) || !Number.isFinite(e.end)) continue;
      const tags =
        Array.isArray(e.tags) && e.tags.length
          ? e.tags.filter((t) => typeof t === "string" && t)
          : [];
      intervals.push({
        user_id: s.user_id,
        start: e.start,
        end: e.end,
        tags: tags.length ? tags : ["neutral"],
      });
    }
    remember(s);
  }

  const reactorCount = new Set(intervals.map((i) => i.user_id)).size;

  // 曲レベル k-匿名性: 5 人未満なら insight を消す（非表示）
  if (reactorCount < MIN_REACTORS) {
    await insightRef.delete().catch(() => {});
    return;
  }

  // 密度: 各バケットで区間が重なる distinct user_id を数える
  const maxEnd = intervals.reduce((m, i) => Math.max(m, i.end), 0);
  const bucketCount = Math.min(
    MAX_BUCKETS,
    Math.max(1, Math.ceil(maxEnd / BUCKET_SEC)),
  );
  const bucketReactors = Array.from({ length: bucketCount }, () => new Set());
  for (const i of intervals) {
    const start = Math.max(0, i.start);
    const end = Math.max(i.start, i.end);
    const startBucket = Math.floor(start / BUCKET_SEC);
    const endBucket = Math.floor(end / BUCKET_SEC);
    for (let b = startBucket; b <= endBucket && b < bucketCount; b += 1) {
      bucketReactors[b].add(i.user_id);
    }
  }
  const density = bucketReactors.map((set, i) => ({
    t: i * BUCKET_SEC,
    // 区間レベル k-匿名性: 5 人未満のバケットは伏せる
    count: set.size >= MIN_REACTORS ? set.size : 0,
  }));

  // タグ分布（曲は既に 5 人以上＝集計を出してよい）
  const tagCounts = {};
  for (const i of intervals) {
    for (const tag of i.tags) tagCounts[tag] = (tagCounts[tag] || 0) + 1;
  }

  await insightRef.set({
    song_id: songId,
    // カタログのアーティスト情報（アーティスト別ダッシュボードで曲を束ねるため。個人情報ではない）
    artist_id: artistId,
    artist_name: artistName,
    song_title: songTitle,
    reactor_count: reactorCount,
    density,
    tags: tagCounts,
    updated_at: FieldValue.serverTimestamp(),
  });
}

module.exports = { recomputeSongInsights, MIN_REACTORS, BUCKET_SEC };
