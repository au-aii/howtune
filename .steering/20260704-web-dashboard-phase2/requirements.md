# 要求内容

## 概要

Web ダッシュボード Phase 2。複数リスナーの反応を**曲ごとに集計**し、「曲のどこで沸いたか（反応密度ヒートマップ）」「どんな聴き方(How)が多いか（タグ分布）」を**匿名化**して見せる。B2B インサイトの土台（ADR-0007）、データフライホイールの最初の一回転（`docs/vision.md`）。

## 背景

- Phase 1 で本人の How カード一覧はできた。次は「集計インサイト」。
- 前提バグ：タグは作成UIで選んでも `HowCardCommentPayload` が破棄＝**Firestore 未保存**。本 Phase で解消。

## 実装対象の機能

### 1. How カードにタグを保存

- iOS の作成UIで選んだ `HowTag` を how-card に保存（破棄バグ解消）。既存カードはコメント推測で補完。

### 2. song_insights 集計（Firestore トリガー）

- how-card 書き込みで該当曲を再集計し `song_insights/{songId}` に前計算・保存。
- 中身：反応密度ヒートマップ（時間バケット）＋タグ分布＋reactor_count。**user_id は含めない**。

### 3. 匿名化（k=5）

- 反応者 5 人未満の**曲・区間は非表示**。

### 4. Web で自分の曲のインサイト表示

- 自分の how-cards の曲 → その曲の集計ヒートマップ＋タグ棒を表示。5 人未満は「データが少なく表示できません」。

## 受け入れ条件

- [ ] how-card 作成時に `tags` が Firestore に保存される
- [ ] 同一曲に 5 人以上の反応があると `song_insights/{songId}` が生成される
- [ ] Web で密度ヒートマップ＋タグ分布が表示される
- [ ] 反応者 5 人未満の曲・区間が非表示になる
- [ ] iOS ビルド green / Web `npm run build` 通過

## スコープ外（次テーマ）

- 生 `ReactionEvent`/モーションの Firestore 保存（moat の燃料）← 本 Phase で再検討したが「タグだけ」に確定、独立テーマへ分離。
- アーティスト認証・曲所有権・B2B 画面（Phase 3）。

## 参照

- `docs/adr/0007-read-only-web-dashboard.md` / `docs/vision.md`
- 承認済みプラン: `~/.claude/plans/elegant-fluttering-kernighan.md`
