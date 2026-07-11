import { collection, getDocs, query, where, limit } from "firebase/firestore";
import { db } from "./firebase";

export interface HowCard {
  id: string;
  comment: string;
  songId: string;
  songTitle: string | null;
  artistName: string | null;
  songStart: number;
  songEnd: number;
  likes: number;
  replyCount: number;
  createdAt: Date | null;
}

/**
 * 自分の How カードを Firestore から直読みする。
 * firestore.rules: how-cards は「ログイン済みなら read 可」なので、
 * user_id == 自分 で絞れば本人分だけ取得できる。
 * （where + orderBy は複合インデックスが要るため、並べ替えはクライアント側で行う）
 */
export async function fetchMyHowCards(uid: string): Promise<HowCard[]> {
  const q = query(
    collection(db, "how-cards"),
    where("user_id", "==", uid),
    limit(200),
  );
  const snap = await getDocs(q);

  const cards = snap.docs.map((d) => {
    const data = d.data() as Record<string, unknown>;
    const created = data["created_at"] as { toDate?: () => Date } | undefined;
    return {
      id: d.id,
      comment: (data["comment"] as string) ?? "",
      songId: (data["song_id"] as string) ?? "",
      songTitle: (data["song_title"] as string) ?? null,
      artistName: (data["artist_name"] as string) ?? null,
      songStart: Number(data["song_start"] ?? 0),
      songEnd: Number(data["song_end"] ?? 0),
      likes: Number(data["likes"] ?? 0),
      replyCount: Number(data["reply_count"] ?? 0),
      createdAt: created?.toDate ? created.toDate() : null,
    } satisfies HowCard;
  });

  return cards.sort(
    (a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0),
  );
}

export function formatRange(start: number, end: number): string {
  const fmt = (t: number) => {
    const v = Math.max(0, Math.round(t));
    return `${Math.floor(v / 60)}:${String(v % 60).padStart(2, "0")}`;
  };
  const safeEnd = end > start ? end : start;
  return `${fmt(start)}–${fmt(safeEnd)}`;
}
