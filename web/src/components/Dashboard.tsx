"use client";

import { useEffect, useState } from "react";
import { signOut, type User } from "firebase/auth";
import { auth } from "@/lib/firebase";
import { fetchMyHowCards, formatRange, type HowCard } from "@/lib/howCards";
import { fetchArtistSongInsights, type SongInsight } from "@/lib/songInsights";
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
  const [browseSongId, setBrowseSongId] = useState<string | null>(null);
  const [songIdInput, setSongIdInput] = useState("");
  const [artistIdInput, setArtistIdInput] = useState("");
  const [artistSongs, setArtistSongs] = useState<SongInsight[] | null>(null);
  const [artistSelectedSongId, setArtistSelectedSongId] = useState<
    string | null
  >(null);
  const [artistError, setArtistError] = useState<string | null>(null);
  const [artistLoading, setArtistLoading] = useState(false);

  const loadArtist = (idOverride?: string) => {
    const id = (idOverride ?? artistIdInput).trim();
    if (!id) return;
    setArtistError(null);
    setArtistSongs(null);
    setArtistSelectedSongId(null);
    setArtistLoading(true);
    fetchArtistSongInsights(id)
      .then((rows) => setArtistSongs(rows))
      .catch(() =>
        setArtistError("アーティストのインサイトを読み込めませんでした"),
      )
      .finally(() => setArtistLoading(false));
  };

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

      <section className="si-section-wrap">
        <h3 className="si-section-title">曲別インサイトを探す</h3>
        <p className="muted" style={{ marginTop: -4 }}>
          曲IDを入れると、その曲の匿名インサイト（反応密度＋Howタグ）を見られます。自分の
          How カードが無くても閲覧できます。
        </p>
        <div
          style={{
            display: "flex",
            gap: 8,
            flexWrap: "wrap",
            marginBottom: 12,
          }}
        >
          <input
            value={songIdInput}
            onChange={(e) => setSongIdInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && songIdInput.trim())
                setBrowseSongId(songIdInput.trim());
            }}
            placeholder="曲ID（例: howtune-demo-song）"
            aria-label="曲ID"
            style={{
              flex: "1 1 220px",
              padding: "8px 12px",
              borderRadius: 8,
              border: "1px solid var(--separator, rgba(128,128,128,0.4))",
              background: "transparent",
              color: "inherit",
            }}
          />
          <button
            className="si-song-tab"
            onClick={() =>
              songIdInput.trim() && setBrowseSongId(songIdInput.trim())
            }
          >
            見る
          </button>
          <button
            className="si-song-tab"
            onClick={() => {
              setSongIdInput("howtune-demo-song");
              setBrowseSongId("howtune-demo-song");
            }}
          >
            デモ曲を見る
          </button>
        </div>
        {browseSongId && <SongInsightPanel songId={browseSongId} />}
      </section>

      <section className="si-section-wrap">
        <h3 className="si-section-title">アーティストとして見る</h3>
        <p className="muted" style={{ marginTop: -4 }}>
          アーティストID（Apple Music
          カタログ名義）を入れると、その名義の全曲の反応インサイトをまとめて見られます。
          ※現状は自己申告で、認証・所有権の検証は今後（Apple Music for Artists
          等）。
        </p>
        <div
          style={{
            display: "flex",
            gap: 8,
            flexWrap: "wrap",
            marginBottom: 12,
          }}
        >
          <input
            value={artistIdInput}
            onChange={(e) => setArtistIdInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") loadArtist();
            }}
            placeholder="アーティストID（例: howtune）"
            aria-label="アーティストID"
            style={{
              flex: "1 1 220px",
              padding: "8px 12px",
              borderRadius: 8,
              border: "1px solid var(--separator, rgba(128,128,128,0.4))",
              background: "transparent",
              color: "inherit",
            }}
          />
          <button className="si-song-tab" onClick={() => loadArtist()}>
            見る
          </button>
          <button
            className="si-song-tab"
            onClick={() => {
              setArtistIdInput("howtune");
              loadArtist("howtune");
            }}
          >
            デモ（howtune）
          </button>
        </div>
        {artistLoading && <p className="muted">読み込み中…</p>}
        {artistError && <p className="error">{artistError}</p>}
        {artistSongs && artistSongs.length === 0 && !artistLoading && (
          <p className="muted">
            この名義の公開インサイトはまだありません（反応者5人以上の曲が対象）。
          </p>
        )}
        {artistSongs && artistSongs.length > 0 && (
          <>
            <div className="stats">
              <div className="stat">
                <div className="num">{artistSongs.length}</div>
                <div className="lbl">SONGS</div>
              </div>
              <div className="stat">
                <div className="num">
                  {artistSongs.reduce((s, x) => s + x.reactor_count, 0)}
                </div>
                <div className="lbl">TOTAL REACTORS</div>
              </div>
            </div>
            <div className="si-song-tabs">
              {artistSongs.map((s) => (
                <button
                  key={s.song_id}
                  className={`si-song-tab${artistSelectedSongId === s.song_id ? " active" : ""}`}
                  onClick={() =>
                    setArtistSelectedSongId((prev) =>
                      prev === s.song_id ? null : s.song_id,
                    )
                  }
                >
                  {(s.song_title ?? s.song_id) + "（" + s.reactor_count + "）"}
                </button>
              ))}
            </div>
            {artistSelectedSongId && (
              <SongInsightPanel songId={artistSelectedSongId} />
            )}
          </>
        )}
      </section>

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
