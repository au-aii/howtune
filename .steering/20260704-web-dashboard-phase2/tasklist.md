# タスクリスト

> 実装途中で実データフローを調査し、設計を接地し直した（下記 振り返り 参照）。

## フェーズA: iOS — How カードにタグ保存

- [x] ~~iOS でタグを保存~~（**技術的理由でスキップ**: 実データ調査の結果、タグUIを持つ画面(HowCardCreationView)は how-cards コレクションに書かず、how-cards を書く画面(Clip/Lyric)にはタグUIも反応コンテキストも無い。本物タグは集計対象の Comment型 に乗らないため、iOS 保存は集計に効かない。→ moat 次段階 [issue #112] に分離）

## フェーズB: Functions — タグ受け入れ＋保存

- [x] `routes/how-cards.js` で `tags` を検証（既知 HowTag の部分集合・上限6）※将来の本物タグ用の無害な準備
- [x] `repositories/firestore.js` createHowCard/updateHowCard で `tags` 保存

## フェーズC: Functions — song_insights 集計トリガー

- [x] `repositories/insights.js`（新規）`recomputeSongInsights(songId)`（密度・タグ・k=5・匿名）
- [x] コメント推測タグのフォールバック（CommunityViewModel ロジックを JS 移植）
- [x] `index.js` に `onDocumentWritten('how-cards/{cardId}')` トリガー追加
- [x] Node 構文チェック OK（※実稼働は functions デプロイで有効化）

## フェーズD: Firestore rules

- [x] `firestore.rules` に `song_insights`（read: 認証済み / write: false）追加

## フェーズE: Web — ヒートマップ表示

- [x] `web/src/lib/songInsights.ts`（新規）
- [x] `web/src/components/SongInsight.tsx`（新規・密度＋タグ、**「推定タグ」明記**）
- [x] `web/src/components/Dashboard.tsx` に曲選択→インサイト表示
- [x] `web/src/app/globals.css` にヒートマップ/タグのスタイル
- [x] `npm run build` 通過（静的エクスポート）

## フェーズF: 仕上げ

- [x] `docs/roadmap.md` 更新（moat 次段階 = issue #112）
- [x] moat 次段階を issue #112 に記録
- [ ] コミット
- [x] 実装後の振り返り（下部）

---

## 実装後の振り返り

### 実装完了日

2026-07-05

### 計画と実績の差分（重要）

- **設計を実装途中で接地し直した**。当初「本物タグを how-cards に保存（破棄バグ修正）」としたが、実データ調査で:
  - タグUIを持つ `HowCardCreationView` は how-cards ではなく HowChat の AI エンドポイントを叩く。
  - how-cards を書く Clip/Lyric 経路にはタグUIが無い。
  - `how-cards` に2スキーマ混在（Comment型=集計可・tags空 / HowChat型=howTags有・song範囲無し=集計不可）。
  - 生 `ReactionEvent` は Firestore 未保存。
- → Phase 2 は「**手動 How カード区間の密度＋推定タグ**」に接地。iOS 変更は行わず、UI は「推定タグ」と明記。本物の反応密度＋タグは moat 次段階（issue #112）へ分離。

### 学んだこと

- **憶測で設計せず、作成経路・保存スキーマ・既存データを先に実コードで裏取りする**（[[ground-design-in-real-dataflow]]）。今回は途中で気づいて調査 → 接地したが、本来は着手前にやるべきだった。
- 集計は `where('song_id','==',…)` ＋ finite song_start/end フィルタで HowChat型を自然に除外できている。

### 次回への改善提案

- 大きい機能は「実データフロー調査 → 設計 → 実装」の順を厳守。
