const admin = require("firebase-admin");
const {
  isMusicKitSongId,
  normalizeMusicKitSongId,
} = require("../utils/musicKit");

const db = () => admin.firestore();
const { FieldValue } = admin.firestore;

async function createHowCard({
  uid,
  comment,
  songStart,
  songEnd,
  songId,
  artistId,
  itunesId,
  songSlug,
  tags = [],
}) {
  const ref = db().collection("how-cards").doc();
  const data = {
    comment,
    song_start: songStart,
    song_end: songEnd,
    song_id: songId,
    itunes_id: itunesId ?? songId,
    artist_id: artistId,
    user_id: uid,
    likes: 0,
    tags: Array.isArray(tags) ? tags : [],
    created_at: FieldValue.serverTimestamp(),
  };

  if (songSlug) data.song_slug = songSlug;

  await ref.set(data);
  return serializeHowCard(ref.id, { ...data, created_at: null });
}

// 反応セッション（moat P-a）: 本人の user_id で保存。B2B へは Functions 集計・匿名化のみ。
async function createReactionSession({
  uid,
  songId,
  songTitle,
  artistId,
  artistName,
  durationSec,
  consentVersion,
  events,
  selfReportTags,
}) {
  const now = FieldValue.serverTimestamp();
  const ref = db().collection("reaction_sessions").doc();
  await ref.set({
    user_id: uid,
    song_id: songId,
    song_title: songTitle ?? null,
    artist_id: artistId ?? null,
    artist_name: artistName ?? null,
    duration_sec: durationSec ?? null,
    consent_version: consentVersion ?? "v1",
    events: Array.isArray(events) ? events : [],
    // 弱教師ラベル（ユーザーが選んだ How タグ）＝将来の ML 学習用
    self_report: { tags: Array.isArray(selfReportTags) ? selfReportTags : [] },
    recorded_at: now,
    created_at: now,
  });
  return { id: ref.id };
}

async function getHowCards({ songId, limit = 50 } = {}) {
  const collection = db().collection("how-cards");

  if (songId) {
    const queries = [
      collection.where("song_id", "==", songId).limit(limit).get(),
    ];
    if (isMusicKitSongId(songId)) {
      queries.push(
        collection.where("itunes_id", "==", songId).limit(limit).get(),
      );
    }

    const snapshots = await Promise.all(queries);
    return serializeHowCardDocs(
      snapshots.flatMap((snapshot) => snapshot.docs),
      limit,
    );
  }

  const query = collection.orderBy("created_at", "desc");
  const snapshot = await query.limit(limit).get();
  return serializeHowCardDocs(snapshot.docs, limit);
}

async function serializeHowCardDocs(docs, limit) {
  const docsById = new Map();
  for (const doc of docs) {
    if (!docsById.has(doc.id)) {
      docsById.set(doc.id, doc);
    }
  }

  const howCards = [...docsById.values()]
    .map((doc) => serializeHowCard(doc.id, doc.data()))
    .filter(Boolean)
    .sort(
      (a, b) => timestampMillis(b.created_at) - timestampMillis(a.created_at),
    )
    .slice(0, limit);

  return attachUserNames(howCards);
}

async function getHowCard(cardId) {
  const doc = await db().collection("how-cards").doc(cardId).get();
  if (!doc.exists) return null;
  return attachUserName(serializeHowCard(doc.id, doc.data()));
}

async function getRecommendedHowCards({ limit = 12 } = {}) {
  const safeLimit = clampLimit(limit, 1, 50);
  const sampleLimit = Math.min(100, Math.max(safeLimit * 4, 24));
  const collection = db().collection("how-cards");
  const [recentSnapshot, likedSnapshot] = await Promise.all([
    collection.orderBy("created_at", "desc").limit(sampleLimit).get(),
    collection.orderBy("likes", "desc").limit(sampleLimit).get(),
  ]);

  const candidates = new Map();
  for (const doc of [...recentSnapshot.docs, ...likedSnapshot.docs]) {
    if (!candidates.has(doc.id)) {
      candidates.set(doc.id, serializeHowCard(doc.id, doc.data()));
    }
  }

  const howCards = [...candidates.values()]
    .filter(Boolean)
    .sort(compareRecommendedHowCards)
    .slice(0, safeLimit);

  return attachUserNames(howCards);
}

async function getHowCardReplies({ cardId, limit = 50 } = {}) {
  const cardRef = db().collection("how-cards").doc(cardId);
  const cardDoc = await cardRef.get();
  if (!cardDoc.exists || !isHowCardComment(cardDoc.data())) return null;

  const snapshot = await cardRef
    .collection("replies")
    .orderBy("created_at", "asc")
    .limit(clampLimit(limit, 1, 100))
    .get();

  const replies = snapshot.docs
    .map((doc) => serializeHowCardReply(doc.id, cardId, doc.data()))
    .filter(Boolean);

  return attachReplyUserNames(replies);
}

async function createHowCardReply({ cardId, uid, body }) {
  const cardRef = db().collection("how-cards").doc(cardId);
  const replyRef = cardRef.collection("replies").doc();
  let replyData = null;

  await db().runTransaction(async (transaction) => {
    const cardDoc = await transaction.get(cardRef);
    if (!cardDoc.exists || !isHowCardComment(cardDoc.data())) {
      throwFirestoreError("Howカードが見つかりません", "not-found");
    }

    replyData = {
      body,
      user_id: uid,
      created_at: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
    };

    transaction.set(replyRef, replyData);
    transaction.update(cardRef, {
      reply_count: FieldValue.increment(1),
      updated_at: FieldValue.serverTimestamp(),
    });
  });

  const updatedCard = await cardRef.get();
  const replyCount = updatedCard.exists
    ? currentReplyCount(updatedCard.data())
    : 0;
  const reply = serializeHowCardReply(replyRef.id, cardId, {
    ...replyData,
    created_at: null,
  });
  const [withUserName] = await attachReplyUserNames([reply]);
  return { reply: withUserName, replyCount };
}

async function updateHowCard({
  uid,
  cardId,
  comment,
  songStart,
  songEnd,
  songId,
  artistId,
  itunesId,
  songSlug,
  tags = [],
}) {
  const ref = db().collection("how-cards").doc(cardId);

  await db().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) {
      throwFirestoreError("Howカードが見つかりません", "not-found");
    }

    const data = snapshot.data();
    if (!isHowCardComment(data)) {
      throwFirestoreError("Howカードが見つかりません", "not-found");
    }

    if (data.user_id !== uid) {
      throwFirestoreError(
        "このHowカードへのアクセス権がありません",
        "permission-denied",
      );
    }

    const patch = {
      comment,
      song_start: songStart,
      song_end: songEnd,
      song_id: songId,
      itunes_id: itunesId ?? songId,
      artist_id: artistId,
      tags: Array.isArray(tags) ? tags : [],
      updated_at: FieldValue.serverTimestamp(),
    };
    if (songSlug) {
      patch.song_slug = songSlug;
    } else {
      patch.song_slug = FieldValue.delete();
    }

    transaction.update(ref, patch);
  });

  return getHowCard(cardId);
}

async function likeHowCard({ cardId, uid }) {
  const cardRef = db().collection("how-cards").doc(cardId);
  const likeRef = cardRef.collection("liked-by").doc(uid);

  return db().runTransaction(async (transaction) => {
    const cardDoc = await transaction.get(cardRef);
    if (!cardDoc.exists) return null;

    const data = cardDoc.data();
    if (!isHowCardComment(data)) return null;

    const likeDoc = await transaction.get(likeRef);
    const currentLikes = currentLikeCount(data);
    if (likeDoc.exists) return currentLikes;

    transaction.set(likeRef, {
      user_id: uid,
      liked_at: FieldValue.serverTimestamp(),
    });
    transaction.update(cardRef, {
      likes: currentLikes + 1,
      goods: FieldValue.delete(),
      updated_at: FieldValue.serverTimestamp(),
    });
    return currentLikes + 1;
  });
}

async function upsertUserProfile({ uid, email, displayName }) {
  const userRef = db().collection("users").doc(uid);
  const now = FieldValue.serverTimestamp();

  await db().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(userRef);
    const existingData = snapshot.exists ? snapshot.data() : {};
    const data = {
      user_id: uid,
      email,
      display_name: displayName ?? null,
      updated_at: now,
    };

    if (!snapshot.exists || !isFirestoreTimestamp(existingData.created_at)) {
      data.created_at = now;
    }

    transaction.set(userRef, data, { merge: true });
  });

  const snapshot = await userRef.get();
  return serializeUser(snapshot.id, snapshot.data());
}

async function getUserProfile(uid) {
  const doc = await db().collection("users").doc(uid).get();
  if (!doc.exists) return null;
  return serializeUser(doc.id, doc.data());
}

function serializeHowCard(id, data) {
  if (!isHowCardComment(data)) return null;
  const canonicalSongId = canonicalMusicSongID(data);
  const storedSongId = normalizeString(data.song_id);
  const songId = canonicalSongId ?? storedSongId;
  if (!songId) return null;

  const songSlug =
    normalizeString(data.song_slug) ??
    (canonicalSongId && storedSongId && storedSongId !== canonicalSongId
      ? storedSongId
      : null);

  const howCard = {
    id,
    comment: data.comment,
    song_start: Number.isFinite(data.song_start) ? data.song_start : 0,
    song_end: Number.isFinite(data.song_end) ? data.song_end : 0,
    song_id: songId,
    ...(songSlug ? { song_slug: songSlug } : {}),
    artist_id: data.artist_id,
    user_id: data.user_id,
    likes: currentLikeCount(data),
    reply_count: currentReplyCount(data),
    user_name: data.user_name ?? data.display_name ?? data.displayName ?? null,
    created_at: timestampToISOString(data.created_at),
    updated_at: timestampToISOString(data.updated_at),
  };

  if (canonicalSongId) {
    howCard.itunes_id = canonicalSongId;
  }
  if (typeof data.song_slug === "string") {
    howCard.song_slug = data.song_slug;
  }
  if (typeof data.song_title === "string") {
    howCard.song_title = data.song_title;
  }
  if (typeof data.artist_name === "string") {
    howCard.artist_name = data.artist_name;
  }

  return howCard;
}

async function attachUserNames(howCards) {
  const userIds = [
    ...new Set(howCards.map((card) => card.user_id).filter(Boolean)),
  ];
  if (userIds.length === 0) return howCards;

  const userNames = await userNamesById(userIds);

  return howCards.map((card) => ({
    ...card,
    user_name: userNames.get(card.user_id) ?? card.user_name ?? null,
  }));
}

async function attachUserName(howCard) {
  if (!howCard) return null;
  const [withUserName] = await attachUserNames([howCard]);
  return withUserName;
}

async function attachReplyUserNames(replies) {
  const userIds = [
    ...new Set(replies.map((reply) => reply.user_id).filter(Boolean)),
  ];
  if (userIds.length === 0) return replies;

  const userNames = await userNamesById(userIds);
  return replies.map((reply) => ({
    ...reply,
    user_name: userNames.get(reply.user_id) ?? reply.user_name ?? null,
  }));
}

async function userNamesById(userIds) {
  const snapshots = await Promise.all(
    userIds.map((userId) => db().collection("users").doc(userId).get()),
  );
  const userNames = new Map();
  snapshots.forEach((snapshot, index) => {
    if (!snapshot.exists) return;
    const displayName = displayNameFromUserData(snapshot.data());
    if (displayName) userNames.set(userIds[index], displayName);
  });
  return userNames;
}

function currentLikeCount(data) {
  const likes = Number.isInteger(data.likes) ? data.likes : null;
  const goods = Number.isInteger(data.goods) ? data.goods : null;
  if (likes !== null && goods !== null) return Math.max(likes, goods);
  if (likes !== null) return likes;
  if (goods !== null) return goods;
  return 0;
}

function currentReplyCount(data) {
  return Number.isInteger(data.reply_count) ? Math.max(0, data.reply_count) : 0;
}

function serializeHowCardReply(id, cardId, data) {
  if (!isHowCardReply(data)) return null;
  return {
    id,
    how_card_id: cardId,
    body: data.body,
    user_id: data.user_id,
    user_name: data.user_name ?? data.display_name ?? data.displayName ?? null,
    created_at: timestampToISOString(data.created_at),
    updated_at: timestampToISOString(data.updated_at),
  };
}

function isHowCardReply(data) {
  return Boolean(
    data &&
    typeof data.body === "string" &&
    data.body.trim().length > 0 &&
    typeof data.user_id === "string",
  );
}

function serializeUser(id, data = {}) {
  return {
    id,
    user_id: data.user_id ?? id,
    email: data.email ?? null,
    display_name: data.display_name ?? data.displayName ?? null,
    created_at: timestampToISOString(data.created_at ?? data.createdAt),
    updated_at: timestampToISOString(data.updated_at ?? data.updatedAt),
  };
}

function displayNameFromUserData(data = {}) {
  const displayName = data.display_name ?? data.displayName;
  if (typeof displayName !== "string") return null;
  const trimmed = displayName.trim();
  return trimmed ? trimmed : null;
}

function isHowCardComment(data) {
  return Boolean(
    data &&
    typeof data.comment === "string" &&
    normalizeString(data.song_id) &&
    typeof data.artist_id === "string" &&
    typeof data.user_id === "string",
  );
}

function canonicalMusicSongID(data) {
  return (
    normalizeMusicKitSongId(data.itunes_id) ??
    normalizeMusicKitSongId(data.music_kit_id) ??
    normalizeMusicKitSongId(data.song_id)
  );
}

function normalizeString(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed || null;
}

function timestampToISOString(value) {
  if (!value) return null;
  if (typeof value === "string") return value;
  if (typeof value.toDate === "function") return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  return null;
}

function timestampMillis(value) {
  if (!value) return 0;
  const time = Date.parse(value);
  return Number.isFinite(time) ? time : 0;
}

function isFirestoreTimestamp(value) {
  return Boolean(value && typeof value.toDate === "function");
}

function compareRecommendedHowCards(left, right) {
  const scoreDiff = recommendationScore(right) - recommendationScore(left);
  if (scoreDiff !== 0) return scoreDiff;
  return timestampMillis(right.created_at) - timestampMillis(left.created_at);
}

function recommendationScore(card) {
  const likes = Math.max(0, Number.isInteger(card.likes) ? card.likes : 0);
  const ageHours = ageHoursFromNow(card.created_at);
  const recency = ageHours == null ? 0 : Math.exp(-ageHours / 72);
  const freshBoost = ageHours != null && ageHours <= 24 ? 1.2 : 0;

  return Math.log2(likes + 1) * 2.4 + recency * 3 + freshBoost;
}

function ageHoursFromNow(value) {
  const millis = timestampMillis(value);
  if (!millis) return null;
  return Math.max(0, (Date.now() - millis) / 36e5);
}

function clampLimit(value, min, max) {
  const number = Number(value);
  if (!Number.isFinite(number)) return min;
  return Math.min(max, Math.max(min, Math.floor(number)));
}

function throwFirestoreError(message, code) {
  const error = new Error(message);
  error.code = code;
  throw error;
}

module.exports = {
  createHowCard,
  createReactionSession,
  getHowCards,
  getHowCard,
  getRecommendedHowCards,
  getHowCardReplies,
  createHowCardReply,
  updateHowCard,
  likeHowCard,
  upsertUserProfile,
  getUserProfile,
};
