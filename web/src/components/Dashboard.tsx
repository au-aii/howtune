"use client";

import { useEffect, useState } from "react";
import { signOut, type User } from "firebase/auth";
import { auth } from "@/lib/firebase";
import { fetchMyHowCards, formatRange, type HowCard } from "@/lib/howCards";
import SongInsightPanel from "@/components/SongInsight";

interface SongEntry {
  songId: string;
  label: string;
}

function distinctSongs(cards: HowCard[]): SongEntry[] {
  const seen = new Map<string, string>();
  for (const c of cards) {
    if (!seen.has(c.songId)) {
      seen.set(c.songId, c.artistName ?? c.songTitle ?? c.songId);
    }
  }
  return Array.from(seen.entries()).map(([songId, label]) => ({
    songId,
    label,
  }));
}

export default function Dashboard({ user }: { user: User }) {
  const [cards, setCards] = useState<HowCard[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [selectedSongId, setSelectedSongId] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    fetchMyHowCards(user.uid)
      .then((c) => {
        if (active) setCards(c);
      })
      .catch(() => {
        if (active) setError("How カードを読み込めませんでした");
      });
    return () => {
      active = false;
    };
  }, [user.uid]);

  const totalLikes = cards?.reduce((sum, c) => sum + c.likes, 0) ?? 0;

  return (
    <div className="wrap">
      <header className="top">
        <div className="who">
          <h2>あなたの How カード</h2>
          <p className="email">{user.email}</p>
        </div>
        <button className="ghost" onClick={() => signOut(auth)}>
          ログアウト
        </button>
      </header>

      {cards && cards.length > 0 && (
        <div className="stats">
          <div className="stat">
            <div className="num">{cards.length}</div>
            <div className="lbl">HOW CARDS</div>
          </div>
          <div className="stat">
            <div className="num">{totalLikes}</div>
            <div className="lbl">TOTAL LIKES</div>
          </div>
        </div>
      )}

      {error && <p className="error">{error}</p>}

      {!cards && !error && <p className="muted">読み込み中…</p>}

      {cards && cards.length === 0 && (
        <div className="empty">
          まだ How カードがありません。
          <br />
          iOS アプリで曲の聴きどころを記録すると、ここに表示されます。
        </div>
      )}

      {cards && cards.length > 0 && (
        <div className="list">
          {cards.map((card) => (
            <article className="card" key={card.id}>
              <div className="song">
                <span>{card.artistName ?? card.songTitle ?? card.songId}</span>
                <span className="range">
                  {formatRange(card.songStart, card.songEnd)}
                </span>
              </div>
              <p className="comment">{card.comment}</p>
              <div className="meta">
                <span>♥ {card.likes}</span>
                <span>💬 {card.replyCount}</span>
                {card.createdAt && (
                  <span>{card.createdAt.toLocaleDateString("ja-JP")}</span>
                )}
              </div>
            </article>
          ))}
        </div>
      )}

      {cards && cards.length > 0 && (
        <section className="si-section-wrap">
          <h3 className="si-section-title">曲別インサイト</h3>
          <div className="si-song-tabs">
            {distinctSongs(cards).map(({ songId, label }) => (
              <button
                key={songId}
                className={`si-song-tab${selectedSongId === songId ? " active" : ""}`}
                onClick={() =>
                  setSelectedSongId((prev) => (prev === songId ? null : songId))
                }
              >
                {label}
              </button>
            ))}
          </div>
          {selectedSongId && <SongInsightPanel songId={selectedSongId} />}
        </section>
      )}
    </div>
  );
}
