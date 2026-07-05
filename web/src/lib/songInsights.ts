import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  where,
} from "firebase/firestore";
import { db } from "./firebase";

export interface DensityBucket {
  t: number;
  count: number;
}

export interface SongInsight {
  song_id: string;
  artist_id: string | null;
  artist_name: string | null;
  song_title: string | null;
  reactor_count: number;
  density: DensityBucket[];
  tags: Record<string, number>;
  updated_at: Date | null;
}

function mapSongInsight(
  songId: string,
  data: Record<string, unknown>,
): SongInsight {
  const updatedAt = data["updated_at"] as { toDate?: () => Date } | undefined;
  return {
    song_id: (data["song_id"] as string) ?? songId,
    artist_id: (data["artist_id"] as string) ?? null,
    artist_name: (data["artist_name"] as string) ?? null,
    song_title: (data["song_title"] as string) ?? null,
    reactor_count: Number(data["reactor_count"] ?? 0),
    density: (data["density"] as DensityBucket[]) ?? [],
    tags: (data["tags"] as Record<string, number>) ?? {},
    updated_at: updatedAt?.toDate ? updatedAt.toDate() : null,
  };
}

/**
 * song_insights/{songId} を直読みする。
 * doc が存在しない（反応者 5 人未満）場合は null を返す。
 * firestore.rules: 認証済みユーザーなら read 可。
 */
export async function fetchSongInsight(
  songId: string,
): Promise<SongInsight | null> {
  const ref = doc(db, "song_insights", songId);
  const snap = await getDoc(ref);
  if (!snap.exists()) return null;
  return mapSongInsight(songId, snap.data() as Record<string, unknown>);
}

/**
 * 指定アーティストの全曲インサイトを取得する（アーティスト別ダッシュボード用）。
 * `artist_id` は Apple Music カタログのアーティスト。匿名集計済みなので個人は特定されない。
 * firestore.rules: 認証済みなら song_insights を list 可。
 */
export async function fetchArtistSongInsights(
  artistId: string,
): Promise<SongInsight[]> {
  const col = collection(db, "song_insights");
  const q = query(col, where("artist_id", "==", artistId));
  const snap = await getDocs(q);
  return snap.docs
    .map((d) => mapSongInsight(d.id, d.data() as Record<string, unknown>))
    .sort((a, b) => b.reactor_count - a.reactor_count);
}
