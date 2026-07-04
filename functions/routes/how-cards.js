const express = require("express");
const router = express.Router();
const auth = require("../middleware/auth");
const {
  createHowCard,
  getHowCards,
  getHowCard,
  getHowCardReplies,
  createHowCardReply,
  updateHowCard,
  likeHowCard,
} = require("../repositories/firestore");
const { normalizeMusicKitSongId } = require("../utils/musicKit");

const INVALID_SONG_ID_ERROR =
  "song_id には MusicKit / Apple Music / iTunes の数値曲IDを指定してください";
const INVALID_REPLY_BODY_ERROR = "返信本文は1〜180文字で入力してください";

// HowTag.rawValue（iOS の Models/HowTag.swift と一致させる）
const KNOWN_HOW_TAGS = new Set([
  "groove",
  "hype",
  "chill",
  "immersion",
  "hit",
  "afterglow",
  "neutral",
]);
const MAX_TAGS = 6;

router.get("/", auth, async (req, res) => {
  try {
    const hasSongIdQuery = Object.prototype.hasOwnProperty.call(
      req.query,
      "song_id",
    );
    const songId = hasSongIdQuery
      ? normalizeLookupSongId(req.query.song_id)
      : null;
    if (hasSongIdQuery && !songId) {
      return res
        .status(400)
        .json({ error: "song_id は空でない文字列を指定してください" });
    }

    const howCards = await getHowCards({
      songId,
      limit: parseLimit(req.query.limit),
    });
    res.json({ howCards });
  } catch (err) {
    console.error(err?.message ?? err);
    res.status(500).json({ error: "Howカードの取得に失敗しました" });
  }
});

router.get("/:id/replies", auth, async (req, res) => {
  try {
    const replies = await getHowCardReplies({
      cardId: req.params.id,
      limit: parseRepliesLimit(req.query.limit),
    });
    if (replies === null) {
      return res.status(404).json({ error: "Howカードが見つかりません" });
    }

    res.json({ replies });
  } catch (err) {
    console.error(err?.message ?? err);
    res.status(500).json({ error: "返信の取得に失敗しました" });
  }
});

router.post("/:id/replies", auth, async (req, res) => {
  const body = normalizeRequiredString(req.body?.body, 180);
  if (!body) {
    return res.status(400).json({ error: INVALID_REPLY_BODY_ERROR });
  }

  try {
    const { reply, replyCount } = await createHowCardReply({
      cardId: req.params.id,
      uid: req.uid,
      body,
    });
    res.status(201).json({ reply, reply_count: replyCount });
  } catch (err) {
    if (err.code === "not-found") {
      return res.status(404).json({ error: err.message });
    }

    console.error(err?.message ?? err);
    res.status(500).json({ error: "返信の作成に失敗しました" });
  }
});

router.get("/:id", auth, async (req, res) => {
  try {
    const howCard = await getHowCard(req.params.id);
    if (!howCard) {
      return res.status(404).json({ error: "Howカードが見つかりません" });
    }

    res.json({ howCard });
  } catch (err) {
    console.error(err?.message ?? err);
    res.status(500).json({ error: "Howカードの取得に失敗しました" });
  }
});

router.post("/", auth, async (req, res) => {
  const payload = normalizeCommentPayload(req.body);
  if (!payload) {
    return res.status(400).json({
      error: `comment, song_start, song_end, artist_id が必要です。${INVALID_SONG_ID_ERROR}`,
    });
  }

  try {
    const howCard = await createHowCard({ uid: req.uid, ...payload });
    res.status(201).json({ howCard });
  } catch (err) {
    console.error(err?.message ?? err);
    res.status(500).json({ error: "Howカードの作成に失敗しました" });
  }
});

router.patch("/:id", auth, async (req, res) => {
  const payload = normalizeCommentPayload(req.body);
  if (!payload) {
    return res.status(400).json({
      error: `comment, song_start, song_end, artist_id が必要です。${INVALID_SONG_ID_ERROR}`,
    });
  }

  try {
    const howCard = await updateHowCard({
      uid: req.uid,
      cardId: req.params.id,
      ...payload,
    });
    res.json({ howCard });
  } catch (err) {
    if (err.code === "not-found") {
      return res.status(404).json({ error: err.message });
    }
    if (err.code === "permission-denied") {
      return res.status(403).json({ error: err.message });
    }

    console.error(err?.message ?? err);
    res.status(500).json({ error: "Howカードの更新に失敗しました" });
  }
});

router.post("/:id/like", auth, async (req, res) => {
  try {
    const likes = await likeHowCard({ cardId: req.params.id, uid: req.uid });
    if (likes === null) {
      return res.status(404).json({ error: "Howカードが見つかりません" });
    }

    res.json({ likes });
  } catch (err) {
    console.error(err?.message ?? err);
    res.status(500).json({ error: "Howカードのいいね更新に失敗しました" });
  }
});

function normalizeCommentPayload(body) {
  if (!body || typeof body !== "object") return null;

  const comment = normalizeRequiredString(body.comment, 140);
  const songStart = normalizeRangePoint(body.song_start);
  const songEnd = normalizeRangePoint(body.song_end);
  const songId = normalizeMusicKitSongId(body.song_id);
  const artistId = normalizeRequiredString(body.artist_id, 120);
  if (
    !comment ||
    songStart == null ||
    songEnd == null ||
    songEnd <= songStart ||
    !songId ||
    !artistId
  ) {
    return null;
  }

  const explicitSongSlug = normalizeOptionalString(body.song_slug, 120);

  return {
    comment,
    songStart,
    songEnd,
    songId,
    artistId,
    itunesId: songId,
    songSlug: explicitSongSlug,
    tags: normalizeTags(body.tags),
  };
}

function normalizeTags(value) {
  if (!Array.isArray(value)) return [];
  const seen = new Set();
  for (const v of value) {
    if (typeof v === "string" && KNOWN_HOW_TAGS.has(v)) {
      seen.add(v);
    }
    if (seen.size >= MAX_TAGS) break;
  }
  return [...seen];
}

function normalizeOptionalString(value, maxLength) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  return trimmed.length <= maxLength ? trimmed : null;
}

function normalizeRequiredString(value, maxLength) {
  return normalizeOptionalString(value, maxLength);
}

function normalizeLookupSongId(value) {
  return normalizeOptionalString(value, 120);
}

function normalizeRangePoint(value) {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0)
    return null;
  return value;
}

function parseLimit(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) return 50;
  return Math.min(250, Math.max(1, Math.floor(number)));
}

function parseRepliesLimit(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) return 50;
  return Math.min(100, Math.max(1, Math.floor(number)));
}

module.exports = router;
