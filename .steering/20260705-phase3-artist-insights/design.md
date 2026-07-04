# 設計書 — Phase 3: アーティスト向け B2B インサイト

## アーキテクチャ概要

Phase 2 の匿名 `song_insights` を土台に、B2B 閲覧サーフェスを足す。責務分離（収集=iOS / 集計=Functions / 閲覧=Web, ADR-0007）は不変。**A: 認証・所有権に依存しない閲覧スライス**と、**B: アーティスト identity/所有権層**に分ける。

## A. 決定不要スライス（実装可能）

- ルート例: `web/src/app/song/[songId]/page.tsx`（静的エクスポートなので `generateStaticParams` は使えない → クライアント側で `songId` を受け取り `fetchSongInsight` する構成、または Dashboard 内に「曲IDで探す」入力を追加）。
- 再利用: `web/src/lib/songInsights.ts` の `fetchSongInsight`、`web/src/components/SongInsight.tsx`（密度＋タグ表示、データ無しは「表示できません」）。
- rules 変更: **不要**（`song_insights` は認証済み read 可）。
- UX: `Dashboard.tsx` に「曲別インサイトを探す」セクションを足し、`song_id`（例 `howtune-demo-song`）を入力/選択 → `SongInsightPanel` を表示。自分の How カード有無に依存しない。
- これで「任意曲の匿名インサイトを閲覧」という Phase 3 の中核価値を、認証・所有権を待たずに出せる。

## B. アーティスト層（設計のみ・実装はユーザー判断後）

### データモデル案

```jsonc
// artists/{artistId}  — 検証済みアーティスト
{ "uid": "…", "display_name": "…", "verified": true, "created_at": … }

// song_ownership/{songId}  — 曲 → アーティストの所有権（運営 or 検証で付与）
{ "song_id": "…", "artist_id": "…", "verified_by": "manual|isrc", "created_at": … }
```

### rules 案（決定後に追加）

- `artists/{id}`: 本人のみ read/更新、`verified` は Functions のみ書き込み。
- `song_ownership/{songId}`: read 認証済み可、write は Functions(admin) のみ（自己申告を許すなら別途検証フロー）。
- `song_insights` は現行どおり（匿名なので所有権に関係なく read 可）。アーティスト画面は「自分が所有する `song_id` 群」で `song_insights` をフィルタ表示するだけ＝**生データは一切増やさない**。

### アーティスト画面（Web）

- `artists/{uid}` があるユーザーには、`song_ownership where artist_id==自分` の曲群を一覧し、各曲の `SongInsight` を表示するダッシュボードを出す。

## データフロー

```
（A）認証済みユーザー → song_id 指定 → fetchSongInsight → SongInsight 表示（rules 変更なし）
（B）artist ユーザー → song_ownership(自分の曲) → 各 song_insights を束ねて表示
```

## テスト戦略

- A: `web` で `npm run build` green、曲ID入力→既存デモ曲(`howtune-demo-song`)のインサイト表示を確認。
- B: rules テスト（他人の artist/ownership を書けない）、所有曲のみ表示されること。

## 段階

- **P3-A（今回の縦スライス）**: 任意曲インサイト閲覧（決定不要・rules 変更なし）。
- **P3-B**: アーティスト identity＋所有権＋rules（未決3点の確定後）。
- **P3-C**: 検証フロー・ディストリビューター連携（将来）。

## 未決（ユーザー判断待ち → requirements.md 参照）

- 認証方式 / 所有権証明 / `artist_id` キー。これらが決まるまで **B の実装には入らない**（A のみ実装）。
