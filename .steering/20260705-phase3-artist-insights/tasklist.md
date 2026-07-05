# タスクリスト — Phase 3: アーティスト向け B2B インサイト

## フェーズ 0: 設計（この steering）

- [x] `firestore.rules` の実態確認（`song_insights` は認証済み read 可）
- [x] requirements.md（スコープを A 決定不要 / B アーティスト層に分割、未決3点）
- [x] design.md（A スライス設計・B のスキーマ/rules 案・段階）

## フェーズ P3-A: 任意曲インサイト閲覧（決定不要・実装可）

- [x] `web/src/components/Dashboard.tsx` に「曲IDでインサイトを探す」入力を追加（`SongInsightPanel` 再利用、デモ曲 `howtune-demo-song` クイックボタン）
- [x] 自分の How カード有無に依存せず閲覧できる（header 直下・`cards.length>0` ゲートの外に配置）
- [x] 検証: `npm run build` green（node@22）
- [x] `personal` に push（PR #8 umbrella に反映）
- [ ] **hosting へ deploy はユーザーがPR確認後に実行**（auto-mode 分類器が自動 deploy をブロック＝正しい）

## 決定（2026-07-05 確定）

- ④ 認証: **まず認証なし・自己申告で体験を出す**（Sign in with Apple / MusicKit は将来）
- ⑤ 所有権: **自己クレーム**（Apple Music アーティストに紐付け。soft検証＝Apple Music for Artists 等は将来）
- ⑥ キー: **Apple Music の `artist_id`**（既存 how-card のカタログ情報を流用）

## フェーズ P3-B（MVP・自己申告アーティストビュー）← 実装済み

- [x] `functions/repositories/insights.js` に `artist_id`/`artist_name`/`song_title` を集計出力へ追加（アーティスト単位で `song_insights` を引けるように。個人情報ではない）
- [x] `web/src/lib/songInsights.ts` に `fetchArtistSongInsights(artistId)`（`song_insights` を `artist_id==X` で list）
- [x] `web/src/components/Dashboard.tsx` に「アーティストとして見る」（名義の全曲の反応をまとめて表示、自己申告）
- [x] 検証: `npm run build` green（node@22）、デモ曲 recompute で `artist_id=howtune` 付与を確認
- [ ] hosting + functions（artist_id 付与のトリガー反映）の再デプロイは**ユーザーが PR 確認後**

## フェーズ P3-B2: 永続クレーム＋検証（将来）

- [ ] `artists`/`song_ownership` コレクション＋rules（永続的なアーティストアカウント・所有権）
- [ ] Apple Music for Artists / Spotify for Artists 等での所有権検証（soft→強）

## 旧・未決（→ 上の「決定」で解消済み）

## フェーズ P3-C: 検証フロー・外部連携（将来）

- [ ] 所有権の検証フロー（手動 or ISRC）

## 実装後の振り返り

（P3-A 実装時に記入）
