const express = require("express");
const router = express.Router();
const auth = require("../middleware/auth");
const { createReactionSession } = require("../repositories/firestore");
const { normalizeMusicKitSongId } = require("../utils/musicKit");

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
const MAX_EVENTS = 200;

function normTags(value) {
  if (!Array.isArray(value)) return [];
  const out = [];
  const seen = new Set();
  for (const v of value) {
    if (typeof v !== "string" || !KNOWN_HOW_TAGS.has(v) || seen.has(v))
      continue;
    seen.add(v);
    out.push(v);
    if (out.length >= MAX_TAGS) break;
  }
  return out;
}

function num(v) {
  return typeof v === "number" && Number.isFinite(v) && v >= 0 ? v : null;
}

function str(v, max) {
  return typeof v === "string" && v ? v.slice(0, max) : null;
}

function normEvents(value) {
  if (!Array.isArray(value)) return [];
  const out = [];
  for (const e of value) {
    if (!e || typeof e !== "object") continue;
    const start = num(e.start);
    const end = num(e.end);
    if (start == null || end == null || end < start) continue;
    const ev = {
      start,
      end: Math.min(end, start + 3600), // 異常な長区間を防ぐ
      tags: normTags(e.tags),
    };
    const intensity = num(e.intensity);
    if (intensity != null) ev.intensity = Math.min(1, intensity);
    const arousal = num(e.arousal);
    if (arousal != null) ev.arousal = Math.min(1, arousal);
    const valence = num(e.valence);
    if (valence != null) ev.valence = Math.min(1, valence);
    const hrTrend = str(e.hr_trend, 16);
    if (hrTrend) ev.hr_trend = hrTrend;
    out.push(ev);
    if (out.length >= MAX_EVENTS) break;
  }
  return out;
}

function normalizePayload(body) {
  if (!body || typeof body !== "object") return null;
  const songId = normalizeMusicKitSongId(body.song_id);
  if (!songId) return null;
  return {
    songId,
    songTitle: str(body.song_title, 200),
    artistId: str(body.artist_id, 120),
    artistName: str(body.artist_name, 200),
    durationSec: num(body.duration_sec),
    consentVersion: str(body.consent_version, 16) ?? "v1",
    events: normEvents(body.events),
    selfReportTags: normTags(body.self_report_tags),
  };
}

// POST /reaction-sessions : 反応セッションを本人の user_id で保存（書き込みは Functions のみ, ADR-0002）
router.post("/", auth, async (req, res) => {
  const payload = normalizePayload(req.body);
  if (!payload) {
    return res.status(400).json({
      error: "song_id が必要です（MusicKit / Apple Music / iTunes の数値曲ID）",
    });
  }
  if (payload.events.length === 0 && payload.selfReportTags.length === 0) {
    return res
      .status(400)
      .json({ error: "events か self_report_tags のいずれかが必要です" });
  }

  try {
    const session = await createReactionSession({ uid: req.uid, ...payload });
    res.status(201).json({ session });
  } catch (err) {
    console.error(err?.message ?? err);
    res.status(500).json({ error: "反応セッションの保存に失敗しました" });
  }
});

module.exports = router;
