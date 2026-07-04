import { doc, getDoc } from "firebase/firestore";
import { db } from "./firebase";

export interface DensityBucket {
  t: number;
  count: number;
}

export interface SongInsight {
  song_id: string;
  reactor_count: number;
  density: DensityBucket[];
  tags: Record<string, number>;
  updated_at: Date | null;
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

  const data = snap.data() as Record<string, unknown>;
  const updatedAt = data["updated_at"] as { toDate?: () => Date } | undefined;

  return {
    song_id: (data["song_id"] as string) ?? songId,
    reactor_count: Number(data["reactor_count"] ?? 0),
    density: (data["density"] as DensityBucket[]) ?? [],
    tags: (data["tags"] as Record<string, number>) ?? {},
    updated_at: updatedAt?.toDate ? updatedAt.toDate() : null,
  };
}
