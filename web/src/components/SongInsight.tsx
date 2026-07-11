"use client";

import { useEffect, useState } from "react";
import { fetchSongInsight, type SongInsight } from "@/lib/songInsights";

const TAG_COLORS: Record<string, string> = {
  groove: "#FF4D4D",
  hype: "#FF8C1A",
  chill: "#33B3FF",
  immersion: "#994DFF",
  hit: "#FF3380",
  afterglow: "#E6BF4D",
  neutral: "#A3ADB3",
};

function fmtTime(t: number): string {
  const v = Math.max(0, Math.round(t));
  return `${Math.floor(v / 60)}:${String(v % 60).padStart(2, "0")}`;
}

type State = SongInsight | null | "loading";

export default function SongInsightPanel({ songId }: { songId: string }) {
  const [state, setState] = useState<State>("loading");

  useEffect(() => {
    let active = true;
    setState("loading");
    fetchSongInsight(songId)
      .then((data) => {
        if (active) setState(data);
      })
      .catch(() => {
        if (active) setState(null);
      });
    return () => {
      active = false;
    };
  }, [songId]);

  if (state === "loading") {
    return <p className="muted si-msg">読み込み中…</p>;
  }

  if (!state) {
    return <p className="muted si-msg">データが少なく表示できません</p>;
  }

  const maxDensity = Math.max(...state.density.map((b) => b.count), 1);
  const sortedTags = Object.entries(state.tags).sort((a, b) => b[1] - a[1]);
  const maxTagCount = sortedTags.length > 0 ? sortedTags[0][1] : 1;

  return (
    <div className="si-panel">
      <p className="si-reactor-count">{state.reactor_count} 人が反応</p>

      {state.density.length > 0 && (
        <section className="si-section">
          <h4 className="si-heading">How カードの密度</h4>
          <div
            className="si-heatmap"
            role="img"
            aria-label="反応密度ヒートマップ"
          >
            {state.density.map((bucket) => (
              <div
                key={bucket.t}
                className="si-cell"
                title={`${fmtTime(bucket.t)} — ${bucket.count} 人`}
              >
                <div
                  className="si-bar"
                  style={{
                    opacity:
                      bucket.count === 0
                        ? 0.07
                        : 0.15 + 0.85 * (bucket.count / maxDensity),
                  }}
                />
                <span className="si-time">{fmtTime(bucket.t)}</span>
              </div>
            ))}
          </div>
        </section>
      )}

      {sortedTags.length > 0 && (
        <section className="si-section">
          <h4 className="si-heading">タグ分布（推定）</h4>
          <p className="faint" style={{ fontSize: 11, margin: "0 0 10px" }}>
            ※ コメントから推定したタグです
          </p>
          <div className="si-tags">
            {sortedTags.map(([tag, count]) => (
              <div key={tag} className="si-tag-row">
                <span className="si-tag-name">{tag}</span>
                <div className="si-tag-track">
                  <div
                    className="si-tag-fill"
                    style={{
                      width: `${(count / maxTagCount) * 100}%`,
                      background: TAG_COLORS[tag] ?? "#A3ADB3",
                    }}
                  />
                </div>
                <span className="si-tag-count">{count}</span>
              </div>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
