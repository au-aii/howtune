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

## フェーズ P3-B: アーティスト層（**未決3点の確定後に着手**）

- [ ] `artists` / `song_ownership` コレクションと rules
- [ ] アーティスト画面（所有曲の `song_insights` を束ねて表示）
- [ ] 検証: rules テスト・所有曲のみ表示

## フェーズ P3-C: 検証フロー・外部連携（将来）

- [ ] 所有権の検証フロー（手動 or ISRC）

## 実装後の振り返り

（P3-A 実装時に記入）
