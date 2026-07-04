const admin = require("firebase-admin");

const db = () => admin.firestore();
const { FieldValue } = admin.firestore;

// k-匿名性: 反応者がこれ未満の曲・区間は非表示（集計に出さない）
const MIN_REACTORS = 5;
// 密度ヒートマップの時間バケット（秒）
const BUCKET_SEC = 5;

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

// 本物のタグがあればそれを、無ければコメント推測で補完
function tagsForCard(data) {
  const tags = Array.isArray(data.tags)
    ? data.tags.filter((t) => typeof t === "string" && t)
    : [];
  if (tags.length > 0) return [...new Set(tags)];
  return [heuristicTag(data.comment)];
}

/**
 * 指定曲の how-cards を集計して song_insights/{songId} に前計算・保存する。
 * - 匿名化: user_id は保存しない。反応者 5 人未満の曲/区間は伏せる。
 */
async function recomputeSongInsights(songId) {
  if (!songId || typeof songId !== "string") return;
  const insightRef = db().collection("song_insights").doc(songId);

  const snap = await db()
    .collection("how-cards")
    .where("song_id", "==", songId)
    .get();
  const cards = snap.docs
    .map((d) => d.data())
    .filter(
      (data) =>
        data &&
        typeof data.user_id === "string" &&
        Number.isFinite(data.song_start) &&
        Number.isFinite(data.song_end),
    );

  const reactorIds = new Set(cards.map((c) => c.user_id));
  const reactorCount = reactorIds.size;

  // 曲レベル k-匿名性: 5 人未満なら insight を消す（非表示）
  if (reactorCount < MIN_REACTORS) {
    await insightRef.delete().catch(() => {});
    return;
  }

  // 密度: 各バケットで区間が重なる distinct user_id を数える
  const maxEnd = cards.reduce((m, c) => Math.max(m, c.song_end), 0);
  const bucketCount = Math.max(1, Math.ceil(maxEnd / BUCKET_SEC));
  const bucketReactors = Array.from({ length: bucketCount }, () => new Set());
  for (const c of cards) {
    const start = Math.max(0, c.song_start);
    const end = Math.max(c.song_start, c.song_end);
    const startBucket = Math.floor(start / BUCKET_SEC);
    const endBucket = Math.floor(end / BUCKET_SEC);
    for (let b = startBucket; b <= endBucket && b < bucketCount; b += 1) {
      bucketReactors[b].add(c.user_id);
    }
  }
  const density = bucketReactors.map((set, i) => ({
    t: i * BUCKET_SEC,
    // 区間レベル k-匿名性: 5 人未満のバケットは伏せる
    count: set.size >= MIN_REACTORS ? set.size : 0,
  }));

  // タグ分布（曲は既に 5 人以上＝集計を出してよい）
  const tagCounts = {};
  for (const c of cards) {
    for (const tag of tagsForCard(c)) {
      tagCounts[tag] = (tagCounts[tag] || 0) + 1;
    }
  }

  await insightRef.set({
    song_id: songId,
    reactor_count: reactorCount,
    density,
    tags: tagCounts,
    updated_at: FieldValue.serverTimestamp(),
  });
}

module.exports = { recomputeSongInsights, MIN_REACTORS, BUCKET_SEC };
